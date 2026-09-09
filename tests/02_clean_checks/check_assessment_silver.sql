-- ASSESSMENT SILVER DATA QUALITY VALIDATION

WITH base AS (
    SELECT *
    FROM oulad.oulad_silver.assessment_silver
),

course_keys AS (
    SELECT DISTINCT
        TRIM(UPPER(code_module)) AS code_module,
        TRIM(UPPER(code_presentation)) AS code_presentation
    FROM oulad.oulad_silver.courses_silver
),

dq_results AS (

    -- Volume check
    SELECT
        'assessment_silver' AS table_name,
        'Row count' AS check_name,
        'VOLUME' AS check_type,
        COUNT(*) AS records_checked,
        CASE
            WHEN COUNT(*) = 206 THEN 0
            ELSE ABS(COUNT(*) - 206)
        END AS failures
    FROM base

    UNION ALL

    -- Required field checks
    SELECT
        'assessment_silver',
        'Missing id_assessment',
        'NULL',
        COUNT(*),
        SUM(CASE WHEN id_assessment IS NULL THEN 1 ELSE 0 END)
    FROM base

    UNION ALL

    SELECT
        'assessment_silver',
        'Missing code_module',
        'NULL',
        COUNT(*),
        SUM(CASE WHEN code_module IS NULL OR TRIM(code_module) = '' THEN 1 ELSE 0 END)
    FROM base

    UNION ALL

    SELECT
        'assessment_silver',
        'Missing code_presentation',
        'NULL',
        COUNT(*),
        SUM(CASE WHEN code_presentation IS NULL OR TRIM(code_presentation) = '' THEN 1 ELSE 0 END)
    FROM base

    UNION ALL

    SELECT
        'assessment_silver',
        'Missing assessment_type',
        'NULL',
        COUNT(*),
        SUM(CASE WHEN assessment_type IS NULL OR TRIM(assessment_type) = '' THEN 1 ELSE 0 END)
    FROM base

    UNION ALL

    -- Date NULLs are allowed because Bronze contained documented '?' values
    SELECT
        'assessment_silver',
        'Missing assessment date',
        'NULL',
        COUNT(*),
        SUM(CASE WHEN date IS NULL THEN 1 ELSE 0 END)
    FROM base

    UNION ALL

    -- Weight should be available and valid
    SELECT
        'assessment_silver',
        'Missing weight',
        'NULL',
        COUNT(*),
        SUM(CASE WHEN weight IS NULL THEN 1 ELSE 0 END)
    FROM base

    UNION ALL

    -- Business key uniqueness
    SELECT
        'assessment_silver',
        'Duplicate assessment business key',
        'UNIQUE',
        COUNT(*),
        COUNT(*) - COUNT(DISTINCT id_assessment)
    FROM base

    UNION ALL

    -- No unresolved source sentinel values should remain
    SELECT
        'assessment_silver',
        'Unresolved sentinel (?) values',
        'SENTINEL',
        COUNT(*),
        SUM(
            CASE
                WHEN CAST(id_assessment AS STRING) = '?'
                  OR code_module = '?'
                  OR code_presentation = '?'
                  OR assessment_type = '?'
                  OR CAST(date AS STRING) = '?'
                  OR CAST(weight AS STRING) = '?'
                THEN 1
                ELSE 0
            END
        )
    FROM base

    UNION ALL

    -- Weight range
    SELECT
        'assessment_silver',
        'Invalid weight range',
        'RANGE',
        COUNT(*),
        SUM(
            CASE
                WHEN weight < 0 OR weight > 100 THEN 1
                ELSE 0
            END
        )
    FROM base

    UNION ALL

    -- Assessment type validation
    SELECT
        'assessment_silver',
        'Invalid assessment_type',
        'ACCEPTED VALUE',
        COUNT(*),
        SUM(
            CASE
                WHEN assessment_type NOT IN ('TMA', 'CMA', 'Exam')
                THEN 1
                ELSE 0
            END
        )
    FROM base

    UNION ALL

    -- Standardization checks
    SELECT
        'assessment_silver',
        'Untrimmed module/presentation values',
        'STANDARDIZATION',
        COUNT(*),
        SUM(
            CASE
                WHEN code_module <> TRIM(code_module)
                  OR code_presentation <> TRIM(code_presentation)
                  OR assessment_type <> TRIM(assessment_type)
                THEN 1
                ELSE 0
            END
        )
    FROM base

    UNION ALL

    -- Foreign key to courses
    SELECT
        'assessment_silver',
        'Assessment without matching course',
        'FOREIGN KEY',
        COUNT(*),
        SUM(
            CASE
                WHEN c.code_module IS NULL THEN 1
                ELSE 0
            END
        )
    FROM base a
    LEFT JOIN course_keys c
        ON TRIM(UPPER(a.code_module)) = c.code_module
       AND TRIM(UPPER(a.code_presentation)) = c.code_presentation

    UNION ALL

    -- Bronze lineage
    SELECT
        'assessment_silver',
        'Missing Bronze ingestion timestamp',
        'LINEAGE',
        COUNT(*),
        SUM(
            CASE
                WHEN bronze_ingestion_timestamp IS NULL THEN 1
                ELSE 0
            END
        )
    FROM base

    UNION ALL

    -- Silver processing metadata
    SELECT
        'assessment_silver',
        'Missing Silver processing timestamp',
        'LINEAGE',
        COUNT(*),
        SUM(
            CASE
                WHEN silver_processed_timestamp IS NULL THEN 1
                ELSE 0
            END
        )
    FROM base
)

SELECT
    table_name,
    check_name,
    check_type,
    records_checked,
    failures,
    ROUND(
        failures * 100.0 / NULLIF(records_checked, 0),
        2
    ) AS failure_percentage,

    CASE
        WHEN failures = 0 THEN 'PASS'

        -- Assessment date NULLs are expected because
        -- Bronze contained 11 documented '?' values.
        WHEN check_name = 'Missing assessment date'
             AND failures = 11 THEN 'PASS'

        ELSE 'FAIL'
    END AS status

FROM dq_results

ORDER BY
    CASE
        WHEN status = 'FAIL' THEN 1
        WHEN status = 'WARN' THEN 2
        ELSE 3
    END,
    check_type,
    check_name;