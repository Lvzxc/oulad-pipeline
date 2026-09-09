-- STUDENT VLE SILVER DATA QUALITY VALIDATION

WITH checks AS (

    -- Volume / deduplication check
    SELECT
        'student_vle_silver' AS table_name,
        'Bronze-to-Silver deduplication' AS check_name,
        'VOLUME' AS check_type,
        COUNT(*) AS records_checked,
        CASE
            WHEN COUNT(*) =
                 (
                     SELECT COUNT(DISTINCT CONCAT(
                         id_student, '|',
                         code_module, '|',
                         code_presentation, '|',
                         id_site, '|',
                         date
                     ))
                     FROM oulad.oulad_bronze.student_vle_bronze
                 )
            THEN 0
            ELSE ABS(
                COUNT(*) -
                (
                    SELECT COUNT(DISTINCT CONCAT(
                        id_student, '|',
                        code_module, '|',
                        code_presentation, '|',
                        id_site, '|',
                        date
                    ))
                    FROM oulad.oulad_bronze.student_vle_bronze
                )
            )
        END AS failures
    FROM oulad.oulad_silver.student_vle_silver

    UNION ALL

    -- NULL checks
    SELECT
        'student_vle_silver',
        'Missing id_student',
        'NULL',
        COUNT(*),
        SUM(CASE WHEN id_student IS NULL THEN 1 ELSE 0 END)
    FROM oulad.oulad_silver.student_vle_silver

    UNION ALL

    SELECT
        'student_vle_silver',
        'Missing id_site',
        'NULL',
        COUNT(*),
        SUM(CASE WHEN id_site IS NULL THEN 1 ELSE 0 END)
    FROM oulad.oulad_silver.student_vle_silver

    UNION ALL

    SELECT
        'student_vle_silver',
        'Missing date',
        'NULL',
        COUNT(*),
        SUM(CASE WHEN date IS NULL THEN 1 ELSE 0 END)
    FROM oulad.oulad_silver.student_vle_silver

    UNION ALL

    SELECT
        'student_vle_silver',
        'Missing code_module',
        'NULL',
        COUNT(*),
        SUM(CASE WHEN code_module IS NULL THEN 1 ELSE 0 END)
    FROM oulad.oulad_silver.student_vle_silver

    UNION ALL

    SELECT
        'student_vle_silver',
        'Missing code_presentation',
        'NULL',
        COUNT(*),
        SUM(CASE WHEN code_presentation IS NULL THEN 1 ELSE 0 END)
    FROM oulad.oulad_silver.student_vle_silver

    UNION ALL

    SELECT
        'student_vle_silver',
        'Missing sum_click',
        'NULL',
        COUNT(*),
        SUM(CASE WHEN sum_click IS NULL THEN 1 ELSE 0 END)
    FROM oulad.oulad_silver.student_vle_silver

    UNION ALL

    -- Uniqueness check
    SELECT
        'student_vle_silver',
        'Duplicate student-site-date business key',
        'UNIQUE',
        COUNT(*),
        COUNT(*) -
        COUNT(DISTINCT CONCAT(
            id_student, '|',
            id_site, '|',
            date
        ))
    FROM oulad.oulad_silver.student_vle_silver

    UNION ALL

    -- Sentinel check
    SELECT
        'student_vle_silver',
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
    FROM oulad.oulad_silver.student_vle_silver

    UNION ALL

    -- Standardization check
    SELECT
        'student_vle_silver',
        'Unstandardized module/presentation values',
        'STANDARDIZATION',
        COUNT(*),
        SUM(
            CASE
                WHEN code_module <> TRIM(code_module)
                  OR code_presentation <> TRIM(code_presentation)
                THEN 1
                ELSE 0
            END
        )
    FROM oulad.oulad_silver.student_vle_silver

    UNION ALL

    -- Student foreign key
    SELECT
        'student_vle_silver',
        'VLE activity without matching student',
        'FOREIGN KEY',
        COUNT(*),
        COUNT(*)
    FROM oulad.oulad_silver.student_vle_silver sv
    LEFT JOIN oulad.oulad_silver.student_info_silver si
        ON sv.id_student = si.id_student
        AND sv.code_module = si.code_module
        AND sv.code_presentation = si.code_presentation
    WHERE si.id_student IS NULL

    UNION ALL

    -- VLE site foreign key
    SELECT
        'student_vle_silver',
        'VLE activity without matching site',
        'FOREIGN KEY',
        COUNT(*),
        COUNT(*)
    FROM oulad.oulad_silver.student_vle_silver sv
    LEFT JOIN oulad.oulad_silver.vle_silver v
        ON sv.id_site = v.id_site
    WHERE v.id_site IS NULL

    UNION ALL

    -- Course foreign key
    SELECT
        'student_vle_silver',
        'VLE activity without matching course',
        'FOREIGN KEY',
        COUNT(*),
        COUNT(*)
    FROM oulad.oulad_silver.student_vle_silver sv
    LEFT JOIN oulad.oulad_silver.courses_silver c
        ON sv.code_module = c.code_module
        AND sv.code_presentation = c.code_presentation
    WHERE c.code_module IS NULL

    UNION ALL

    -- Lineage checks
    SELECT
        'student_vle_silver',
        'Missing ingestion timestamp',
        'LINEAGE',
        COUNT(*),
        SUM(
            CASE
                WHEN ingestion_timestamp IS NULL THEN 1
                ELSE 0
            END
        )
    FROM oulad.oulad_silver.student_vle_silver

    UNION ALL

    SELECT
        'student_vle_silver',
        'Missing ingestion date',
        'LINEAGE',
        COUNT(*),
        SUM(
            CASE
                WHEN ingestion_date IS NULL THEN 1
                ELSE 0
            END
        )
    FROM oulad.oulad_silver.student_vle_silver
)

SELECT
    table_name,
    check_name,
    check_type,
    records_checked,
    failures,

    ROUND(
        failures * 100.0 /
        NULLIF(records_checked, 0),
        2
    ) AS failure_percentage,

    CASE
        WHEN failures = 0 THEN 'PASS'
        WHEN failures * 100.0 /
             NULLIF(records_checked, 0) <= 1
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