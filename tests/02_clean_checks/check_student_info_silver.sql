-- STUDENT INFO SILVER DATA QUALITY VALIDATION

WITH base AS (
    SELECT *
    FROM oulad.oulad_silver.student_info_silver
),

-- Expected values are derived from Bronze to avoid hard-coded counts.
bronze_expectations AS (
    SELECT
        COUNT(*) AS bronze_count,
        SUM(
            CASE
                WHEN TRIM(imd_band) = '?' THEN 1
                ELSE 0
            END
        ) AS expected_null_imd_band
    FROM oulad.oulad_bronze.student_info_bronze
),

course_keys AS (
    SELECT DISTINCT
        code_module,
        code_presentation
    FROM oulad.oulad_silver.courses_silver
),

dq_results AS (

    -- Volume check
    SELECT
        'student_info_silver' AS table_name,
        'Row count' AS check_name,
        'VOLUME' AS check_type,
        COUNT(*) AS records_checked,
        ABS(COUNT(*) - e.bronze_count) AS failures,
        CAST(e.bronze_count AS STRING) AS expected_value
    FROM base
    CROSS JOIN bronze_expectations e
    GROUP BY e.bronze_count

    UNION ALL

    -- Required fields
    SELECT
        'student_info_silver',
        'Missing code_module',
        'NULL',
        COUNT(*),
        COUNT_IF(code_module IS NULL),
        '0'
    FROM base

    UNION ALL

    SELECT
        'student_info_silver',
        'Missing code_presentation',
        'NULL',
        COUNT(*),
        COUNT_IF(code_presentation IS NULL),
        '0'
    FROM base

    UNION ALL

    SELECT
        'student_info_silver',
        'Missing id_student',
        'NULL',
        COUNT(*),
        COUNT_IF(id_student IS NULL),
        '0'
    FROM base

    UNION ALL

    -- Categorical fields expected to be populated
    SELECT
        'student_info_silver',
        'Missing gender',
        'NULL',
        COUNT(*),
        COUNT_IF(gender IS NULL),
        '0'
    FROM base

    UNION ALL

    SELECT
        'student_info_silver',
        'Missing region',
        'NULL',
        COUNT(*),
        COUNT_IF(region IS NULL),
        '0'
    FROM base

    UNION ALL

    SELECT
        'student_info_silver',
        'Missing highest_education',
        'NULL',
        COUNT(*),
        COUNT_IF(highest_education IS NULL),
        '0'
    FROM base

    UNION ALL

    -- imd_band NULLs are expected because Bronze contained '?'
    SELECT
        'student_info_silver',
        'Missing imd_band',
        'NULL',
        COUNT(*),
        COUNT_IF(imd_band IS NULL),
        CAST(e.expected_null_imd_band AS STRING)
    FROM base
    CROSS JOIN bronze_expectations e
    GROUP BY e.expected_null_imd_band

    UNION ALL

    SELECT
        'student_info_silver',
        'Missing age_band',
        'NULL',
        COUNT(*),
        COUNT_IF(age_band IS NULL),
        '0'
    FROM base

    UNION ALL

    SELECT
        'student_info_silver',
        'Missing disability',
        'NULL',
        COUNT(*),
        COUNT_IF(disability IS NULL),
        '0'
    FROM base

    UNION ALL

    SELECT
        'student_info_silver',
        'Missing final_result',
        'NULL',
        COUNT(*),
        COUNT_IF(final_result IS NULL),
        '0'
    FROM base

    UNION ALL

    -- Numeric fields
    SELECT
        'student_info_silver',
        'Missing num_of_prev_attempts',
        'NULL',
        COUNT(*),
        COUNT_IF(num_of_prev_attempts IS NULL),
        '0'
    FROM base

    UNION ALL

    SELECT
        'student_info_silver',
        'Missing studied_credits',
        'NULL',
        COUNT(*),
        COUNT_IF(studied_credits IS NULL),
        '0'
    FROM base

    UNION ALL

    -- Range checks
    SELECT
        'student_info_silver',
        'Invalid num_of_prev_attempts',
        'RANGE',
        COUNT(*),
        COUNT_IF(num_of_prev_attempts < 0),
        '0'
    FROM base

    UNION ALL

    SELECT
        'student_info_silver',
        'Invalid studied_credits',
        'RANGE',
        COUNT(*),
        COUNT_IF(studied_credits < 0),
        '0'
    FROM base

    UNION ALL

    -- Business key uniqueness
    SELECT
        'student_info_silver',
        'Duplicate student-module-presentation business key',
        'UNIQUE',
        COUNT(*),
        COUNT(*) - COUNT(DISTINCT
            CONCAT(
                code_module, '|',
                code_presentation, '|',
                id_student
            )
        ),
        '0'
    FROM base

    UNION ALL

    -- Sentinel cleanup
    SELECT
        'student_info_silver',
        'Unresolved sentinel (?) values',
        'SENTINEL',
        COUNT(*),
        COUNT_IF(
            gender = '?'
            OR region = '?'
            OR highest_education = '?'
            OR imd_band = '?'
            OR age_band = '?'
            OR disability = '?'
            OR final_result = '?'
        ),
        '0'
    FROM base

    UNION ALL

    -- Standardization
    SELECT
        'student_info_silver',
        'Untrimmed categorical values',
        'STANDARDIZATION',
        COUNT(*),
        COUNT_IF(
            code_module <> TRIM(code_module)
            OR code_presentation <> TRIM(code_presentation)
            OR gender <> TRIM(gender)
            OR region <> TRIM(region)
            OR highest_education <> TRIM(highest_education)
            OR age_band <> TRIM(age_band)
            OR disability <> TRIM(disability)
            OR final_result <> TRIM(final_result)
        ),
        '0'
    FROM base

    UNION ALL

    -- Foreign key to courses
    SELECT
        'student_info_silver',
        'Student record without matching course',
        'FOREIGN KEY',
        COUNT(*),
        COUNT_IF(c.code_module IS NULL),
        '0'
    FROM base s
    LEFT JOIN course_keys c
        ON s.code_module = c.code_module
        AND s.code_presentation = c.code_presentation

    UNION ALL

    -- Bronze lineage
    SELECT
        'student_info_silver',
        'Missing Bronze ingestion timestamp',
        'LINEAGE',
        COUNT(*),
        COUNT_IF(bronze_ingestion_timestamp IS NULL),
        '0'
    FROM base

    UNION ALL

    SELECT
        'student_info_silver',
        'Missing Bronze ingestion date',
        'LINEAGE',
        COUNT(*),
        COUNT_IF(bronze_ingestion_date IS NULL),
        '0'
    FROM base

    UNION ALL

    -- Silver processing lineage
    SELECT
        'student_info_silver',
        'Missing Silver processing timestamp',
        'LINEAGE',
        COUNT(*),
        COUNT_IF(silver_processed_timestamp IS NULL),
        '0'
    FROM base

    UNION ALL

    SELECT
        'student_info_silver',
        'Missing Silver processing date',
        'LINEAGE',
        COUNT(*),
        COUNT_IF(silver_processed_date IS NULL),
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

        -- Expected imd_band NULLs are acceptable when they match Bronze.
        WHEN check_name = 'Missing imd_band'
             AND CAST(failures AS STRING) = expected_value
        THEN 'PASS'

        -- No actual failures means the check passes.
        WHEN failures = 0
        THEN 'PASS'

        -- Mandatory key fields: any NULL is a FAIL.
        WHEN check_name IN (
            'Missing code_module',
            'Missing code_presentation',
            'Missing id_student'
        )
        THEN 'FAIL'

        -- UNIQUE / RANGE: 1% warning threshold.
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

        -- Non-key NULL: 1% warning threshold.
        WHEN check_type = 'NULL'
             AND failure_pct <= 1
        THEN 'WARN'

        WHEN check_type = 'NULL'
        THEN 'FAIL'

        -- FOREIGN KEY: 0.1% warning threshold.
        WHEN check_type = 'FOREIGN KEY'
             AND failure_pct <= 0.1
        THEN 'WARN'

        WHEN check_type = 'FOREIGN KEY'
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