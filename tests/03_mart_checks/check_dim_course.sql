-- DIM_COURSE GOLD DATA QUALITY VALIDATION

WITH base AS (
    SELECT *
    FROM oulad.oulad_gold.dim_course
),

-- Expected values are derived from Silver to avoid hard-coded counts.
expectations AS (
    SELECT
        COUNT(*) AS silver_count
    FROM oulad.oulad_silver.courses_silver
),

dq_results AS (

    -- Volume check
    SELECT
        'dim_course' AS table_name,
        'Row count' AS check_name,
        'VOLUME' AS check_type,
        COUNT(*) AS records_checked,
        ABS(COUNT(*) - e.silver_count) AS failures,
        CAST(e.silver_count AS STRING) AS expected_value,
        CAST(COUNT(*) AS STRING) AS actual_value
    FROM base
    CROSS JOIN expectations e
    GROUP BY e.silver_count

    UNION ALL

    -- Surrogate key completeness
    SELECT
        'dim_course',
        'Missing course_key',
        'NULL',
        COUNT(*),
        COUNT_IF(course_key IS NULL),
        '0',
        CAST(COUNT_IF(course_key IS NULL) AS STRING)
    FROM base

    UNION ALL

    -- Surrogate key uniqueness
    SELECT
        'dim_course',
        'Duplicate course_key',
        'UNIQUE',
        COUNT(*),
        COUNT(*) - COUNT(DISTINCT course_key),
        '0',
        CAST(
            COUNT(*) - COUNT(DISTINCT course_key)
            AS STRING
        )
    FROM base

    UNION ALL

    -- Natural business key uniqueness
    SELECT
        'dim_course',
        'Duplicate course business key',
        'UNIQUE',
        COUNT(*),
        COUNT(*) - COUNT(
            DISTINCT CONCAT(
                code_module,
                '|',
                code_presentation
            )
        ),
        '0',
        CAST(
            COUNT(*) - COUNT(
                DISTINCT CONCAT(
                    code_module,
                    '|',
                    code_presentation
                )
            )
            AS STRING
        )
    FROM base

    UNION ALL

    -- Required module code
    SELECT
        'dim_course',
        'Missing code_module',
        'NULL',
        COUNT(*),
        COUNT_IF(
            code_module IS NULL
            OR TRIM(code_module) = ''
        ),
        '0',
        CAST(
            COUNT_IF(
                code_module IS NULL
                OR TRIM(code_module) = ''
            )
            AS STRING
        )
    FROM base

    UNION ALL

    -- Required presentation code
    SELECT
        'dim_course',
        'Missing code_presentation',
        'NULL',
        COUNT(*),
        COUNT_IF(
            code_presentation IS NULL
            OR TRIM(code_presentation) = ''
        ),
        '0',
        CAST(
            COUNT_IF(
                code_presentation IS NULL
                OR TRIM(code_presentation) = ''
            )
            AS STRING
        )
    FROM base

    UNION ALL

    -- Course length should be positive when provided.
    SELECT
        'dim_course',
        'Invalid module presentation length',
        'RANGE',
        COUNT(*),
        COUNT_IF(
            module_presentation_length IS NULL
            OR module_presentation_length <= 0
        ),
        '> 0',
        CAST(
            COUNT_IF(
                module_presentation_length IS NULL
                OR module_presentation_length <= 0
            )
            AS STRING
        )
    FROM base

    UNION ALL

    -- Silver lineage
    SELECT
        'dim_course',
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
        'dim_course',
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

-- Calculate failure percentage before applying thresholds.
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

    -- Apply the thresholds defined in the DQ framework.
    CASE

        -- No actual failures means the check passes.
        WHEN failures = 0
        THEN 'PASS'

        -- Mandatory key fields: any NULL is a FAIL.
        WHEN check_type = 'NULL'
             AND check_name IN (
                 'Missing course_key',
                 'Missing code_module',
                 'Missing code_presentation'
             )
        THEN 'FAIL'

        -- UNIQUE / RANGE checks: 1% warning threshold.
        WHEN check_type IN (
            'UNIQUE',
            'RANGE'
        )
        AND failure_pct <= 1
        THEN 'WARN'

        WHEN check_type IN (
            'UNIQUE',
            'RANGE'
        )
        THEN 'FAIL'

        -- VOLUME: 2% warning threshold.
        WHEN check_type = 'VOLUME'
             AND failure_pct <= 2
        THEN 'WARN'

        WHEN check_type = 'VOLUME'
        THEN 'FAIL'

        -- Other NULL checks: 1% warning threshold.
        WHEN check_type = 'NULL'
             AND failure_pct <= 1
        THEN 'WARN'

        WHEN check_type = 'NULL'
        THEN 'FAIL'

        -- Lineage checks: 1% warning threshold.
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