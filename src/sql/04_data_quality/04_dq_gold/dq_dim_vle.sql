-- DIM_VLE GOLD DQ RESULTS

WITH run_info AS (
    SELECT
        uuid() AS run_id,
        current_timestamp() AS run_timestamp
),

base AS (
    SELECT *
    FROM oulad.oulad_gold.dim_vle
),

expectations AS (
    SELECT COUNT(*) AS expected_row_count
    FROM (
        SELECT DISTINCT
            v.id_site,
            c.course_key
        FROM oulad.oulad_silver.vle_silver v
        INNER JOIN oulad.oulad_gold.dim_course c
            ON v.code_module = c.code_module
            AND v.code_presentation = c.code_presentation
    )
),

checks AS (

    -- VOLUME
    SELECT
        'dim_vle' AS table_name,
        'site_key' AS column_name,
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

    -- NULL: site_key
    SELECT
        'dim_vle',
        'site_key',
        'NULL',
        'Missing site_key',
        'FAIL',
        '0',
        CAST(COUNT_IF(site_key IS NULL) AS STRING),
        COUNT(*),
        COUNT(*) - COUNT_IF(site_key IS NULL),
        COUNT_IF(site_key IS NULL)
    FROM base

    UNION ALL

    -- UNIQUE: site_key
    SELECT
        'dim_vle',
        'site_key',
        'UNIQUE',
        'Duplicate site_key',
        'FAIL',
        '0',
        CAST(COUNT(*) - COUNT(DISTINCT site_key) AS STRING),
        COUNT(*),
        COUNT(DISTINCT site_key),
        COUNT(*) - COUNT(DISTINCT site_key)
    FROM base

    UNION ALL

    -- NULL: id_site
    SELECT
        'dim_vle',
        'id_site',
        'NULL',
        'Missing id_site',
        'FAIL',
        '0',
        CAST(COUNT_IF(id_site IS NULL) AS STRING),
        COUNT(*),
        COUNT(*) - COUNT_IF(id_site IS NULL),
        COUNT_IF(id_site IS NULL)
    FROM base

    UNION ALL

    -- NULL: course_key
    SELECT
        'dim_vle',
        'course_key',
        'NULL',
        'Missing course_key',
        'FAIL',
        '0',
        CAST(COUNT_IF(course_key IS NULL) AS STRING),
        COUNT(*),
        COUNT(*) - COUNT_IF(course_key IS NULL),
        COUNT_IF(course_key IS NULL)
    FROM base

    UNION ALL

    -- UNIQUE: VLE business key
    SELECT
        'dim_vle',
        'id_site,course_key',
        'UNIQUE',
        'Duplicate VLE business key',
        'FAIL',
        '0',
        CAST(
            COUNT(*) - COUNT(
                DISTINCT CONCAT(
                    CAST(id_site AS STRING),
                    '|',
                    CAST(course_key AS STRING)
                )
            ) AS STRING
        ),
        COUNT(*),
        COUNT(
            DISTINCT CONCAT(
                CAST(id_site AS STRING),
                '|',
                CAST(course_key AS STRING)
            )
        ),
        COUNT(*) - COUNT(
            DISTINCT CONCAT(
                CAST(id_site AS STRING),
                '|',
                CAST(course_key AS STRING)
            )
        )
    FROM base

    UNION ALL

    -- REFERENTIAL INTEGRITY: course_key
    SELECT
        'dim_vle',
        'course_key',
        'REFERENTIAL INTEGRITY',
        'VLE without matching course',
        'FAIL',
        '0',
        CAST(COUNT_IF(c.course_key IS NULL) AS STRING),
        COUNT(*),
        COUNT(*) - COUNT_IF(c.course_key IS NULL),
        COUNT_IF(c.course_key IS NULL)
    FROM base v
    LEFT JOIN oulad.oulad_gold.dim_course c
        ON v.course_key = c.course_key

    UNION ALL

    -- RANGE: week range
    SELECT
        'dim_vle',
        'week_from,week_to',
        'RANGE',
        'Invalid week range',
        'FAIL',
        'week_from <= week_to',
        CAST(
            COUNT_IF(
                week_from IS NOT NULL
                AND week_to IS NOT NULL
                AND week_from > week_to
            ) AS STRING
        ),
        COUNT(*),
        COUNT(*) - COUNT_IF(
            week_from IS NOT NULL
            AND week_to IS NOT NULL
            AND week_from > week_to
        ),
        COUNT_IF(
            week_from IS NOT NULL
            AND week_to IS NOT NULL
            AND week_from > week_to
        )
    FROM base

    UNION ALL

    -- BUSINESS: Silver lineage
    SELECT
        'dim_vle',
        'silver_processed_timestamp',
        'BUSINESS',
        'Missing Silver processing timestamp',
        'FAIL',
        '0',
        CAST(
            COUNT_IF(silver_processed_timestamp IS NULL) AS STRING
        ),
        COUNT(*),
        COUNT(*) - COUNT_IF(silver_processed_timestamp IS NULL),
        COUNT_IF(silver_processed_timestamp IS NULL)
    FROM base

    UNION ALL

    -- BUSINESS: Gold lineage
    SELECT
        'dim_vle',
        'gold_processed_timestamp',
        'BUSINESS',
        'Missing Gold processing timestamp',
        'FAIL',
        '0',
        CAST(
            COUNT_IF(gold_processed_timestamp IS NULL) AS STRING
        ),
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