-- STUDENT REGISTRATION SILVER DATA QUALITY VALIDATION

WITH checks AS (

    -- Volume check
    SELECT
        'student_registration_silver' AS table_name,
        'Row count' AS check_name,
        'VOLUME' AS check_type,
        (SELECT COUNT(*)
         FROM oulad.oulad_silver.student_registration_silver) AS records_checked,
        ABS(
            (SELECT COUNT(*)
             FROM oulad.oulad_silver.student_registration_silver)
            -
            (SELECT COUNT(*)
             FROM oulad.oulad_bronze.student_registration_bronze)
        ) AS failures

    UNION ALL

    -- Required fields
    SELECT
        'student_registration_silver',
        'Missing code_module',
        'NULL',
        COUNT(*),
        SUM(CASE WHEN code_module IS NULL THEN 1 ELSE 0 END)
    FROM oulad.oulad_silver.student_registration_silver

    UNION ALL

    SELECT
        'student_registration_silver',
        'Missing code_presentation',
        'NULL',
        COUNT(*),
        SUM(CASE WHEN code_presentation IS NULL THEN 1 ELSE 0 END)
    FROM oulad.oulad_silver.student_registration_silver

    UNION ALL

    SELECT
        'student_registration_silver',
        'Missing id_student',
        'NULL',
        COUNT(*),
        SUM(CASE WHEN id_student IS NULL THEN 1 ELSE 0 END)
    FROM oulad.oulad_silver.student_registration_silver

    UNION ALL

    -- date_registration: Bronze '?' should become NULL
    SELECT
        'student_registration_silver',
        'Unexpected missing date_registration',
        'NULL',
        COUNT(*),
        ABS(
            COUNT(*) FILTER (WHERE date_registration IS NULL)
            -
            (
                SELECT COUNT(*)
                FROM oulad.oulad_bronze.student_registration_bronze
                WHERE TRIM(date_registration) = '?'
            )
        )
    FROM oulad.oulad_silver.student_registration_silver

    UNION ALL

    -- date_unregistration: NULL is expected for '?' values
    SELECT
        'student_registration_silver',
        'Unexpected missing date_unregistration',
        'NULL',
        COUNT(*),
        ABS(
            COUNT(*) FILTER (WHERE date_unregistration IS NULL)
            -
            (
                SELECT COUNT(*)
                FROM oulad.oulad_bronze.student_registration_bronze
                WHERE TRIM(date_unregistration) = '?'
            )
        )
    FROM oulad.oulad_silver.student_registration_silver

    UNION ALL

    -- Business key uniqueness
    SELECT
        'student_registration_silver',
        'Duplicate student-registration business key',
        'UNIQUE',
        COUNT(*),
        COUNT(*) -
        COUNT(DISTINCT CONCAT(
            code_module, '|',
            code_presentation, '|',
            id_student
        ))
    FROM oulad.oulad_silver.student_registration_silver

    UNION ALL

    -- Sentinel cleanup
    SELECT
        'student_registration_silver',
        'Unresolved sentinel (?) values',
        'SENTINEL',
        COUNT(*),
        SUM(
            CASE
                WHEN code_module = '?'
                  OR code_presentation = '?'
                THEN 1
                ELSE 0
            END
        )
    FROM oulad.oulad_silver.student_registration_silver

    UNION ALL

    -- Standardization
    SELECT
        'student_registration_silver',
        'Unstandardized module/presentation values',
        'STANDARDIZATION',
        COUNT(*),
        SUM(
            CASE
                WHEN code_module <> UPPER(TRIM(code_module))
                  OR code_presentation <> UPPER(TRIM(code_presentation))
                THEN 1
                ELSE 0
            END
        )
    FROM oulad.oulad_silver.student_registration_silver

    UNION ALL

    -- Registration date range
    SELECT
        'student_registration_silver',
        'Invalid date_registration range',
        'RANGE',
        COUNT(*),
        SUM(
            CASE
                WHEN date_registration IS NOT NULL
                 AND date_registration < -365
                THEN 1
                ELSE 0
            END
        )
    FROM oulad.oulad_silver.student_registration_silver

    UNION ALL

    -- Unregistration date range
    SELECT
        'student_registration_silver',
        'Invalid date_unregistration range',
        'RANGE',
        COUNT(*),
        SUM(
            CASE
                WHEN date_unregistration IS NOT NULL
                 AND date_unregistration < -365
                THEN 1
                ELSE 0
            END
        )
    FROM oulad.oulad_silver.student_registration_silver

    UNION ALL

    -- Registration FK to student info
    SELECT
        'student_registration_silver',
        'Registration without matching student',
        'FOREIGN KEY',
        COUNT(*),
        COUNT(*)
    FROM oulad.oulad_silver.student_registration_silver r
    LEFT JOIN oulad.oulad_silver.student_info_silver s
        ON r.id_student = s.id_student
        AND r.code_module = s.code_module
        AND r.code_presentation = s.code_presentation
    WHERE s.id_student IS NULL

    UNION ALL

    -- Registration FK to courses
    SELECT
        'student_registration_silver',
        'Registration without matching course',
        'FOREIGN KEY',
        COUNT(*),
        COUNT(*)
    FROM oulad.oulad_silver.student_registration_silver r
    LEFT JOIN oulad.oulad_silver.courses_silver c
        ON r.code_module = c.code_module
        AND r.code_presentation = c.code_presentation
    WHERE c.code_module IS NULL

    UNION ALL

    -- Ingestion lineage
    SELECT
        'student_registration_silver',
        'Missing ingestion timestamp',
        'LINEAGE',
        COUNT(*),
        SUM(
            CASE
                WHEN ingestion_timestamp IS NULL THEN 1
                ELSE 0
            END
        )
    FROM oulad.oulad_silver.student_registration_silver

    UNION ALL

    SELECT
        'student_registration_silver',
        'Missing ingestion date',
        'LINEAGE',
        COUNT(*),
        SUM(
            CASE
                WHEN ingestion_date IS NULL THEN 1
                ELSE 0
            END
        )
    FROM oulad.oulad_silver.student_registration_silver
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
        WHEN check_name IN (
            'Unexpected missing date_registration',
            'Unexpected missing date_unregistration'
        )
        AND failures = 0
            THEN 'PASS'

        WHEN failures = 0
            THEN 'PASS'

        WHEN failures * 100.0 / NULLIF(records_checked, 0) <= 1
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