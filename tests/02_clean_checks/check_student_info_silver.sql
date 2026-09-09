-- STUDENT INFO SILVER DATA QUALITY VALIDATION

WITH checks AS (

    -- Volume check
    SELECT
        'student_info_silver' AS table_name,
        'Row count' AS check_name,
        'VOLUME' AS check_type,
        (SELECT COUNT(*) FROM oulad.oulad_silver.student_info_silver) AS records_checked,
        ABS(
            (SELECT COUNT(*) FROM oulad.oulad_silver.student_info_silver)
            - (SELECT COUNT(*) FROM oulad.oulad_bronze.student_info_bronze)
        ) AS failures

    UNION ALL

    -- Required fields
    SELECT
        'student_info_silver',
        'Missing code_module',
        'NULL',
        COUNT(*),
        SUM(CASE WHEN code_module IS NULL THEN 1 ELSE 0 END)
    FROM oulad.oulad_silver.student_info_silver

    UNION ALL

    SELECT
        'student_info_silver',
        'Missing code_presentation',
        'NULL',
        COUNT(*),
        SUM(CASE WHEN code_presentation IS NULL THEN 1 ELSE 0 END)
    FROM oulad.oulad_silver.student_info_silver

    UNION ALL

    SELECT
        'student_info_silver',
        'Missing id_student',
        'NULL',
        COUNT(*),
        SUM(CASE WHEN id_student IS NULL THEN 1 ELSE 0 END)
    FROM oulad.oulad_silver.student_info_silver

    UNION ALL

    -- Categorical fields expected to be populated
    SELECT
        'student_info_silver',
        'Missing gender',
        'NULL',
        COUNT(*),
        SUM(CASE WHEN gender IS NULL THEN 1 ELSE 0 END)
    FROM oulad.oulad_silver.student_info_silver

    UNION ALL

    SELECT
        'student_info_silver',
        'Missing region',
        'NULL',
        COUNT(*),
        SUM(CASE WHEN region IS NULL THEN 1 ELSE 0 END)
    FROM oulad.oulad_silver.student_info_silver

    UNION ALL

    SELECT
        'student_info_silver',
        'Missing highest_education',
        'NULL',
        COUNT(*),
        SUM(CASE WHEN highest_education IS NULL THEN 1 ELSE 0 END)
    FROM oulad.oulad_silver.student_info_silver

    UNION ALL

    -- imd_band NULLs are expected because Bronze contained '?'
    SELECT
        'student_info_silver',
        'Unexpected missing imd_band',
        'NULL',
        COUNT(*),
        ABS(
            COUNT(*) FILTER (WHERE imd_band IS NULL)
            - (
                SELECT COUNT(*)
                FROM oulad.oulad_bronze.student_info_bronze
                WHERE TRIM(imd_band) = '?'
            )
        )
    FROM oulad.oulad_silver.student_info_silver

    UNION ALL

    SELECT
        'student_info_silver',
        'Missing age_band',
        'NULL',
        COUNT(*),
        SUM(CASE WHEN age_band IS NULL THEN 1 ELSE 0 END)
    FROM oulad.oulad_silver.student_info_silver

    UNION ALL

    SELECT
        'student_info_silver',
        'Missing disability',
        'NULL',
        COUNT(*),
        SUM(CASE WHEN disability IS NULL THEN 1 ELSE 0 END)
    FROM oulad.oulad_silver.student_info_silver

    UNION ALL

    SELECT
        'student_info_silver',
        'Missing final_result',
        'NULL',
        COUNT(*),
        SUM(CASE WHEN final_result IS NULL THEN 1 ELSE 0 END)
    FROM oulad.oulad_silver.student_info_silver

    UNION ALL

    -- Numeric fields
    SELECT
        'student_info_silver',
        'Missing num_of_prev_attempts',
        'NULL',
        COUNT(*),
        SUM(CASE WHEN num_of_prev_attempts IS NULL THEN 1 ELSE 0 END)
    FROM oulad.oulad_silver.student_info_silver

    UNION ALL

    SELECT
        'student_info_silver',
        'Missing studied_credits',
        'NULL',
        COUNT(*),
        SUM(CASE WHEN studied_credits IS NULL THEN 1 ELSE 0 END)
    FROM oulad.oulad_silver.student_info_silver

    UNION ALL

    -- Range checks
    SELECT
        'student_info_silver',
        'Invalid num_of_prev_attempts',
        'RANGE',
        COUNT(*),
        SUM(
            CASE
                WHEN num_of_prev_attempts < 0 THEN 1
                ELSE 0
            END
        )
    FROM oulad.oulad_silver.student_info_silver

    UNION ALL

    SELECT
        'student_info_silver',
        'Invalid studied_credits',
        'RANGE',
        COUNT(*),
        SUM(
            CASE
                WHEN studied_credits < 0 THEN 1
                ELSE 0
            END
        )
    FROM oulad.oulad_silver.student_info_silver

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
        )
    FROM oulad.oulad_silver.student_info_silver

    UNION ALL

    -- Sentinel cleanup
    SELECT
        'student_info_silver',
        'Unresolved sentinel (?) values',
        'SENTINEL',
        COUNT(*),
        SUM(
            CASE
                WHEN gender = '?'
                  OR region = '?'
                  OR highest_education = '?'
                  OR imd_band = '?'
                  OR age_band = '?'
                  OR disability = '?'
                  OR final_result = '?'
                THEN 1
                ELSE 0
            END
        )
    FROM oulad.oulad_silver.student_info_silver

    UNION ALL

    -- Standardization
    SELECT
        'student_info_silver',
        'Untrimmed categorical values',
        'STANDARDIZATION',
        COUNT(*),
        SUM(
            CASE
                WHEN code_module <> TRIM(code_module)
                  OR code_presentation <> TRIM(code_presentation)
                  OR gender <> TRIM(gender)
                  OR region <> TRIM(region)
                  OR highest_education <> TRIM(highest_education)
                  OR age_band <> TRIM(age_band)
                  OR disability <> TRIM(disability)
                  OR final_result <> TRIM(final_result)
                THEN 1
                ELSE 0
            END
        )
    FROM oulad.oulad_silver.student_info_silver

    UNION ALL

    -- Foreign key to courses
    SELECT
        'student_info_silver',
        'Student record without matching course',
        'FOREIGN KEY',
        COUNT(*),
        COUNT(*)
    FROM oulad.oulad_silver.student_info_silver s
    LEFT JOIN oulad.oulad_silver.courses_silver c
        ON s.code_module = c.code_module
        AND s.code_presentation = c.code_presentation
    WHERE c.code_module IS NULL

    UNION ALL

    -- Bronze lineage
    SELECT
        'student_info_silver',
        'Missing Bronze ingestion timestamp',
        'LINEAGE',
        COUNT(*),
        SUM(
            CASE
                WHEN bronze_ingestion_timestamp IS NULL THEN 1
                ELSE 0
            END
        )
    FROM oulad.oulad_silver.student_info_silver

    UNION ALL

    SELECT
        'student_info_silver',
        'Missing Bronze ingestion date',
        'LINEAGE',
        COUNT(*),
        SUM(
            CASE
                WHEN bronze_ingestion_date IS NULL THEN 1
                ELSE 0
            END
        )
    FROM oulad.oulad_silver.student_info_silver

    UNION ALL

    -- Silver processing lineage
    SELECT
        'student_info_silver',
        'Missing Silver processing timestamp',
        'LINEAGE',
        COUNT(*),
        SUM(
            CASE
                WHEN silver_processed_timestamp IS NULL THEN 1
                ELSE 0
            END
        )
    FROM oulad.oulad_silver.student_info_silver

    UNION ALL

    SELECT
        'student_info_silver',
        'Missing Silver processing date',
        'LINEAGE',
        COUNT(*),
        SUM(
            CASE
                WHEN silver_processed_date IS NULL THEN 1
                ELSE 0
            END
        )
    FROM oulad.oulad_silver.student_info_silver
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
        WHEN check_name = 'Unexpected missing imd_band'
             AND failures = 0
            THEN 'PASS'

        WHEN check_type IN ('VOLUME', 'NULL', 'RANGE', 'UNIQUE',
                            'SENTINEL', 'STANDARDIZATION',
                            'FOREIGN KEY', 'LINEAGE')
             AND failures = 0
            THEN 'PASS'

        WHEN check_type IN ('VOLUME', 'NULL', 'RANGE', 'UNIQUE',
                            'SENTINEL', 'STANDARDIZATION',
                            'FOREIGN KEY', 'LINEAGE')
             AND failures * 100.0 / NULLIF(records_checked, 0) <= 1
            THEN 'WARN'

        ELSE 'FAIL'
    END AS status

FROM checks

ORDER BY
    CASE
        WHEN status = 'FAIL' THEN 1
        WHEN status = 'WARN' THEN 2
        ELSE 3
    END,
    check_type,
    check_name;