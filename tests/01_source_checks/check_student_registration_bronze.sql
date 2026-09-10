-- STUDENT REGISTRATION BRONZE DATA QUALITY VALIDATION

WITH base AS (
    SELECT *
    FROM oulad.oulad_bronze.student_registration_bronze
),

course_keys AS (
    SELECT DISTINCT
        TRIM(UPPER(code_module)) AS code_module,
        TRIM(UPPER(code_presentation)) AS code_presentation
    FROM oulad.oulad_bronze.courses_bronze
),

student_keys AS (
    SELECT DISTINCT
        TRY_CAST(id_student AS BIGINT) AS id_student
    FROM oulad.oulad_bronze.student_info_bronze
    WHERE TRY_CAST(id_student AS BIGINT) IS NOT NULL
),

dq_results AS (

    -- Volume check
    SELECT
        'student_registration_bronze' AS table_name,
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
        'student_registration_bronze',
        'Missing code_module',
        'NULL',
        COUNT(*),
        COUNT_IF(code_module IS NULL),
        ROUND(COUNT_IF(code_module IS NULL) * 100.0 / COUNT(*), 2),
        '0% missing; mandatory key'
    FROM base

    UNION ALL

    SELECT
        'student_registration_bronze',
        'Missing code_presentation',
        'NULL',
        COUNT(*),
        COUNT_IF(code_presentation IS NULL),
        ROUND(COUNT_IF(code_presentation IS NULL) * 100.0 / COUNT(*), 2),
        '0% missing; mandatory key'
    FROM base

    UNION ALL

    SELECT
        'student_registration_bronze',
        'Missing id_student',
        'NULL',
        COUNT(*),
        COUNT_IF(id_student IS NULL),
        ROUND(COUNT_IF(id_student IS NULL) * 100.0 / COUNT(*), 2),
        '0% missing; mandatory key'
    FROM base

    UNION ALL

    SELECT
        'student_registration_bronze',
        'Missing date_registration',
        'NULL',
        COUNT(*),
        COUNT_IF(date_registration IS NULL),
        ROUND(COUNT_IF(date_registration IS NULL) * 100.0 / COUNT(*), 2),
        'Registration date should normally be populated'
    FROM base

    UNION ALL

    SELECT
        'student_registration_bronze',
        'Missing date_unregistration',
        'NULL',
        COUNT(*),
        COUNT_IF(date_unregistration IS NULL),
        ROUND(COUNT_IF(date_unregistration IS NULL) * 100.0 / COUNT(*), 2),
        'NULL is legitimate when student did not withdraw'
    FROM base

    UNION ALL

    -- Uniqueness checks
    SELECT
        'student_registration_bronze',
        'Duplicate registration business key',
        'UNIQUE',
        COUNT(*),
        COUNT(*) - COUNT(DISTINCT CONCAT(
            CAST(TRY_CAST(id_student AS BIGINT) AS STRING), '|',
            TRIM(UPPER(code_module)), '|',
            TRIM(UPPER(code_presentation))
        )),
        ROUND(
            (COUNT(*) - COUNT(DISTINCT CONCAT(
                CAST(TRY_CAST(id_student AS BIGINT) AS STRING), '|',
                TRIM(UPPER(code_module)), '|',
                TRIM(UPPER(code_presentation))
            ))) * 100.0 / COUNT(*),
            2
        ),
        '0% duplicate id_student + code_module + code_presentation'
    FROM base

    UNION ALL

    SELECT
        'student_registration_bronze',
        'Exact duplicate records',
        'UNIQUE',
        COUNT(*),
        COUNT(*) - COUNT(DISTINCT
            code_module,
            code_presentation,
            id_student,
            date_registration,
            date_unregistration
        ),
        ROUND(
            (COUNT(*) - COUNT(DISTINCT
                code_module,
                code_presentation,
                id_student,
                date_registration,
                date_unregistration
            )) * 100.0 / COUNT(*),
            2
        ),
        '0% exact duplicate records'
    FROM base

    UNION ALL

    -- Type and format checks
    SELECT
        'student_registration_bronze',
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
        'student_registration_bronze',
        'Invalid date_registration format',
        'TYPE / FORMAT',
        COUNT(*),
        COUNT_IF(
            date_registration IS NOT NULL
            AND TRIM(CAST(date_registration AS STRING)) <> '?'
            AND TRY_CAST(date_registration AS INT) IS NULL
        ),
        ROUND(
            COUNT_IF(
                date_registration IS NOT NULL
                AND TRIM(CAST(date_registration AS STRING)) <> '?'
                AND TRY_CAST(date_registration AS INT) IS NULL
            ) * 100.0 / COUNT(*),
            2
        ),
        'date_registration must be numeric or ?'
    FROM base

    UNION ALL

    SELECT
        'student_registration_bronze',
        'Invalid date_unregistration format',
        'TYPE / FORMAT',
        COUNT(*),
        COUNT_IF(
            date_unregistration IS NOT NULL
            AND TRIM(CAST(date_unregistration AS STRING)) <> '?'
            AND TRY_CAST(date_unregistration AS INT) IS NULL
        ),
        ROUND(
            COUNT_IF(
                date_unregistration IS NOT NULL
                AND TRIM(CAST(date_unregistration AS STRING)) <> '?'
                AND TRY_CAST(date_unregistration AS INT) IS NULL
            ) * 100.0 / COUNT(*),
            2
        ),
        'date_unregistration must be numeric or ?'
    FROM base

    UNION ALL

    -- Source sentinel checks
    SELECT
        'student_registration_bronze',
        'Source sentinel (?) in date_registration',
        'SENTINEL',
        COUNT(*),
        COUNT_IF(TRIM(CAST(date_registration AS STRING)) = '?'),
        ROUND(
            COUNT_IF(TRIM(CAST(date_registration AS STRING)) = '?')
            * 100.0 / COUNT(*),
            2
        ),
        'Source may use ? for unavailable registration date'
    FROM base

    UNION ALL

    SELECT
        'student_registration_bronze',
        'Source sentinel (?) in date_unregistration',
        'SENTINEL',
        COUNT(*),
        COUNT_IF(TRIM(CAST(date_unregistration AS STRING)) = '?'),
        ROUND(
            COUNT_IF(TRIM(CAST(date_unregistration AS STRING)) = '?')
            * 100.0 / COUNT(*),
            2
        ),
        'Source may use ? for unavailable unregistration date'
    FROM base

    UNION ALL

    -- Referential integrity checks
    SELECT
        'student_registration_bronze',
        'Registration without matching course presentation',
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

    UNION ALL

    SELECT
        'student_registration_bronze',
        'Registration without matching student',
        'FOREIGN KEY',
        COUNT(*),
        COUNT_IF(s.id_student IS NULL),
        ROUND(
            COUNT_IF(s.id_student IS NULL) * 100.0 / COUNT(*),
            2
        ),
        'Every id_student should exist in student_info_bronze'
    FROM base b
    LEFT JOIN student_keys s
        ON TRY_CAST(b.id_student AS BIGINT) = s.id_student
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
             AND check_name = 'Missing date_unregistration' THEN 'PASS'

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
        WHEN 'SENTINEL' THEN 5
        WHEN 'FOREIGN KEY' THEN 6
        ELSE 7
    END,
    check_name;