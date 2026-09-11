-- STUDENT REGISTRATION BRONZE DATA QUALITY VALIDATION

WITH base AS (
    SELECT *
    FROM oulad.oulad_bronze.student_registration_bronze
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

student_keys AS (
    SELECT DISTINCT
        id_student
    FROM oulad.oulad_bronze.student_info_bronze
    WHERE id_student IS NOT NULL
),

exact_duplicate_count AS (
    SELECT
        COALESCE(SUM(duplicate_count - 1), 0) AS duplicate_records
    FROM (
        SELECT
            code_module,
            code_presentation,
            id_student,
            date_registration,
            date_unregistration,
            COUNT(*) AS duplicate_count
        FROM base
        GROUP BY
            code_module,
            code_presentation,
            id_student,
            date_registration,
            date_unregistration
        HAVING COUNT(*) > 1
    ) d
),

checks AS (

    -- Volume check
    SELECT
        'student_registration_bronze' AS table_name,
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
        'student_registration_bronze',
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
        'student_registration_bronze',
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
        'student_registration_bronze',
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
        'student_registration_bronze',
        'date_registration',
        'NULL',
        'Registration date is populated',
        'FAIL',
        '0% missing',
        CAST(COUNT_IF(date_registration IS NULL) AS STRING),
        COUNT(*),
        COUNT(*) - COUNT_IF(date_registration IS NULL),
        COUNT_IF(date_registration IS NULL)
    FROM base

    UNION ALL

    -- date_unregistration NULL is legitimate because students may not withdraw
    SELECT
        'student_registration_bronze',
        'date_unregistration',
        'NULL',
        'Unregistration date may be NULL for active students',
        'INFO',
        'NULL allowed when student did not withdraw',
        CAST(COUNT_IF(date_unregistration IS NULL) AS STRING),
        COUNT(*),
        COUNT(*) - COUNT_IF(date_unregistration IS NULL),
        COUNT_IF(date_unregistration IS NULL)
    FROM base

    UNION ALL

    -- Business key uniqueness
    SELECT
        'student_registration_bronze',
        'code_module, code_presentation, id_student',
        'UNIQUE',
        'Registration business key is unique',
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
        'student_registration_bronze',
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

    -- Date format checks
    SELECT
        'student_registration_bronze',
        'date_registration',
        'TYPE / FORMAT',
        'Registration date has valid format',
        'FAIL',
        'Numeric value or ?',
        CAST(COUNT_IF(
            date_registration IS NOT NULL
            AND TRIM(CAST(date_registration AS STRING)) <> '?'
            AND TRY_CAST(date_registration AS INT) IS NULL
        ) AS STRING),
        COUNT(*),
        COUNT(*) - COUNT_IF(
            date_registration IS NOT NULL
            AND TRIM(CAST(date_registration AS STRING)) <> '?'
            AND TRY_CAST(date_registration AS INT) IS NULL
        ),
        COUNT_IF(
            date_registration IS NOT NULL
            AND TRIM(CAST(date_registration AS STRING)) <> '?'
            AND TRY_CAST(date_registration AS INT) IS NULL
        )
    FROM base

    UNION ALL

    SELECT
        'student_registration_bronze',
        'date_unregistration',
        'TYPE / FORMAT',
        'Unregistration date has valid format',
        'FAIL',
        'Numeric value or ?',
        CAST(COUNT_IF(
            date_unregistration IS NOT NULL
            AND TRIM(CAST(date_unregistration AS STRING)) <> '?'
            AND TRY_CAST(date_unregistration AS INT) IS NULL
        ) AS STRING),
        COUNT(*),
        COUNT(*) - COUNT_IF(
            date_unregistration IS NOT NULL
            AND TRIM(CAST(date_unregistration AS STRING)) <> '?'
            AND TRY_CAST(date_unregistration AS INT) IS NULL
        ),
        COUNT_IF(
            date_unregistration IS NOT NULL
            AND TRIM(CAST(date_unregistration AS STRING)) <> '?'
            AND TRY_CAST(date_unregistration AS INT) IS NULL
        )
    FROM base

    UNION ALL

    -- Source sentinel checks
    SELECT
        'student_registration_bronze',
        'date_registration',
        'SOURCE SENTINEL',
        'Source sentinel (?) in date_registration',
        'WARN',
        'Source may use ? for unavailable registration date',
        CAST(COUNT_IF(
            TRIM(CAST(date_registration AS STRING)) = '?'
        ) AS STRING),
        COUNT(*),
        COUNT(*) - COUNT_IF(
            TRIM(CAST(date_registration AS STRING)) = '?'
        ),
        COUNT_IF(
            TRIM(CAST(date_registration AS STRING)) = '?'
        )
    FROM base

    UNION ALL

    SELECT
        'student_registration_bronze',
        'date_unregistration',
        'SOURCE SENTINEL',
        'Source sentinel (?) in date_unregistration',
        'WARN',
        'Source may use ? when student did not withdraw',
        CAST(COUNT_IF(
            TRIM(CAST(date_unregistration AS STRING)) = '?'
        ) AS STRING),
        COUNT(*),
        COUNT(*) - COUNT_IF(
            TRIM(CAST(date_unregistration AS STRING)) = '?'
        ),
        COUNT_IF(
            TRIM(CAST(date_unregistration AS STRING)) = '?'
        )
    FROM base

    UNION ALL

    -- Course referential integrity
    SELECT
        'student_registration_bronze',
        'code_module, code_presentation',
        'REFERENTIAL INTEGRITY',
        'Registration course presentation exists',
        'FAIL',
        '0 unmatched course presentations',
        CAST(COUNT_IF(
            c.code_module IS NULL
            OR c.code_presentation IS NULL
        ) AS STRING),
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

    UNION ALL

    -- Student referential integrity
    SELECT
        'student_registration_bronze',
        'id_student',
        'REFERENTIAL INTEGRITY',
        'Registration student exists',
        'FAIL',
        '0 unmatched students',
        CAST(COUNT_IF(s.id_student IS NULL) AS STRING),
        COUNT(*),
        COUNT(*) - COUNT_IF(s.id_student IS NULL),
        COUNT_IF(s.id_student IS NULL)
    FROM base b
    LEFT JOIN student_keys s
        ON b.id_student = s.id_student
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
            WHEN c.severity IN ('INFO', 'WARN') THEN NULL
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