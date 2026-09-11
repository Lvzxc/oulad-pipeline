-- STUDENT INFO SILVER DATA QUALITY VALIDATION

WITH base AS (
    SELECT *
    FROM oulad.oulad_silver.student_info_silver
),

table_count AS (
    SELECT COUNT(*) AS total_records
    FROM base
),

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
        TRIM(UPPER(code_module)) AS code_module,
        TRIM(UPPER(code_presentation)) AS code_presentation
    FROM oulad.oulad_silver.courses_silver
),

exact_duplicate_count AS (
    SELECT
        COALESCE(SUM(duplicate_count - 1), 0) AS duplicate_records
    FROM (
        SELECT
            code_module,
            code_presentation,
            id_student,
            gender,
            region,
            highest_education,
            imd_band,
            age_band,
            num_of_prev_attempts,
            studied_credits,
            disability,
            final_result,
            COUNT(*) AS duplicate_count
        FROM base
        GROUP BY
            code_module,
            code_presentation,
            id_student,
            gender,
            region,
            highest_education,
            imd_band,
            age_band,
            num_of_prev_attempts,
            studied_credits,
            disability,
            final_result
        HAVING COUNT(*) > 1
    ) d
),

checks (
    table_name,
    column_name,
    dq_dimension,
    rule_name,
    severity,
    expected_value,
    actual_value,
    total_records,
    passed_records,
    failed_records
) AS (

    -- Volume
    SELECT
        'student_info_silver',
        NULL,
        'VOLUME',
        'Silver row count matches Bronze row count',
        'INFO',
        CAST(e.bronze_count AS STRING),
        CAST(tc.total_records AS STRING),
        tc.total_records,
        tc.total_records - ABS(tc.total_records - e.bronze_count),
        ABS(tc.total_records - e.bronze_count)
    FROM table_count tc
    CROSS JOIN bronze_expectations e

    UNION ALL

    -- Required fields
    SELECT
        'student_info_silver',
        'code_module',
        'NULL',
        'Required code_module is not NULL',
        'FAIL',
        '0',
        CAST(COUNT_IF(code_module IS NULL) AS STRING),
        COUNT(*),
        COUNT(*) - COUNT_IF(code_module IS NULL),
        COUNT_IF(code_module IS NULL)
    FROM base

    UNION ALL

    SELECT
        'student_info_silver',
        'code_presentation',
        'NULL',
        'Required code_presentation is not NULL',
        'FAIL',
        '0',
        CAST(COUNT_IF(code_presentation IS NULL) AS STRING),
        COUNT(*),
        COUNT(*) - COUNT_IF(code_presentation IS NULL),
        COUNT_IF(code_presentation IS NULL)
    FROM base

    UNION ALL

    SELECT
        'student_info_silver',
        'id_student',
        'NULL',
        'Required id_student is not NULL',
        'FAIL',
        '0',
        CAST(COUNT_IF(id_student IS NULL) AS STRING),
        COUNT(*),
        COUNT(*) - COUNT_IF(id_student IS NULL),
        COUNT_IF(id_student IS NULL)
    FROM base

    UNION ALL

    SELECT
        'student_info_silver',
        'gender',
        'NULL',
        'Gender is not NULL',
        'FAIL',
        '0',
        CAST(COUNT_IF(gender IS NULL) AS STRING),
        COUNT(*),
        COUNT(*) - COUNT_IF(gender IS NULL),
        COUNT_IF(gender IS NULL)
    FROM base

    UNION ALL

    SELECT
        'student_info_silver',
        'region',
        'NULL',
        'Region is not NULL',
        'FAIL',
        '0',
        CAST(COUNT_IF(region IS NULL) AS STRING),
        COUNT(*),
        COUNT(*) - COUNT_IF(region IS NULL),
        COUNT_IF(region IS NULL)
    FROM base

    UNION ALL

    SELECT
        'student_info_silver',
        'highest_education',
        'NULL',
        'Highest education is not NULL',
        'FAIL',
        '0',
        CAST(COUNT_IF(highest_education IS NULL) AS STRING),
        COUNT(*),
        COUNT(*) - COUNT_IF(highest_education IS NULL),
        COUNT_IF(highest_education IS NULL)
    FROM base

    UNION ALL

    -- Expected NULLs originate from Bronze '?'
    SELECT
        'student_info_silver',
        'imd_band',
        'NULL',
        'NULL imd_band values match expected Bronze sentinel count',
        'WARN',
        CAST(e.expected_null_imd_band AS STRING),
        CAST(COUNT_IF(s.imd_band IS NULL) AS STRING),
        COUNT(*),
        COUNT(*) - COUNT_IF(s.imd_band IS NULL),
        COUNT_IF(s.imd_band IS NULL)
    FROM base s
    CROSS JOIN bronze_expectations e
    GROUP BY e.expected_null_imd_band

    UNION ALL

    SELECT
        'student_info_silver',
        'age_band',
        'NULL',
        'Age band is not NULL',
        'FAIL',
        '0',
        CAST(COUNT_IF(age_band IS NULL) AS STRING),
        COUNT(*),
        COUNT(*) - COUNT_IF(age_band IS NULL),
        COUNT_IF(age_band IS NULL)
    FROM base

    UNION ALL

    SELECT
        'student_info_silver',
        'disability',
        'NULL',
        'Disability is not NULL',
        'FAIL',
        '0',
        CAST(COUNT_IF(disability IS NULL) AS STRING),
        COUNT(*),
        COUNT(*) - COUNT_IF(disability IS NULL),
        COUNT_IF(disability IS NULL)
    FROM base

    UNION ALL

    SELECT
        'student_info_silver',
        'final_result',
        'NULL',
        'Final result is not NULL',
        'FAIL',
        '0',
        CAST(COUNT_IF(final_result IS NULL) AS STRING),
        COUNT(*),
        COUNT(*) - COUNT_IF(final_result IS NULL),
        COUNT_IF(final_result IS NULL)
    FROM base

    UNION ALL

    -- Numeric fields
    SELECT
        'student_info_silver',
        'num_of_prev_attempts',
        'NULL',
        'Previous attempts is not NULL',
        'FAIL',
        '0',
        CAST(COUNT_IF(num_of_prev_attempts IS NULL) AS STRING),
        COUNT(*),
        COUNT(*) - COUNT_IF(num_of_prev_attempts IS NULL),
        COUNT_IF(num_of_prev_attempts IS NULL)
    FROM base

    UNION ALL

    SELECT
        'student_info_silver',
        'studied_credits',
        'NULL',
        'Studied credits is not NULL',
        'FAIL',
        '0',
        CAST(COUNT_IF(studied_credits IS NULL) AS STRING),
        COUNT(*),
        COUNT(*) - COUNT_IF(studied_credits IS NULL),
        COUNT_IF(studied_credits IS NULL)
    FROM base

    UNION ALL

    -- Range checks
    SELECT
        'student_info_silver',
        'num_of_prev_attempts',
        'RANGE',
        'Previous attempts is not negative',
        'FAIL',
        '0 invalid records',
        CAST(COUNT_IF(num_of_prev_attempts < 0) AS STRING),
        COUNT(*),
        COUNT(*) - COUNT_IF(num_of_prev_attempts < 0),
        COUNT_IF(num_of_prev_attempts < 0)
    FROM base

    UNION ALL

    SELECT
        'student_info_silver',
        'studied_credits',
        'RANGE',
        'Studied credits is greater than 0',
        'FAIL',
        '0 invalid records',
        CAST(COUNT_IF(studied_credits <= 0) AS STRING),
        COUNT(*),
        COUNT(*) - COUNT_IF(studied_credits <= 0),
        COUNT_IF(studied_credits <= 0)
    FROM base

    UNION ALL

    -- Business key uniqueness
    SELECT
        'student_info_silver',
        NULL,
        'UNIQUE',
        'Student-module-presentation business key is unique',
        'FAIL',
        '0 duplicate records',
        CAST(
            COUNT(*) - COUNT(DISTINCT CONCAT(
                code_module,
                '|',
                code_presentation,
                '|',
                id_student
            ))
            AS STRING
        ),
        COUNT(*),
        COUNT(DISTINCT CONCAT(
            code_module,
            '|',
            code_presentation,
            '|',
            id_student
        )),
        COUNT(*) - COUNT(DISTINCT CONCAT(
            code_module,
            '|',
            code_presentation,
            '|',
            id_student
        ))
    FROM base

    UNION ALL

    -- Exact duplicates
    SELECT
        'student_info_silver',
        NULL,
        'UNIQUE',
        'Exact duplicate records do not exist',
        'FAIL',
        '0 exact duplicate records',
        CAST(e.duplicate_records AS STRING),
        tc.total_records,
        tc.total_records - e.duplicate_records,
        e.duplicate_records
    FROM exact_duplicate_count e
    CROSS JOIN table_count tc

    UNION ALL

    -- No unresolved source sentinel values
    SELECT
        'student_info_silver',
        NULL,
        'SOURCE SENTINEL',
        'No unresolved sentinel (?) values remain',
        'FAIL',
        '0',
        CAST(COUNT_IF(
            gender = '?'
            OR region = '?'
            OR highest_education = '?'
            OR imd_band = '?'
            OR age_band = '?'
            OR disability = '?'
            OR final_result = '?'
        ) AS STRING),
        COUNT(*),
        COUNT(*) - COUNT_IF(
            gender = '?'
            OR region = '?'
            OR highest_education = '?'
            OR imd_band = '?'
            OR age_band = '?'
            OR disability = '?'
            OR final_result = '?'
        ),
        COUNT_IF(
            gender = '?'
            OR region = '?'
            OR highest_education = '?'
            OR imd_band = '?'
            OR age_band = '?'
            OR disability = '?'
            OR final_result = '?'
        )
    FROM base

    UNION ALL

    -- Standardization
    SELECT
        'student_info_silver',
        NULL,
        'STANDARDIZATION',
        'Categorical values are trimmed',
        'FAIL',
        '0 untrimmed records',
        CAST(COUNT_IF(
            code_module <> TRIM(code_module)
            OR code_presentation <> TRIM(code_presentation)
            OR gender <> TRIM(gender)
            OR region <> TRIM(region)
            OR highest_education <> TRIM(highest_education)
            OR imd_band <> TRIM(imd_band)
            OR age_band <> TRIM(age_band)
            OR disability <> TRIM(disability)
            OR final_result <> TRIM(final_result)
        ) AS STRING),
        COUNT(*),
        COUNT(*) - COUNT_IF(
            code_module <> TRIM(code_module)
            OR code_presentation <> TRIM(code_presentation)
            OR gender <> TRIM(gender)
            OR region <> TRIM(region)
            OR highest_education <> TRIM(highest_education)
            OR imd_band <> TRIM(imd_band)
            OR age_band <> TRIM(age_band)
            OR disability <> TRIM(disability)
            OR final_result <> TRIM(final_result)
        ),
        COUNT_IF(
            code_module <> TRIM(code_module)
            OR code_presentation <> TRIM(code_presentation)
            OR gender <> TRIM(gender)
            OR region <> TRIM(region)
            OR highest_education <> TRIM(highest_education)
            OR imd_band <> TRIM(imd_band)
            OR age_band <> TRIM(age_band)
            OR disability <> TRIM(disability)
            OR final_result <> TRIM(final_result)
        )
    FROM base

    UNION ALL

    -- Course referential integrity
    SELECT
        'student_info_silver',
        NULL,
        'REFERENTIAL INTEGRITY',
        'Every student record references an existing course presentation',
        'FAIL',
        '0 unmatched records',
        CAST(COUNT_IF(c.code_module IS NULL) AS STRING),
        COUNT(*),
        COUNT(*) - COUNT_IF(c.code_module IS NULL),
        COUNT_IF(c.code_module IS NULL)
    FROM base s
    LEFT JOIN course_keys c
        ON TRIM(UPPER(s.code_module)) = c.code_module
       AND TRIM(UPPER(s.code_presentation)) = c.code_presentation

    UNION ALL

    -- Bronze lineage
    SELECT
        'student_info_silver',
        'bronze_ingestion_timestamp',
        'LINEAGE',
        'Bronze ingestion timestamp is present',
        'FAIL',
        '0 missing records',
        CAST(COUNT_IF(bronze_ingestion_timestamp IS NULL) AS STRING),
        COUNT(*),
        COUNT(*) - COUNT_IF(bronze_ingestion_timestamp IS NULL),
        COUNT_IF(bronze_ingestion_timestamp IS NULL)
    FROM base

    UNION ALL

    -- Silver processing lineage
    SELECT
        'student_info_silver',
        'silver_processed_timestamp',
        'LINEAGE',
        'Silver processing timestamp is present',
        'FAIL',
        '0 missing records',
        CAST(COUNT_IF(silver_processed_timestamp IS NULL) AS STRING),
        COUNT(*),
        COUNT(*) - COUNT_IF(silver_processed_timestamp IS NULL),
        COUNT_IF(silver_processed_timestamp IS NULL)
    FROM base

    UNION ALL

    SELECT
        'student_info_silver',
        'silver_processed_date',
        'LINEAGE',
        'Silver processing date is present',
        'FAIL',
        '0 missing records',
        CAST(COUNT_IF(silver_processed_date IS NULL) AS STRING),
        COUNT(*),
        COUNT(*) - COUNT_IF(silver_processed_date IS NULL),
        COUNT_IF(silver_processed_date IS NULL)
    FROM base
),

final_results AS (
    SELECT
        r.run_id,
        r.run_timestamp,
        'SILVER' AS layer,
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
            WHEN c.severity = 'WARN' THEN NULL
            WHEN c.failed_records = 0 THEN 100.00
            ELSE ROUND(
                c.passed_records * 100.0
                / NULLIF(c.total_records, 0),
                2
            )
        END AS dq_score,

        CASE
            WHEN c.severity = 'INFO' THEN NULL
            WHEN c.severity = 'WARN' THEN 'WARN'
            WHEN c.failed_records = 0 THEN 'PASS'
            ELSE 'FAIL'
        END AS status

    FROM checks c
    CROSS JOIN (
        SELECT
            uuid() AS run_id,
            current_timestamp() AS run_timestamp
    ) r
)

INSERT INTO oulad.oulad_quality.dq_results
SELECT *
FROM final_results;