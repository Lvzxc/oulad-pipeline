-- DIM_DATE GOLD DATA QUALITY VALIDATION

WITH base AS (
    SELECT *
    FROM oulad.oulad_gold.dim_date
),

-- Recreate the expected relative-date range from Silver.
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

dq_results AS (

    -- Volume: dim_date should contain every relative day
    -- between the expected minimum and maximum.
    SELECT
        'dim_date' AS table_name,
        'Row count' AS check_name,
        'VOLUME' AS check_type,
        COUNT(*) AS records_checked,
        ABS(
            COUNT(*) - e.expected_row_count
        ) AS failures,
        CAST(e.expected_row_count AS STRING) AS expected_value,
        CAST(COUNT(*) AS STRING) AS actual_value
    FROM base
    CROSS JOIN expectations e
    GROUP BY e.expected_row_count

    UNION ALL

    -- Surrogate key completeness.
    SELECT
        'dim_date',
        'Missing date_key',
        'NULL',
        COUNT(*),
        COUNT_IF(date_key IS NULL),
        '0',
        CAST(COUNT_IF(date_key IS NULL) AS STRING)
    FROM base

    UNION ALL

    -- Surrogate key uniqueness.
    SELECT
        'dim_date',
        'Duplicate date_key',
        'UNIQUE',
        COUNT(*),
        COUNT(*) - COUNT(DISTINCT date_key),
        '0',
        CAST(
            COUNT(*) - COUNT(DISTINCT date_key)
            AS STRING
        )
    FROM base

    UNION ALL

    -- Natural relative-day key completeness.
    SELECT
        'dim_date',
        'Missing relative_day',
        'NULL',
        COUNT(*),
        COUNT_IF(relative_day IS NULL),
        '0',
        CAST(COUNT_IF(relative_day IS NULL) AS STRING)
    FROM base

    UNION ALL

    -- Each relative day should occur exactly once.
    SELECT
        'dim_date',
        'Duplicate relative_day',
        'UNIQUE',
        COUNT(*),
        COUNT(*) - COUNT(DISTINCT relative_day),
        '0',
        CAST(
            COUNT(*) - COUNT(DISTINCT relative_day)
            AS STRING
        )
    FROM base

    UNION ALL

    -- Validate that the dimension covers the complete expected range.
    SELECT
        'dim_date',
        'Invalid relative_day range',
        'RANGE',
        COUNT(*),
        COUNT_IF(
            relative_day < e.min_date
            OR relative_day > e.max_date
        ),
        CONCAT(
            CAST(e.min_date AS STRING),
            ' to ',
            CAST(e.max_date AS STRING)
        ),
        CONCAT(
            CAST(MIN(relative_day) AS STRING),
            ' to ',
            CAST(MAX(relative_day) AS STRING)
        )
    FROM base
    CROSS JOIN expectations e
    GROUP BY e.min_date, e.max_date

    UNION ALL

    -- Validate the relative week calculation.
    SELECT
        'dim_date',
        'Invalid relative_week',
        'RANGE',
        COUNT(*),
        COUNT_IF(
            relative_week <> CAST(FLOOR(relative_day / 7) AS BIGINT)
        ),
        'FLOOR(relative_day / 7)',
        CAST(
            COUNT_IF(
                relative_week <>
                CAST(FLOOR(relative_day / 7) AS BIGINT)
            )
            AS STRING
        )
    FROM base

    UNION ALL

    -- Silver lineage.
    SELECT
        'dim_date',
        'Missing Silver processing timestamp',
        'LINEAGE',
        COUNT(*),
        COUNT_IF(silver_processed_timestamp IS NULL),
        '0',
        CAST(
            COUNT_IF(silver_processed_timestamp IS NULL)
            AS STRING
        )
    FROM base

    UNION ALL

    -- Gold lineage.
    SELECT
        'dim_date',
        'Missing Gold processing timestamp',
        'LINEAGE',
        COUNT(*),
        COUNT_IF(gold_processed_timestamp IS NULL),
        '0',
        CAST(
            COUNT_IF(gold_processed_timestamp IS NULL)
            AS STRING
        )
    FROM base
),

measured AS (
    SELECT
        table_name,
        check_name,
        check_type,
        records_checked,
        failures,
        expected_value,
        actual_value,
        ROUND(
            failures * 100.0 / NULLIF(records_checked, 0),
            2
        ) AS failure_pct
    FROM dq_results
)

SELECT
    table_name,
    check_name,
    check_type,
    records_checked,
    failures,
    expected_value,
    actual_value,
    failure_pct,

    CASE
        WHEN failures = 0
        THEN 'PASS'

        WHEN check_type = 'NULL'
             AND check_name IN (
                 'Missing date_key',
                 'Missing relative_day'
             )
        THEN 'FAIL'

        WHEN check_type IN (
            'UNIQUE',
            'RANGE',
            'ACCEPTED VALUE'
        )
        AND failure_pct <= 1
        THEN 'WARN'

        WHEN check_type IN (
            'UNIQUE',
            'RANGE',
            'ACCEPTED VALUE'
        )
        THEN 'FAIL'

        WHEN check_type = 'VOLUME'
             AND failure_pct <= 2
        THEN 'WARN'

        WHEN check_type = 'VOLUME'
        THEN 'FAIL'

        WHEN check_type = 'NULL'
             AND failure_pct <= 1
        THEN 'WARN'

        WHEN check_type = 'NULL'
        THEN 'FAIL'

        WHEN check_type = 'LINEAGE'
             AND failure_pct <= 1
        THEN 'WARN'

        ELSE 'FAIL'
    END AS status

FROM measured

ORDER BY
    CASE
        WHEN status = 'FAIL' THEN 1
        WHEN status = 'WARN' THEN 2
        ELSE 3
    END,
    check_type,
    check_name;