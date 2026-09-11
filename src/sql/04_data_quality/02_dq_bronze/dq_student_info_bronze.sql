-- STUDENT INFO BRONZE DATA QUALITY VALIDATION

WITH base AS (
    SELECT *
    FROM oulad.oulad_bronze.student_info_bronze
),

table_count AS (
    SELECT COUNT(*) AS total_records
    FROM base
),

course_keys AS (
    SELECT DISTINCT
        TRIM(UPPER(code_module)) AS code_module,
        TRIM(UPPER(code_presentation)) AS code_presentation
    FROM oulad.oulad_bronze.courses_bronze
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

checks AS (

    -- Volume check
    SELECT
        'student_info_bronze' AS table_name,
        NULL AS column_name,
        'VOLUME' AS dq_dimension,
        'Table contains records' AS rule_name,
        'INFO' AS severity,
        'At least 1 record' AS expected_value,
        CAST(COUNT(*) AS STRING) AS actual_value,
        COUNT(*) AS total_records,
        CASE WHEN COUNT(*) > 0 THEN COUNT(*) ELSE 0 END AS passed_records,
        CASE WHEN COUNT(*) = 0 THEN 1 ELSE 0 END AS failed_records
    FROM base

    UNION ALL

    -- Required field checks
    SELECT
        'student_info_bronze',
        'code_module',
        'NULL',
        'Mandatory code_module is populated',
        'FAIL',
        '0% missing',
        CAST(COUNT_IF(code_module IS NULL) AS STRING),
        COUNT(*),
        COUNT(*) - COUNT_IF(code_module IS NULL),
        COUNT_IF(code_module IS NULL)
    FROM base

    UNION ALL

    SELECT
        'student_info_bronze',
        'code_presentation',
        'NULL',
        'Mandatory code_presentation is populated',
        'FAIL',
        '0% missing',
        CAST(COUNT_IF(code_presentation IS NULL) AS STRING),
        COUNT(*),
        COUNT(*) - COUNT_IF(code_presentation IS NULL),
        COUNT_IF(code_presentation IS NULL)
    FROM base

    UNION ALL

    SELECT
        'student_info_bronze',
        'id_student',
        'NULL',
        'Mandatory id_student is populated',
        'FAIL',
        '0% missing',
        CAST(COUNT_IF(id_student IS NULL) AS STRING),
        COUNT(*),
        COUNT(*) - COUNT_IF(id_student IS NULL),
        COUNT_IF(id_student IS NULL)
    FROM base

    UNION ALL

    SELECT
        'student_info_bronze',
        'gender',
        'NULL',
        'Gender is populated',
        'FAIL',
        '0% missing',
        CAST(COUNT_IF(gender IS NULL) AS STRING),
        COUNT(*),
        COUNT(*) - COUNT_IF(gender IS NULL),
        COUNT_IF(gender IS NULL)
    FROM base

    UNION ALL

    SELECT
        'student_info_bronze',
        'region',
        'NULL',
        'Region is populated',
        'FAIL',
        '0% missing',
        CAST(COUNT_IF(region IS NULL) AS STRING),
        COUNT(*),
        COUNT(*) - COUNT_IF(region IS NULL),
        COUNT_IF(region IS NULL)
    FROM base

    UNION ALL

    SELECT
        'student_info_bronze',
        'highest_education',
        'NULL',
        'Highest education is populated',
        'FAIL',
        '0% missing',
        CAST(COUNT_IF(highest_education IS NULL) AS STRING),
        COUNT(*),
        COUNT(*) - COUNT_IF(highest_education IS NULL),
        COUNT_IF(highest_education IS NULL)
    FROM base

    UNION ALL

    SELECT
        'student_info_bronze',
        'imd_band',
        'NULL',
        'imd_band is populated',
        'WARN',
        'Missing values may be unavailable',
        CAST(COUNT_IF(imd_band IS NULL) AS STRING),
        COUNT(*),
        COUNT(*) - COUNT_IF(imd_band IS NULL),
        COUNT_IF(imd_band IS NULL)
    FROM base

    UNION ALL

    SELECT
        'student_info_bronze',
        'age_band',
        'NULL',
        'Age band is populated',
        'FAIL',
        '0% missing',
        CAST(COUNT_IF(age_band IS NULL) AS STRING),
        COUNT(*),
        COUNT(*) - COUNT_IF(age_band IS NULL),
        COUNT_IF(age_band IS NULL)
    FROM base

    UNION ALL

    SELECT
        'student_info_bronze',
        'num_of_prev_attempts',
        'NULL',
        'Previous attempts is populated',
        'FAIL',
        '0% missing',
        CAST(COUNT_IF(num_of_prev_attempts IS NULL) AS STRING),
        COUNT(*),
        COUNT(*) - COUNT_IF(num_of_prev_attempts IS NULL),
        COUNT_IF(num_of_prev_attempts IS NULL)
    FROM base

    UNION ALL

    SELECT
        'student_info_bronze',
        'studied_credits',
        'NULL',
        'Studied credits is populated',
        'FAIL',
        '0% missing',
        CAST(COUNT_IF(studied_credits IS NULL) AS STRING),
        COUNT(*),
        COUNT(*) - COUNT_IF(studied_credits IS NULL),
        COUNT_IF(studied_credits IS NULL)
    FROM base

    UNION ALL

    SELECT
        'student_info_bronze',
        'disability',
        'NULL',
        'Disability is populated',
        'FAIL',
        '0% missing',
        CAST(COUNT_IF(disability IS NULL) AS STRING),
        COUNT(*),
        COUNT(*) - COUNT_IF(disability IS NULL),
        COUNT_IF(disability IS NULL)
    FROM base

    UNION ALL

    SELECT
        'student_info_bronze',
        'final_result',
        'NULL',
        'Final result is populated',
        'FAIL',
        '0% missing',
        CAST(COUNT_IF(final_result IS NULL) AS STRING),
        COUNT(*),
        COUNT(*) - COUNT_IF(final_result IS NULL),
        COUNT_IF(final_result IS NULL)
    FROM base

    UNION ALL

    -- Business key uniqueness
    SELECT
        'student_info_bronze',
        'code_module, code_presentation, id_student',
        'UNIQUE',
        'Student-info business key is unique',
        'FAIL',
        '0 duplicate business keys',
        CAST(
            COUNT(*) - COUNT(DISTINCT CONCAT(
                CAST(id_student AS STRING), '|',
                TRIM(UPPER(code_module)), '|',
                TRIM(UPPER(code_presentation))
            ))
            AS STRING
        ),
        COUNT(*),
        COUNT(*) - (
            COUNT(*) - COUNT(DISTINCT CONCAT(
                CAST(id_student AS STRING), '|',
                TRIM(UPPER(code_module)), '|',
                TRIM(UPPER(code_presentation))
            ))
        ),
        COUNT(*) - COUNT(DISTINCT CONCAT(
            CAST(id_student AS STRING), '|',
            TRIM(UPPER(code_module)), '|',
            TRIM(UPPER(code_presentation))
        ))
    FROM base

    UNION ALL

    -- Exact duplicate check
    SELECT
        'student_info_bronze',
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

    -- Range checks
    SELECT
        'student_info_bronze',
        'num_of_prev_attempts',
        'RANGE',
        'Previous attempts are not negative',
        'FAIL',
        'num_of_prev_attempts >= 0',
        CAST(COUNT_IF(num_of_prev_attempts < 0) AS STRING),
        COUNT(*),
        COUNT(*) - COUNT_IF(num_of_prev_attempts < 0),
        COUNT_IF(num_of_prev_attempts < 0)
    FROM base

    UNION ALL

    SELECT
        'student_info_bronze',
        'studied_credits',
        'RANGE',
        'Studied credits are positive',
        'FAIL',
        'studied_credits > 0',
        CAST(COUNT_IF(studied_credits <= 0) AS STRING),
        COUNT(*),
        COUNT(*) - COUNT_IF(studied_credits <= 0),
        COUNT_IF(studied_credits <= 0)
    FROM base

    UNION ALL

    -- Source sentinel check
    SELECT
        'student_info_bronze',
        'imd_band',
        'SOURCE SENTINEL',
        'Source sentinel (?) in imd_band',
        'WARN',
        'Source may use ? for unavailable imd_band',
        CAST(COUNT_IF(TRIM(imd_band) = '?') AS STRING),
        COUNT(*),
        COUNT(*) - COUNT_IF(TRIM(imd_band) = '?'),
        COUNT_IF(TRIM(imd_band) = '?')
    FROM base

    UNION ALL

    -- Referential integrity check
    SELECT
        'student_info_bronze',
        'code_module, code_presentation',
        'REFERENTIAL INTEGRITY',
        'Student course presentation exists in courses',
        'FAIL',
        '0 unmatched course presentations',
        CAST(
            COUNT_IF(
                c.code_module IS NULL
                OR c.code_presentation IS NULL
            ) AS STRING
        ),
        COUNT(*),
        COUNT(*) - COUNT_IF(
            c.code_module IS NULL
            OR c.code_presentation IS NULL
        ),
        COUNT_IF(
            c.code_module IS NULL
            OR c.code_presentation IS NULL
        )
    FROM base b
    LEFT JOIN course_keys c
        ON TRIM(UPPER(b.code_module)) = c.code_module
        AND TRIM(UPPER(b.code_presentation)) = c.code_presentation
),

final_results AS (
    SELECT
        r.run_id,
        r.run_timestamp,
        'BRONZE' AS layer,
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
            c.failed_records * 100.0 / NULLIF(c.total_records, 0),
            2
        ) AS failure_pct,
        CASE
            WHEN c.severity = 'INFO' THEN NULL
            WHEN c.failed_records = 0 THEN 100.00
            ELSE ROUND(
                c.passed_records * 100.0 / NULLIF(c.total_records, 0),
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
SELECT
    run_id,
    run_timestamp,
    layer,
    table_name,
    column_name,
    dq_dimension,
    rule_name,
    severity,
    expected_value,
    actual_value,
    total_records,
    passed_records,
    failed_records,
    failure_pct,
    dq_score,
    status
FROM final_results;