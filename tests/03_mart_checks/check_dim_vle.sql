-- DIM_VLE GOLD DATA QUALITY VALIDATION

WITH base AS (
    SELECT *
    FROM oulad.oulad_gold.dim_vle
),

expectations AS (
    -- Expected Gold row count is based on distinct Silver VLE records
    -- that successfully map to a Gold course.
    SELECT
        COUNT(*) AS expected_row_count
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

dq_results AS (

    -- Volume
    SELECT
        'dim_vle' AS table_name,
        'Row count' AS check_name,
        'VOLUME' AS check_type,
        COUNT(*) AS records_checked,
        ABS(COUNT(*) - e.expected_row_count) AS failures,
        CAST(e.expected_row_count AS STRING) AS expected_value,
        CAST(COUNT(*) AS STRING) AS actual_value
    FROM base
    CROSS JOIN expectations e
    GROUP BY e.expected_row_count

    UNION ALL

    -- Surrogate key completeness
    SELECT
        'dim_vle',
        'Missing site_key',
        'NULL',
        COUNT(*),
        COUNT_IF(site_key IS NULL),
        '0',
        CAST(COUNT_IF(site_key IS NULL) AS STRING)
    FROM base

    UNION ALL

    -- Surrogate key uniqueness
    SELECT
        'dim_vle',
        'Duplicate site_key',
        'UNIQUE',
        COUNT(*),
        COUNT(*) - COUNT(DISTINCT site_key),
        '0',
        CAST(
            COUNT(*) - COUNT(DISTINCT site_key)
            AS STRING
        )
    FROM base

    UNION ALL

    -- Required source identifier
    SELECT
        'dim_vle',
        'Missing id_site',
        'NULL',
        COUNT(*),
        COUNT_IF(id_site IS NULL),
        '0',
        CAST(COUNT_IF(id_site IS NULL) AS STRING)
    FROM base

    UNION ALL

    -- Required course key
    SELECT
        'dim_vle',
        'Missing course_key',
        'NULL',
        COUNT(*),
        COUNT_IF(course_key IS NULL),
        '0',
        CAST(COUNT_IF(course_key IS NULL) AS STRING)
    FROM base

    UNION ALL

    -- Business key uniqueness
    SELECT
        'dim_vle',
        'Duplicate VLE business key',
        'UNIQUE',
        COUNT(*),
        COUNT(*) - COUNT(
            DISTINCT CONCAT(
                id_site,
                '|',
                course_key
            )
        ),
        '0',
        CAST(
            COUNT(*) - COUNT(
                DISTINCT CONCAT(
                    id_site,
                    '|',
                    course_key
                )
            )
            AS STRING
        )
    FROM base

    UNION ALL

    -- Foreign key to dim_course
    SELECT
        'dim_vle',
        'VLE without matching course',
        'FOREIGN KEY',
        COUNT(*),
        COUNT_IF(c.course_key IS NULL),
        '0',
        CAST(
            COUNT_IF(c.course_key IS NULL)
            AS STRING
        )
    FROM base v
    LEFT JOIN oulad.oulad_gold.dim_course c
        ON v.course_key = c.course_key

    UNION ALL

    -- Week range validation
    SELECT
        'dim_vle',
        'Invalid week range',
        'RANGE',
        COUNT(*),
        COUNT_IF(
            week_from IS NOT NULL
            AND week_to IS NOT NULL
            AND week_from > week_to
        ),
        'week_from <= week_to',
        CAST(
            COUNT_IF(
                week_from IS NOT NULL
                AND week_to IS NOT NULL
                AND week_from > week_to
            )
            AS STRING
        )
    FROM base

    UNION ALL

    -- Silver lineage
    SELECT
        'dim_vle',
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

    -- Gold lineage
    SELECT
        'dim_vle',
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

        -- Critical key fields
        WHEN check_type = 'NULL'
             AND check_name IN (
                 'Missing site_key',
                 'Missing id_site',
                 'Missing course_key'
             )
        THEN 'FAIL'

        -- UNIQUE / RANGE
        WHEN check_type IN ('UNIQUE', 'RANGE')
             AND failure_pct <= 1
        THEN 'WARN'

        WHEN check_type IN ('UNIQUE', 'RANGE')
        THEN 'FAIL'

        -- FOREIGN KEY
        WHEN check_type = 'FOREIGN KEY'
             AND failure_pct <= 0.1
        THEN 'WARN'

        WHEN check_type = 'FOREIGN KEY'
        THEN 'FAIL'

        -- VOLUME
        WHEN check_type = 'VOLUME'
             AND failure_pct <= 2
        THEN 'WARN'

        WHEN check_type = 'VOLUME'
        THEN 'FAIL'

        -- Other NULL checks
        WHEN check_type = 'NULL'
             AND failure_pct <= 1
        THEN 'WARN'

        WHEN check_type = 'NULL'
        THEN 'FAIL'

        -- LINEAGE
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