-- STUDENT REGISTRATION SILVER DATA QUALITY VALIDATION

WITH base AS (
    SELECT *
    FROM oulad.oulad_silver.student_registration_silver
),

-- Expected values are derived from Bronze to avoid hard-coded counts.
bronze_expectations AS (
    SELECT
        COUNT(*) AS bronze_count,
        SUM(
            CASE
                WHEN TRIM(date_registration) = '?' THEN 1
                ELSE 0
            END
        ) AS expected_null_date_registration,
        SUM(
            CASE
                WHEN TRIM(date_unregistration) = '?' THEN 1
                ELSE 0
            END
        ) AS expected_null_date_unregistration
    FROM oulad.oulad_bronze.student_registration_bronze
),

student_keys AS (
    SELECT DISTINCT
        id_student,
        code_module,
        code_presentation
    FROM oulad.oulad_silver.student_info_silver
    WHERE id_student IS NOT NULL
),

course_keys AS (
    SELECT DISTINCT
        code_module,
        code_presentation
    FROM oulad.oulad_silver.courses_silver
),

dq_results AS (

    -- Volume check
    SELECT
        'student_registration_silver' AS table_name,
        'Row count' AS check_name,
        'VOLUME' AS check_type,
        COUNT(*) AS records_checked,
        ABS(COUNT(*) - e.bronze_count) AS failures,
        CAST(e.bronze_count AS STRING) AS expected_value
    FROM base
    CROSS JOIN bronze_expectations e
    GROUP BY e.bronze_count

    UNION ALL

    -- Required fields
    SELECT
        'student_registration_silver',
        'Missing code_module',
        'NULL',
        COUNT(*),
        COUNT_IF(code_module IS NULL),
        '0'
    FROM base

    UNION ALL

    SELECT
        'student_registration_silver',
        'Missing code_presentation',
        'NULL',
        COUNT(*),
        COUNT_IF(code_presentation IS NULL),
        '0'
    FROM base

    UNION ALL

    SELECT
        'student_registration_silver',
        'Missing id_student',
        'NULL',
        COUNT(*),
        COUNT_IF(id_student IS NULL),
        '0'
    FROM base

    UNION ALL

    -- date_registration: Bronze '?' should become NULL.
    SELECT
        'student_registration_silver',
        'Missing date_registration',
        'NULL',
        COUNT(*),
        COUNT_IF(date_registration IS NULL),
        CAST(e.expected_null_date_registration AS STRING)
    FROM base
    CROSS JOIN bronze_expectations e
    GROUP BY e.expected_null_date_registration

    UNION ALL

    -- date_unregistration: NULL is expected for '?' values.
    SELECT
        'student_registration_silver',
        'Missing date_unregistration',
        'NULL',
        COUNT(*),
        COUNT_IF(date_unregistration IS NULL),
        CAST(e.expected_null_date_unregistration AS STRING)
    FROM base
    CROSS JOIN bronze_expectations e
    GROUP BY e.expected_null_date_unregistration

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
        )),
        '0'
    FROM base

    UNION ALL

    -- Sentinel cleanup
    SELECT
        'student_registration_silver',
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

    -- Standardization
    SELECT
        'student_registration_silver',
        'Unstandardized module/presentation values',
        'STANDARDIZATION',
        COUNT(*),
        COUNT_IF(
            code_module <> UPPER(TRIM(code_module))
            OR code_presentation <> UPPER(TRIM(code_presentation))
        ),
        '0'
    FROM base

    UNION ALL

    -- Registration date range
    SELECT
        'student_registration_silver',
        'Invalid date_registration range',
        'RANGE',
        COUNT(*),
        COUNT_IF(
            date_registration IS NOT NULL
            AND date_registration < -365
        ),
        '0'
    FROM base

    UNION ALL

    -- Unregistration date range
    SELECT
        'student_registration_silver',
        'Invalid date_unregistration range',
        'RANGE',
        COUNT(*),
        COUNT_IF(
            date_unregistration IS NOT NULL
            AND date_unregistration < -365
        ),
        '0'
    FROM base

    UNION ALL

    -- Registration FK to student info
    SELECT
        'student_registration_silver',
        'Registration without matching student',
        'FOREIGN KEY',
        COUNT(*),
        COUNT_IF(s.id_student IS NULL),
        '0'
    FROM base r
    LEFT JOIN student_keys s
        ON r.id_student = s.id_student
        AND r.code_module = s.code_module
        AND r.code_presentation = s.code_presentation

    UNION ALL

    -- Registration FK to courses
    SELECT
        'student_registration_silver',
        'Registration without matching course',
        'FOREIGN KEY',
        COUNT(*),
        COUNT_IF(c.code_module IS NULL),
        '0'
    FROM base r
    LEFT JOIN course_keys c
        ON r.code_module = c.code_module
        AND r.code_presentation = c.code_presentation

    UNION ALL

    -- Ingestion lineage
    SELECT
        'student_registration_silver',
        'Missing ingestion timestamp',
        'LINEAGE',
        COUNT(*),
        COUNT_IF(ingestion_timestamp IS NULL),
        '0'
    FROM base

    UNION ALL

    SELECT
        'student_registration_silver',
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

        -- Expected date NULLs are acceptable when they match Bronze.
        WHEN check_name IN (
            'Missing date_registration',
            'Missing date_unregistration'
        )
        AND CAST(failures AS STRING) = expected_value
        THEN 'PASS'

        -- No actual failures means the check passes.
        WHEN failures = 0
        THEN 'PASS'

        -- Mandatory key fields: any NULL is a FAIL.
        WHEN check_name IN (
            'Missing code_module',
            'Missing code_presentation',
            'Missing id_student'
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