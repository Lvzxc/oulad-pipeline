-- DIM_DATE GOLD DQ RESULTS

WITH run_info AS (
    SELECT
        uuid() AS run_id,
        current_timestamp() AS run_timestamp
),

base AS (
    SELECT *
    FROM oulad.oulad_gold.dim_date
),

expectations AS (
    WITH date_ranges AS (
        SELECT
            MIN(date_submitted) AS min_date,
            MAX(date_submitted) AS max_date
        FROM oulad.oulad_silver.student_assessment_silver

        UNION ALL

        SELECT
            MIN(date_registration),
            MAX(date_registration)
        FROM oulad.oulad_silver.student_registration_silver

        UNION ALL

        SELECT
            MIN(date_unregistration),
            MAX(date_unregistration)
        FROM oulad.oulad_silver.student_registration_silver

        UNION ALL

        SELECT
            MIN(date),
            MAX(date)
        FROM oulad.oulad_silver.student_vle_silver
    ),
    overall_range AS (
        SELECT
            MIN(min_date) AS min_date,
            MAX(max_date) AS max_date
        FROM date_ranges
    )
    SELECT
        min_date,
        max_date,
        max_date - min_date + 1 AS expected_row_count
    FROM overall_range
),

checks AS (

    -- VOLUME
    SELECT
        'dim_date' AS table_name,
        'date_key' AS column_name,
        'VOLUME' AS dq_dimension,
        'Row count reconciliation' AS rule_name,
        'INFO' AS severity,
        CAST(e.expected_row_count AS STRING) AS expected_value,
        CAST(COUNT(*) AS STRING) AS actual_value,
        COUNT(*) AS total_records,
        COUNT(*) AS passed_records,
        ABS(COUNT(*) - e.expected_row_count) AS failed_records
    FROM base
    CROSS JOIN expectations e
    GROUP BY e.expected_row_count

    UNION ALL

    -- NULL: date_key
    SELECT
        'dim_date',
        'date_key',
        'NULL',
        'Missing date_key',
        'FAIL',
        '0',
        CAST(COUNT_IF(date_key IS NULL) AS STRING),
        COUNT(*),
        COUNT(*) - COUNT_IF(date_key IS NULL),
        COUNT_IF(date_key IS NULL)
    FROM base

    UNION ALL

    -- UNIQUE: date_key
    SELECT
        'dim_date',
        'date_key',
        'UNIQUE',
        'Duplicate date_key',
        'FAIL',
        '0',
        CAST(COUNT(*) - COUNT(DISTINCT date_key) AS STRING),
        COUNT(*),
        COUNT(DISTINCT date_key),
        COUNT(*) - COUNT(DISTINCT date_key)
    FROM base

    UNION ALL

    -- NULL: relative_day
    SELECT
        'dim_date',
        'relative_day',
        'NULL',
        'Missing relative_day',
        'FAIL',
        '0',
        CAST(COUNT_IF(relative_day IS NULL) AS STRING),
        COUNT(*),
        COUNT(*) - COUNT_IF(relative_day IS NULL),
        COUNT_IF(relative_day IS NULL)
    FROM base

    UNION ALL

    -- UNIQUE: relative_day
    SELECT
        'dim_date',
        'relative_day',
        'UNIQUE',
        'Duplicate relative_day',
        'FAIL',
        '0',
        CAST(COUNT(*) - COUNT(DISTINCT relative_day) AS STRING),
        COUNT(*),
        COUNT(DISTINCT relative_day),
        COUNT(*) - COUNT(DISTINCT relative_day)
    FROM base

    UNION ALL

    -- RANGE: relative_day
    SELECT
        'dim_date',
        'relative_day',
        'RANGE',
        'Invalid relative_day range',
        'FAIL',
        CONCAT(
            CAST(e.min_date AS STRING),
            ' to ',
            CAST(e.max_date AS STRING)
        ),
        CONCAT(
            CAST(MIN(b.relative_day) AS STRING),
            ' to ',
            CAST(MAX(b.relative_day) AS STRING)
        ),
        COUNT(*),
        COUNT(*) - COUNT_IF(
            b.relative_day < e.min_date
            OR b.relative_day > e.max_date
        ),
        COUNT_IF(
            b.relative_day < e.min_date
            OR b.relative_day > e.max_date
        )
    FROM base b
    CROSS JOIN expectations e
    GROUP BY e.min_date, e.max_date

    UNION ALL

    -- RANGE: relative_week
    SELECT
        'dim_date',
        'relative_week',
        'RANGE',
        'Invalid relative_week',
        'FAIL',
        'FLOOR(relative_day / 7)',
        CAST(
            COUNT_IF(
                relative_week <>
                CAST(FLOOR(relative_day / 7) AS BIGINT)
            ) AS STRING
        ),
        COUNT(*),
        COUNT(*) - COUNT_IF(
            relative_week <>
            CAST(FLOOR(relative_day / 7) AS BIGINT)
        ),
        COUNT_IF(
            relative_week <>
            CAST(FLOOR(relative_day / 7) AS BIGINT)
        )
    FROM base

    UNION ALL

    -- BUSINESS: Silver lineage
    SELECT
        'dim_date',
        'silver_processed_timestamp',
        'BUSINESS',
        'Missing Silver processing timestamp',
        'FAIL',
        '0',
        CAST(COUNT_IF(silver_processed_timestamp IS NULL) AS STRING),
        COUNT(*),
        COUNT(*) - COUNT_IF(silver_processed_timestamp IS NULL),
        COUNT_IF(silver_processed_timestamp IS NULL)
    FROM base

    UNION ALL

    -- BUSINESS: Gold lineage
    SELECT
        'dim_date',
        'gold_processed_timestamp',
        'BUSINESS',
        'Missing Gold processing timestamp',
        'FAIL',
        '0',
        CAST(COUNT_IF(gold_processed_timestamp IS NULL) AS STRING),
        COUNT(*),
        COUNT(*) - COUNT_IF(gold_processed_timestamp IS NULL),
        COUNT_IF(gold_processed_timestamp IS NULL)
    FROM base
),

final_results AS (
    SELECT
        r.run_id,
        r.run_timestamp,
        'GOLD' AS layer,
        c.table_name,
        c.column_name,
        c.dq_dimension,
        c.rule_name,
        c.severity,
        c.expected_value,
        c.actual_value,
        c.total_records,
        c.passed_records,
        c.failed_records,
        ROUND(
            c.failed_records * 100.0
            / NULLIF(c.total_records, 0),
            2
        ) AS failure_pct,
        CASE
            WHEN c.severity = 'INFO' THEN NULL
            WHEN c.failed_records = 0 THEN 100.0
            ELSE ROUND(
                c.passed_records * 100.0
                / NULLIF(c.total_records, 0),
                2
            )
        END AS dq_score,
        CASE
            WHEN c.severity = 'INFO' THEN NULL
            WHEN c.failed_records = 0 THEN 'PASS'
            ELSE 'FAIL'
        END AS status
    FROM checks c
    CROSS JOIN run_info r
)

INSERT INTO oulad.oulad_quality.dq_results
SELECT *
FROM final_results;