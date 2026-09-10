-- COURSES SILVER DATA QUALITY VALIDATION

WITH base AS (
    SELECT *
    FROM oulad.oulad_silver.courses_silver
),

-- Expected row count is derived from the current Bronze data.
bronze_expectations AS (
    SELECT
        COUNT(*) AS bronze_count
    FROM oulad.oulad_bronze.courses_bronze
),

dq_results AS (

    -- Volume check
    SELECT
        'courses_silver' AS table_name,
        'Row count' AS check_name,
        'VOLUME' AS check_type,
        COUNT(*) AS records_checked,
        ABS(COUNT(*) - e.bronze_count) AS failures,
        CAST(e.bronze_count AS STRING) AS expected_value
    FROM base
    CROSS JOIN bronze_expectations e
    GROUP BY e.bronze_count

    UNION ALL

    -- Missing module
    SELECT
        'courses_silver',
        'Missing code_module',
        'NULL',
        COUNT(*),
        COUNT_IF(
            code_module IS NULL
            OR TRIM(code_module) = ''
        ),
        '0'
    FROM base

    UNION ALL

    -- Missing presentation
    SELECT
        'courses_silver',
        'Missing code_presentation',
        'NULL',
        COUNT(*),
        COUNT_IF(
            code_presentation IS NULL
            OR TRIM(code_presentation) = ''
        ),
        '0'
    FROM base

    UNION ALL

    -- Missing duration
    SELECT
        'courses_silver',
        'Missing module presentation length',
        'NULL',
        COUNT(*),
        COUNT_IF(module_presentation_length IS NULL),
        '0'
    FROM base

    UNION ALL

    -- Positive duration
    SELECT
        'courses_silver',
        'Invalid module presentation length',
        'RANGE',
        COUNT(*),
        COUNT_IF(module_presentation_length <= 0),
        '0'
    FROM base

    UNION ALL

    -- Duplicate business key
    SELECT
        'courses_silver',
        'Duplicate course business key',
        'UNIQUE',
        COUNT(*),
        COUNT(*) - COUNT(DISTINCT
            CONCAT(code_module, '|', code_presentation)
        ),
        '0'
    FROM base

    UNION ALL

    -- Sentinel check
    SELECT
        'courses_silver',
        'Unresolved sentinel (?) values',
        'SENTINEL',
        COUNT(*),
        COUNT_IF(
            code_module = '?'
            OR code_presentation = '?'
        ),
        '0'
    FROM base

    UNION ALL

    -- Standardization check
    SELECT
        'courses_silver',
        'Unstandardized module/presentation values',
        'STANDARDIZATION',
        COUNT(*),
        COUNT_IF(
            code_module <> UPPER(TRIM(code_module))
            OR code_presentation <> UPPER(TRIM(code_presentation))
        ),
        '0'
    FROM base

    UNION ALL

    -- Bronze lineage
    SELECT
        'courses_silver',
        'Missing Bronze ingestion timestamp',
        'LINEAGE',
        COUNT(*),
        COUNT_IF(bronze_ingestion_timestamp IS NULL),
        '0'
    FROM base

    UNION ALL

    -- Silver processing lineage
    SELECT
        'courses_silver',
        'Missing Silver processing timestamp',
        'LINEAGE',
        COUNT(*),
        COUNT_IF(silver_processed_timestamp IS NULL),
        '0'
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
    failure_pct,

    -- Apply the thresholds defined in the DQ framework.
    CASE
        -- No actual failures means the check passes.
        WHEN failures = 0
        THEN 'PASS'

        -- Mandatory key fields: any NULL is a FAIL.
        WHEN check_type = 'NULL'
             AND check_name IN (
                 'Missing code_module',
                 'Missing code_presentation'
             )
        THEN 'FAIL'

        -- UNIQUE / RANGE: 1% warning threshold.
        WHEN check_type IN ('UNIQUE', 'RANGE')
             AND failure_pct <= 1
        THEN 'WARN'

        WHEN check_type IN ('UNIQUE', 'RANGE')
        THEN 'FAIL'

        -- Non-key NULL: 1% warning threshold.
        WHEN check_type = 'NULL'
             AND failure_pct <= 1
        THEN 'WARN'

        WHEN check_type = 'NULL'
        THEN 'FAIL'

        -- Other checks: 1% warning threshold.
        WHEN check_type IN (
            'SENTINEL',
            'STANDARDIZATION',
            'LINEAGE'
        )
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