-- ASSESSMENT SILVER DATA QUALITY VALIDATION

WITH base AS (
    SELECT *
    FROM oulad.oulad_silver.assessment_silver
),

-- Expected values are derived from Bronze to avoid hard-coded counts.
bronze_expectations AS (
    SELECT
        COUNT(*) AS bronze_count,
        SUM(
            CASE
                WHEN CAST(date AS STRING) = '?' THEN 1
                ELSE 0
            END
        ) AS expected_null_dates
    FROM oulad.oulad_bronze.assessment_bronze
),

-- Silver values are expected to be standardized, so direct comparison is used.
course_keys AS (
    SELECT DISTINCT
        code_module,
        code_presentation
    FROM oulad.oulad_silver.courses_silver
),

dq_results AS (

    -- Volume check
    SELECT
        'assessment_silver' AS table_name,
        'Row count' AS check_name,
        'VOLUME' AS check_type,
        COUNT(*) AS records_checked,
        ABS(COUNT(*) - e.bronze_count) AS failures,
        CAST(e.bronze_count AS STRING) AS expected_value
    FROM base
    CROSS JOIN bronze_expectations e
    GROUP BY e.bronze_count

    UNION ALL

    -- Required field checks
    SELECT
        'assessment_silver',
        'Missing id_assessment',
        'NULL',
        COUNT(*),
        COUNT_IF(id_assessment IS NULL),
        '0'
    FROM base

    UNION ALL

    SELECT
        'assessment_silver',
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

    SELECT
        'assessment_silver',
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

    SELECT
        'assessment_silver',
        'Missing assessment_type',
        'NULL',
        COUNT(*),
        COUNT_IF(
            assessment_type IS NULL
            OR TRIM(assessment_type) = ''
        ),
        '0'
    FROM base

    UNION ALL

    -- Date NULLs are expected when caused by '?' values in Bronze.
    SELECT
        'assessment_silver',
        'Missing assessment date',
        'NULL',
        COUNT(*),
        COUNT_IF(date IS NULL),
        CAST(e.expected_null_dates AS STRING)
    FROM base
    CROSS JOIN bronze_expectations e
    GROUP BY e.expected_null_dates

    UNION ALL

    -- Weight should be available and valid.
    SELECT
        'assessment_silver',
        'Missing weight',
        'NULL',
        COUNT(*),
        COUNT_IF(weight IS NULL),
        '0'
    FROM base

    UNION ALL

    -- Business key uniqueness.
    SELECT
        'assessment_silver',
        'Duplicate assessment business key',
        'UNIQUE',
        COUNT(*),
        COUNT(*) - COUNT(DISTINCT id_assessment),
        '0'
    FROM base

    UNION ALL

    -- No unresolved source sentinel values should remain.
    SELECT
        'assessment_silver',
        'Unresolved sentinel (?) values',
        'SENTINEL',
        COUNT(*),
        COUNT_IF(
            CAST(id_assessment AS STRING) = '?'
            OR code_module = '?'
            OR code_presentation = '?'
            OR assessment_type = '?'
            OR CAST(date AS STRING) = '?'
            OR CAST(weight AS STRING) = '?'
        ),
        '0'
    FROM base

    UNION ALL

    -- Weight range.
    SELECT
        'assessment_silver',
        'Invalid weight range',
        'RANGE',
        COUNT(*),
        COUNT_IF(
            weight < 0
            OR weight > 100
        ),
        '0'
    FROM base

    UNION ALL

    -- Assessment type validation.
    SELECT
        'assessment_silver',
        'Invalid assessment_type',
        'ACCEPTED VALUE',
        COUNT(*),
        COUNT_IF(
            assessment_type NOT IN ('TMA', 'CMA', 'Exam')
        ),
        '0'
    FROM base

    UNION ALL

    -- Standardization checks.
    SELECT
        'assessment_silver',
        'Untrimmed module/presentation values',
        'STANDARDIZATION',
        COUNT(*),
        COUNT_IF(
            code_module <> TRIM(code_module)
            OR code_presentation <> TRIM(code_presentation)
            OR assessment_type <> TRIM(assessment_type)
        ),
        '0'
    FROM base

    UNION ALL

    -- Foreign key to courses.
    SELECT
        'assessment_silver',
        'Assessment without matching course',
        'FOREIGN KEY',
        COUNT(*),
        COUNT_IF(c.code_module IS NULL),
        '0'
    FROM base a
    LEFT JOIN course_keys c
        ON a.code_module = c.code_module
       AND a.code_presentation = c.code_presentation

    UNION ALL

    -- Bronze lineage.
    SELECT
        'assessment_silver',
        'Missing Bronze ingestion timestamp',
        'LINEAGE',
        COUNT(*),
        COUNT_IF(bronze_ingestion_timestamp IS NULL),
        '0'
    FROM base

    UNION ALL

    -- Silver processing metadata.
    SELECT
        'assessment_silver',
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

        -- Expected NULLs are acceptable when they match the source expectation.
        WHEN check_name = 'Missing assessment date'
             AND CAST(failures AS STRING) = expected_value
        THEN 'PASS'

        -- No actual failures means the check passes.
        WHEN failures = 0
        THEN 'PASS'

        -- Mandatory key fields: any NULL is a FAIL.
        WHEN check_type = 'NULL'
             AND check_name IN (
                 'Missing id_assessment',
                 'Missing code_module',
                 'Missing code_presentation',
                 'Missing assessment_type'
             )
        THEN 'FAIL'

        -- UNIQUE / RANGE / ACCEPTED VALUE: 1% warning threshold.
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

        -- FOREIGN KEY: 0.1% warning threshold.
        WHEN check_type = 'FOREIGN KEY'
             AND failure_pct <= 0.1
        THEN 'WARN'

        WHEN check_type = 'FOREIGN KEY'
        THEN 'FAIL'

        -- VOLUME: 2% warning threshold.
        WHEN check_type = 'VOLUME'
             AND failure_pct <= 2
        THEN 'WARN'

        WHEN check_type = 'VOLUME'
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