-- STUDENT VLE BRONZE DATA QUALITY VALIDATION

WITH base AS (
    SELECT *
    FROM oulad.oulad_bronze.student_vle_bronze
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

vle_keys AS (
    SELECT DISTINCT
        TRY_CAST(id_site AS BIGINT) AS id_site,
        TRIM(UPPER(code_module)) AS code_module,
        TRIM(UPPER(code_presentation)) AS code_presentation
    FROM oulad.oulad_bronze.vle_bronze
    WHERE TRY_CAST(id_site AS BIGINT) IS NOT NULL
),

dq_results AS (

    -- Volume check
    SELECT
        'student_vle_bronze' AS table_name,
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
        'student_vle_bronze',
        'Missing code_module',
        'NULL',
        COUNT(*),
        COUNT_IF(code_module IS NULL),
        ROUND(COUNT_IF(code_module IS NULL) * 100.0 / COUNT(*), 2),
        '0% missing; mandatory key'
    FROM base

    UNION ALL

    SELECT
        'student_vle_bronze',
        'Missing code_presentation',
        'NULL',
        COUNT(*),
        COUNT_IF(code_presentation IS NULL),
        ROUND(COUNT_IF(code_presentation IS NULL) * 100.0 / COUNT(*), 2),
        '0% missing; mandatory key'
    FROM base

    UNION ALL

    SELECT
        'student_vle_bronze',
        'Missing id_student',
        'NULL',
        COUNT(*),
        COUNT_IF(id_student IS NULL),
        ROUND(COUNT_IF(id_student IS NULL) * 100.0 / COUNT(*), 2),
        '0% missing; mandatory key'
    FROM base

    UNION ALL

    SELECT
        'student_vle_bronze',
        'Missing id_site',
        'NULL',
        COUNT(*),
        COUNT_IF(id_site IS NULL),
        ROUND(COUNT_IF(id_site IS NULL) * 100.0 / COUNT(*), 2),
        '0% missing; mandatory key'
    FROM base

    UNION ALL

    SELECT
        'student_vle_bronze',
        'Missing date',
        'NULL',
        COUNT(*),
        COUNT_IF(date IS NULL),
        ROUND(COUNT_IF(date IS NULL) * 100.0 / COUNT(*), 2),
        'Date should normally be populated; NULL may be retained'
    FROM base

    UNION ALL

    SELECT
        'student_vle_bronze',
        'Missing sum_click',
        'NULL',
        COUNT(*),
        COUNT_IF(sum_click IS NULL),
        ROUND(COUNT_IF(sum_click IS NULL) * 100.0 / COUNT(*), 2),
        'sum_click should normally be populated'
    FROM base

    UNION ALL

    -- Uniqueness checks
    SELECT
        'student_vle_bronze',
        'Duplicate student-VLE business key',
        'UNIQUE',
        COUNT(*),
        COUNT(*) - COUNT(DISTINCT CONCAT(
            CAST(TRY_CAST(id_student AS BIGINT) AS STRING), '|',
            TRIM(UPPER(code_module)), '|',
            TRIM(UPPER(code_presentation)), '|',
            CAST(TRY_CAST(id_site AS BIGINT) AS STRING), '|',
            CAST(date AS STRING)
        )),
        ROUND(
            (COUNT(*) - COUNT(DISTINCT CONCAT(
                CAST(TRY_CAST(id_student AS BIGINT) AS STRING), '|',
                TRIM(UPPER(code_module)), '|',
                TRIM(UPPER(code_presentation)), '|',
                CAST(TRY_CAST(id_site AS BIGINT) AS STRING), '|',
                CAST(date AS STRING)
            ))) * 100.0 / COUNT(*),
            2
        ),
        '0% duplicate student + module + presentation + site + date'
    FROM base

    UNION ALL

    -- Uniqueness checks
    SELECT
        'student_vle_bronze',
        'Duplicate student-VLE 3-keys',
        'UNIQUE',
        COUNT(*),
        COUNT(*) - COUNT(DISTINCT CONCAT(
            CAST(TRY_CAST(id_student AS BIGINT) AS STRING), '|',

            CAST(TRY_CAST(id_site AS BIGINT) AS STRING), '|',
            CAST(date AS STRING)
        )),
        ROUND(
            (COUNT(*) - COUNT(DISTINCT CONCAT(
                CAST(TRY_CAST(id_student AS BIGINT) AS STRING), '|',

                CAST(TRY_CAST(id_site AS BIGINT) AS STRING), '|',
                CAST(date AS STRING)
            ))) * 100.0 / COUNT(*),
            2
        ),
        '0% duplicate student + site + date'
    FROM base





    UNION ALL

    SELECT
        'student_vle_bronze',
        'Exact duplicate records',
        'UNIQUE',
        COUNT(*),
        COUNT(*) - COUNT(DISTINCT
            code_module,
            code_presentation,
            id_student,
            id_site,
            date,
            sum_click
        ),
        ROUND(
            (COUNT(*) - COUNT(DISTINCT
                code_module,
                code_presentation,
                id_student,
                id_site,
                date,
                sum_click
            )) * 100.0 / COUNT(*),
            2
        ),
        '0% exact duplicate records'
    FROM base

    UNION ALL

    -- Type and format checks
    SELECT
        'student_vle_bronze',
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
        'student_vle_bronze',
        'Invalid id_site format',
        'TYPE / FORMAT',
        COUNT(*),
        COUNT_IF(
            id_site IS NOT NULL
            AND TRY_CAST(id_site AS BIGINT) IS NULL
        ),
        ROUND(
            COUNT_IF(
                id_site IS NOT NULL
                AND TRY_CAST(id_site AS BIGINT) IS NULL
            ) * 100.0 / COUNT(*),
            2
        ),
        'id_site must be numeric'
    FROM base

    UNION ALL

    SELECT
        'student_vle_bronze',
        'Invalid date format',
        'TYPE / FORMAT',
        COUNT(*),
        COUNT_IF(
            date IS NOT NULL
            AND TRIM(CAST(date AS STRING)) <> '?'
            AND TRY_CAST(date AS INT) IS NULL
        ),
        ROUND(
            COUNT_IF(
                date IS NOT NULL
                AND TRIM(CAST(date AS STRING)) <> '?'
                AND TRY_CAST(date AS INT) IS NULL
            ) * 100.0 / COUNT(*),
            2
        ),
        'date must be numeric or ?'
    FROM base

    UNION ALL

    SELECT
        'student_vle_bronze',
        'Invalid sum_click format',
        'TYPE / FORMAT',
        COUNT(*),
        COUNT_IF(
            sum_click IS NOT NULL
            AND TRY_CAST(sum_click AS BIGINT) IS NULL
        ),
        ROUND(
            COUNT_IF(
                sum_click IS NOT NULL
                AND TRY_CAST(sum_click AS BIGINT) IS NULL
            ) * 100.0 / COUNT(*),
            2
        ),
        'sum_click must be numeric'
    FROM base

    UNION ALL

    -- Range check
    SELECT
        'student_vle_bronze',
        'Negative sum_click',
        'RANGE',
        COUNT(*),
        COUNT_IF(
            TRY_CAST(sum_click AS BIGINT) < 0
        ),
        ROUND(
            COUNT_IF(
                TRY_CAST(sum_click AS BIGINT) < 0
            ) * 100.0 / COUNT(*),
            2
        ),
        'sum_click >= 0'
    FROM base

    UNION ALL

    -- Source sentinel check
    SELECT
        'student_vle_bronze',
        'Source sentinel (?) in date',
        'SENTINEL',
        COUNT(*),
        COUNT_IF(TRIM(CAST(date AS STRING)) = '?'),
        ROUND(
            COUNT_IF(TRIM(CAST(date AS STRING)) = '?')
            * 100.0 / COUNT(*),
            2
        ),
        'Source may use ? for unavailable date'
    FROM base

    UNION ALL

    -- Referential integrity checks
    SELECT
        'student_vle_bronze',
        'Activity without matching course presentation',
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
        'student_vle_bronze',
        'Activity without matching student',
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

    UNION ALL

    SELECT
        'student_vle_bronze',
        'Activity without matching VLE site',
        'FOREIGN KEY',
        COUNT(*),
        COUNT_IF(
            v.id_site IS NULL
        ),
        ROUND(
            COUNT_IF(
                v.id_site IS NULL
            ) * 100.0 / COUNT(*),
            2
        ),
        'Every id_site + module + presentation should exist in vle_bronze'
    FROM base b
    LEFT JOIN vle_keys v
        ON TRY_CAST(b.id_site AS BIGINT) = v.id_site
        AND TRIM(UPPER(b.code_module)) = v.code_module
        AND TRIM(UPPER(b.code_presentation)) = v.code_presentation
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