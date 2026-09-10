-- STUDENT VLE SILVER DATA QUALITY VALIDATION

WITH base AS (
    SELECT *
    FROM oulad.oulad_silver.student_vle_silver
),

-- Expected row count is the distinct Bronze business-key count
-- because Silver removes duplicate student-site-date records.
bronze_expectations AS (
    SELECT
        COUNT(DISTINCT CONCAT(
            id_student, '|',
            code_module, '|',
            code_presentation, '|',
            id_site, '|',
            date
        )) AS expected_silver_count
    FROM oulad.oulad_bronze.student_vle_bronze
),

student_keys AS (
    SELECT DISTINCT
        id_student,
        code_module,
        code_presentation
    FROM oulad.oulad_silver.student_info_silver
    WHERE id_student IS NOT NULL
),

vle_keys AS (
    SELECT DISTINCT
        id_site
    FROM oulad.oulad_silver.vle_silver
    WHERE id_site IS NOT NULL
),

course_keys AS (
    SELECT DISTINCT
        code_module,
        code_presentation
    FROM oulad.oulad_silver.courses_silver
),

dq_results AS (

    -- Volume / deduplication check
    SELECT
        'student_vle_silver' AS table_name,
        'Bronze-to-Silver deduplication' AS check_name,
        'VOLUME' AS check_type,
        COUNT(*) AS records_checked,
        ABS(COUNT(*) - e.expected_silver_count) AS failures,
        CAST(e.expected_silver_count AS STRING) AS expected_value
    FROM base
    CROSS JOIN bronze_expectations e
    GROUP BY e.expected_silver_count

    UNION ALL

    -- NULL checks
    SELECT
        'student_vle_silver',
        'Missing id_student',
        'NULL',
        COUNT(*),
        COUNT_IF(id_student IS NULL),
        '0'
    FROM base

    UNION ALL

    SELECT
        'student_vle_silver',
        'Missing id_site',
        'NULL',
        COUNT(*),
        COUNT_IF(id_site IS NULL),
        '0'
    FROM base

    UNION ALL

    SELECT
        'student_vle_silver',
        'Missing date',
        'NULL',
        COUNT(*),
        COUNT_IF(date IS NULL),
        '0'
    FROM base

    UNION ALL

    SELECT
        'student_vle_silver',
        'Missing code_module',
        'NULL',
        COUNT(*),
        COUNT_IF(code_module IS NULL),
        '0'
    FROM base

    UNION ALL

    SELECT
        'student_vle_silver',
        'Missing code_presentation',
        'NULL',
        COUNT(*),
        COUNT_IF(code_presentation IS NULL),
        '0'
    FROM base

    UNION ALL

    SELECT
        'student_vle_silver',
        'Missing sum_click',
        'NULL',
        COUNT(*),
        COUNT_IF(sum_click IS NULL),
        '0'
    FROM base

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
        )),
        '0'
    FROM base

    UNION ALL

    -- Sentinel check
    SELECT
        'student_vle_silver',
        'Unresolved sentinel (?) values',
        'SENTINEL',
        COUNT(*),
        COUNT_IF(
            code_module = '?'
            OR code_presentation = '?'
        ),
        '0'
    FROM base

    UNION ALL

    -- Standardization check
    SELECT
        'student_vle_silver',
        'Unstandardized module/presentation values',
        'STANDARDIZATION',
        COUNT(*),
        COUNT_IF(
            code_module <> TRIM(code_module)
            OR code_presentation <> TRIM(code_presentation)
        ),
        '0'
    FROM base

    UNION ALL

    -- Student foreign key
    SELECT
        'student_vle_silver',
        'VLE activity without matching student',
        'FOREIGN KEY',
        COUNT(*),
        COUNT_IF(si.id_student IS NULL),
        '0'
    FROM base sv
    LEFT JOIN student_keys si
        ON sv.id_student = si.id_student
        AND sv.code_module = si.code_module
        AND sv.code_presentation = si.code_presentation

    UNION ALL

    -- VLE site foreign key
    SELECT
        'student_vle_silver',
        'VLE activity without matching site',
        'FOREIGN KEY',
        COUNT(*),
        COUNT_IF(v.id_site IS NULL),
        '0'
    FROM base sv
    LEFT JOIN vle_keys v
        ON sv.id_site = v.id_site

    UNION ALL

    -- Course foreign key
    SELECT
        'student_vle_silver',
        'VLE activity without matching course',
        'FOREIGN KEY',
        COUNT(*),
        COUNT_IF(c.code_module IS NULL),
        '0'
    FROM base sv
    LEFT JOIN course_keys c
        ON sv.code_module = c.code_module
        AND sv.code_presentation = c.code_presentation

    UNION ALL

    -- Lineage checks
    SELECT
        'student_vle_silver',
        'Missing ingestion timestamp',
        'LINEAGE',
        COUNT(*),
        COUNT_IF(ingestion_timestamp IS NULL),
        '0'
    FROM base

    UNION ALL

    SELECT
        'student_vle_silver',
        'Missing ingestion date',
        'LINEAGE',
        COUNT(*),
        COUNT_IF(ingestion_date IS NULL),
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

        -- No actual failures means the check passes.
        WHEN failures = 0
        THEN 'PASS'

        -- Mandatory key fields: any NULL is a FAIL.
        WHEN check_name IN (
            'Missing id_student',
            'Missing id_site',
            'Missing date',
            'Missing code_module',
            'Missing code_presentation'
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

        -- VOLUME: 2% warning threshold.
        WHEN check_type = 'VOLUME'
             AND failure_pct <= 2
        THEN 'WARN'

        WHEN check_type = 'VOLUME'
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