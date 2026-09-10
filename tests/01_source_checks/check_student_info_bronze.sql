-- STUDENT INFO BRONZE DATA QUALITY VALIDATION

WITH base AS (
    SELECT *
    FROM oulad.oulad_bronze.student_info_bronze
),

course_keys AS (
    SELECT DISTINCT
        TRIM(UPPER(code_module)) AS code_module,
        TRIM(UPPER(code_presentation)) AS code_presentation
    FROM oulad.oulad_bronze.courses_bronze
),

dq_results AS (

    -- Volume check
    SELECT
        'student_info_bronze' AS table_name,
        'Row count' AS check_name,
        'VOLUME' AS dq_category,
        COUNT(*) AS total_rows,
        CASE
            WHEN COUNT(*) = 0 THEN 1
            ELSE 0
        END AS failed_rows,
        CASE
            WHEN COUNT(*) = 0 THEN 100.00
            ELSE 0.00
        END AS failure_pct,
        'Table should contain records' AS expected_value
    FROM base

    UNION ALL

    -- NULL checks
    SELECT
        'student_info_bronze',
        'Missing code_module',
        'NULL',
        COUNT(*),
        COUNT_IF(code_module IS NULL),
        ROUND(COUNT_IF(code_module IS NULL) * 100.0 / COUNT(*), 2),
        '0% missing; mandatory key'
    FROM base

    UNION ALL

    SELECT
        'student_info_bronze',
        'Missing code_presentation',
        'NULL',
        COUNT(*),
        COUNT_IF(code_presentation IS NULL),
        ROUND(COUNT_IF(code_presentation IS NULL) * 100.0 / COUNT(*), 2),
        '0% missing; mandatory key'
    FROM base

    UNION ALL

    SELECT
        'student_info_bronze',
        'Missing id_student',
        'NULL',
        COUNT(*),
        COUNT_IF(id_student IS NULL),
        ROUND(COUNT_IF(id_student IS NULL) * 100.0 / COUNT(*), 2),
        '0% missing; mandatory key'
    FROM base

    UNION ALL

    SELECT
        'student_info_bronze',
        'Missing gender',
        'NULL',
        COUNT(*),
        COUNT_IF(gender IS NULL),
        ROUND(COUNT_IF(gender IS NULL) * 100.0 / COUNT(*), 2),
        'Gender should normally be populated'
    FROM base

    UNION ALL

    SELECT
        'student_info_bronze',
        'Missing region',
        'NULL',
        COUNT(*),
        COUNT_IF(region IS NULL),
        ROUND(COUNT_IF(region IS NULL) * 100.0 / COUNT(*), 2),
        'Region should normally be populated'
    FROM base

    UNION ALL

    SELECT
        'student_info_bronze',
        'Missing highest_education',
        'NULL',
        COUNT(*),
        COUNT_IF(highest_education IS NULL),
        ROUND(COUNT_IF(highest_education IS NULL) * 100.0 / COUNT(*), 2),
        'Highest education should normally be populated'
    FROM base

    UNION ALL

    SELECT
        'student_info_bronze',
        'Missing imd_band',
        'NULL',
        COUNT(*),
        COUNT_IF(imd_band IS NULL),
        ROUND(COUNT_IF(imd_band IS NULL) * 100.0 / COUNT(*), 2),
        'imd_band may be unavailable'
    FROM base

    UNION ALL

    SELECT
        'student_info_bronze',
        'Missing age_band',
        'NULL',
        COUNT(*),
        COUNT_IF(age_band IS NULL),
        ROUND(COUNT_IF(age_band IS NULL) * 100.0 / COUNT(*), 2),
        'Age band should normally be populated'
    FROM base

    UNION ALL

    SELECT
        'student_info_bronze',
        'Missing num_of_prev_attempts',
        'NULL',
        COUNT(*),
        COUNT_IF(num_of_prev_attempts IS NULL),
        ROUND(COUNT_IF(num_of_prev_attempts IS NULL) * 100.0 / COUNT(*), 2),
        'Previous attempts should normally be populated'
    FROM base

    UNION ALL

    SELECT
        'student_info_bronze',
        'Missing studied_credits',
        'NULL',
        COUNT(*),
        COUNT_IF(studied_credits IS NULL),
        ROUND(COUNT_IF(studied_credits IS NULL) * 100.0 / COUNT(*), 2),
        'Studied credits should normally be populated'
    FROM base

    UNION ALL

    SELECT
        'student_info_bronze',
        'Missing disability',
        'NULL',
        COUNT(*),
        COUNT_IF(disability IS NULL),
        ROUND(COUNT_IF(disability IS NULL) * 100.0 / COUNT(*), 2),
        'Disability should normally be populated'
    FROM base

    UNION ALL

    SELECT
        'student_info_bronze',
        'Missing final_result',
        'NULL',
        COUNT(*),
        COUNT_IF(final_result IS NULL),
        ROUND(COUNT_IF(final_result IS NULL) * 100.0 / COUNT(*), 2),
        'Final result should normally be populated'
    FROM base

    UNION ALL

    -- Uniqueness checks
    SELECT
        'student_info_bronze',
        'Duplicate student-info business key',
        'UNIQUE',
        COUNT(*),
        COUNT(*) - COUNT(DISTINCT CONCAT(
            CAST(id_student AS STRING), '|',
            TRIM(UPPER(code_module)), '|',
            TRIM(UPPER(code_presentation))
        )),
        ROUND(
            (COUNT(*) - COUNT(DISTINCT CONCAT(
                CAST(id_student AS STRING), '|',
                TRIM(UPPER(code_module)), '|',
                TRIM(UPPER(code_presentation))
            ))) * 100.0 / COUNT(*),
            2
        ),
        '0% duplicate id_student + code_module + code_presentation'
    FROM base

    UNION ALL

    SELECT
        'student_info_bronze',
        'Exact duplicate records',
        'UNIQUE',
        COUNT(*),
        COUNT(*) - COUNT(DISTINCT
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
        ),
        ROUND(
            (COUNT(*) - COUNT(DISTINCT
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
            )) * 100.0 / COUNT(*),
            2
        ),
        '0% exact duplicate records'
    FROM base

    UNION ALL

    -- Type and format checks
    SELECT
        'student_info_bronze',
        'Invalid id_student format',
        'TYPE / FORMAT',
        COUNT(*),
        COUNT_IF(
            id_student IS NOT NULL
            AND TRY_CAST(id_student AS BIGINT) IS NULL
        ),
        ROUND(
            COUNT_IF(
                id_student IS NOT NULL
                AND TRY_CAST(id_student AS BIGINT) IS NULL
            ) * 100.0 / COUNT(*),
            2
        ),
        'id_student must be numeric'
    FROM base

    UNION ALL

    SELECT
        'student_info_bronze',
        'Invalid num_of_prev_attempts format',
        'TYPE / FORMAT',
        COUNT(*),
        COUNT_IF(
            num_of_prev_attempts IS NOT NULL
            AND TRY_CAST(num_of_prev_attempts AS INT) IS NULL
        ),
        ROUND(
            COUNT_IF(
                num_of_prev_attempts IS NOT NULL
                AND TRY_CAST(num_of_prev_attempts AS INT) IS NULL
            ) * 100.0 / COUNT(*),
            2
        ),
        'num_of_prev_attempts must be numeric'
    FROM base

    UNION ALL

    SELECT
        'student_info_bronze',
        'Invalid studied_credits format',
        'TYPE / FORMAT',
        COUNT(*),
        COUNT_IF(
            studied_credits IS NOT NULL
            AND TRY_CAST(studied_credits AS INT) IS NULL
        ),
        ROUND(
            COUNT_IF(
                studied_credits IS NOT NULL
                AND TRY_CAST(studied_credits AS INT) IS NULL
            ) * 100.0 / COUNT(*),
            2
        ),
        'studied_credits must be numeric'
    FROM base

    UNION ALL

    -- Range checks
    SELECT
        'student_info_bronze',
        'Previous attempts below zero',
        'RANGE',
        COUNT(*),
        COUNT_IF(
            TRY_CAST(num_of_prev_attempts AS INT) < 0
        ),
        ROUND(
            COUNT_IF(
                TRY_CAST(num_of_prev_attempts AS INT) < 0
            ) * 100.0 / COUNT(*),
            2
        ),
        'num_of_prev_attempts >= 0'
    FROM base

    UNION ALL

    SELECT
        'student_info_bronze',
        'Studied credits below zero',
        'RANGE',
        COUNT(*),
        COUNT_IF(
            TRY_CAST(studied_credits AS INT) < 0
        ),
        ROUND(
            COUNT_IF(
                TRY_CAST(studied_credits AS INT) < 0
            ) * 100.0 / COUNT(*),
            2
        ),
        'studied_credits >= 0'
    FROM base

    UNION ALL

    -- Source sentinel check
    SELECT
        'student_info_bronze',
        'Source sentinel (?) in imd_band',
        'SENTINEL',
        COUNT(*),
        COUNT_IF(TRIM(imd_band) = '?'),
        ROUND(
            COUNT_IF(TRIM(imd_band) = '?') * 100.0 / COUNT(*),
            2
        ),
        'Source may use ? for unavailable imd_band'
    FROM base

    UNION ALL

    -- Referential integrity check
    SELECT
        'student_info_bronze',
        'Student without matching course presentation',
        'FOREIGN KEY',
        COUNT(*),
        COUNT_IF(
            c.code_module IS NULL
            OR c.code_presentation IS NULL
        ),
        ROUND(
            COUNT_IF(
                c.code_module IS NULL
                OR c.code_presentation IS NULL
            ) * 100.0 / COUNT(*),
            2
        ),
        'Every code_module + code_presentation should exist in courses_bronze'
    FROM base b
    LEFT JOIN course_keys c
        ON TRIM(UPPER(b.code_module)) = c.code_module
        AND TRIM(UPPER(b.code_presentation)) = c.code_presentation
)

SELECT
    table_name,
    check_name,
    dq_category,
    total_rows,
    failed_rows,
    failure_pct,
    expected_value,
    CASE
        WHEN dq_category = 'VOLUME'
             AND failed_rows = 0 THEN 'PASS'

        WHEN dq_category = 'NULL'
             AND failed_rows = 0 THEN 'PASS'

        WHEN dq_category = 'NULL'
             AND failed_rows > 0 THEN 'WARN'

        WHEN dq_category = 'UNIQUE'
             AND failure_pct = 0 THEN 'PASS'

        WHEN dq_category = 'UNIQUE'
             AND failure_pct <= 1 THEN 'WARN'

        WHEN dq_category = 'UNIQUE'
             AND failure_pct > 1 THEN 'FAIL'

        WHEN dq_category = 'TYPE / FORMAT'
             AND failed_rows = 0 THEN 'PASS'

        WHEN dq_category = 'TYPE / FORMAT'
             AND failed_rows > 0 THEN 'FAIL'

        WHEN dq_category = 'RANGE'
             AND failed_rows = 0 THEN 'PASS'

        WHEN dq_category = 'RANGE'
             AND failure_pct <= 1 THEN 'WARN'

        WHEN dq_category = 'RANGE'
             AND failure_pct > 1 THEN 'FAIL'

        WHEN dq_category = 'SENTINEL'
             AND failed_rows = 0 THEN 'PASS'

        WHEN dq_category = 'SENTINEL'
             AND failed_rows > 0 THEN 'WARN'

        WHEN dq_category = 'FOREIGN KEY'
             AND failed_rows = 0 THEN 'PASS'

        WHEN dq_category = 'FOREIGN KEY'
             AND failure_pct <= 0.1 THEN 'WARN'

        WHEN dq_category = 'FOREIGN KEY'
             AND failure_pct > 0.1 THEN 'FAIL'

        ELSE 'REVIEW'
    END AS status

FROM dq_results
ORDER BY
    CASE dq_category
        WHEN 'VOLUME' THEN 1
        WHEN 'NULL' THEN 2
        WHEN 'UNIQUE' THEN 3
        WHEN 'TYPE / FORMAT' THEN 4
        WHEN 'RANGE' THEN 5
        WHEN 'SENTINEL' THEN 6
        WHEN 'FOREIGN KEY' THEN 7
        ELSE 8
    END,
    check_name;