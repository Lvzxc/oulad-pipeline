-- STUDENT REGISTRATION SILVER DATA QUALITY VALIDATION

WITH base AS (
    SELECT *
    FROM oulad.oulad_silver.student_registration_silver
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
        'student_registration_silver',
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
        'student_registration_silver',
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
        'student_registration_silver',
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
        'student_registration_silver',
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

    -- Bronze '?' values are expected to become NULL
    SELECT
        'student_registration_silver',
        'date_registration',
        'NULL',
        'NULL date_registration values match expected Bronze sentinel count',
        'WARN',
        CAST(e.expected_null_date_registration AS STRING),
        CAST(COUNT_IF(r.date_registration IS NULL) AS STRING),
        COUNT(*),
        COUNT(*) - COUNT_IF(r.date_registration IS NULL),
        COUNT_IF(r.date_registration IS NULL)
    FROM base r
    CROSS JOIN bronze_expectations e
    GROUP BY e.expected_null_date_registration

    UNION ALL

    SELECT
        'student_registration_silver',
        'date_unregistration',
        'NULL',
        'NULL date_unregistration values match expected Bronze sentinel count',
        'WARN',
        CAST(e.expected_null_date_unregistration AS STRING),
        CAST(COUNT_IF(r.date_unregistration IS NULL) AS STRING),
        COUNT(*),
        COUNT(*) - COUNT_IF(r.date_unregistration IS NULL),
        COUNT_IF(r.date_unregistration IS NULL)
    FROM base r
    CROSS JOIN bronze_expectations e
    GROUP BY e.expected_null_date_unregistration

    UNION ALL

    -- Business key uniqueness
    SELECT
        'student_registration_silver',
        NULL,
        'UNIQUE',
        'Student-registration business key is unique',
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
        'student_registration_silver',
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

    -- No unresolved sentinel values in categorical fields
    SELECT
        'student_registration_silver',
        NULL,
        'SOURCE SENTINEL',
        'No unresolved sentinel (?) values remain',
        'FAIL',
        '0',
        CAST(COUNT_IF(
            code_module = '?'
            OR code_presentation = '?'
        ) AS STRING),
        COUNT(*),
        COUNT(*) - COUNT_IF(
            code_module = '?'
            OR code_presentation = '?'
        ),
        COUNT_IF(
            code_module = '?'
            OR code_presentation = '?'
        )
    FROM base

    UNION ALL

    -- Standardization
    SELECT
        'student_registration_silver',
        NULL,
        'STANDARDIZATION',
        'Module and presentation values are trimmed and uppercase',
        'FAIL',
        '0 unstandardized records',
        CAST(COUNT_IF(
            code_module <> UPPER(TRIM(code_module))
            OR code_presentation <> UPPER(TRIM(code_presentation))
        ) AS STRING),
        COUNT(*),
        COUNT(*) - COUNT_IF(
            code_module <> UPPER(TRIM(code_module))
            OR code_presentation <> UPPER(TRIM(code_presentation))
        ),
        COUNT_IF(
            code_module <> UPPER(TRIM(code_module))
            OR code_presentation <> UPPER(TRIM(code_presentation))
        )
    FROM base

    UNION ALL

    -- Registration date range
    SELECT
        'student_registration_silver',
        'date_registration',
        'RANGE',
        'Registration date is within expected range',
        'FAIL',
        '0 invalid records',
        CAST(COUNT_IF(
            date_registration IS NOT NULL
            AND date_registration < -365
        ) AS STRING),
        COUNT(*),
        COUNT(*) - COUNT_IF(
            date_registration IS NOT NULL
            AND date_registration < -365
        ),
        COUNT_IF(
            date_registration IS NOT NULL
            AND date_registration < -365
        )
    FROM base

    UNION ALL

    -- Unregistration date range
    SELECT
        'student_registration_silver',
        'date_unregistration',
        'RANGE',
        'Unregistration date is within expected range',
        'FAIL',
        '0 invalid records',
        CAST(COUNT_IF(
            date_unregistration IS NOT NULL
            AND date_unregistration < -365
        ) AS STRING),
        COUNT(*),
        COUNT(*) - COUNT_IF(
            date_unregistration IS NOT NULL
            AND date_unregistration < -365
        ),
        COUNT_IF(
            date_unregistration IS NOT NULL
            AND date_unregistration < -365
        )
    FROM base

    UNION ALL

    -- Student referential integrity
    SELECT
        'student_registration_silver',
        NULL,
        'REFERENTIAL INTEGRITY',
        'Every registration references an existing student-course record',
        'FAIL',
        '0 unmatched records',
        CAST(COUNT_IF(s.id_student IS NULL) AS STRING),
        COUNT(*),
        COUNT(*) - COUNT_IF(s.id_student IS NULL),
        COUNT_IF(s.id_student IS NULL)
    FROM base r
    LEFT JOIN student_keys s
        ON r.id_student = s.id_student
       AND r.code_module = s.code_module
       AND r.code_presentation = s.code_presentation

    UNION ALL

    -- Course referential integrity
    SELECT
        'student_registration_silver',
        NULL,
        'REFERENTIAL INTEGRITY',
        'Every registration references an existing course presentation',
        'FAIL',
        '0 unmatched records',
        CAST(COUNT_IF(c.code_module IS NULL) AS STRING),
        COUNT(*),
        COUNT(*) - COUNT_IF(c.code_module IS NULL),
        COUNT_IF(c.code_module IS NULL)
    FROM base r
    LEFT JOIN course_keys c
        ON r.code_module = c.code_module
       AND r.code_presentation = c.code_presentation

    UNION ALL

    -- Ingestion lineage
    SELECT
        'student_registration_silver',
        'ingestion_timestamp',
        'LINEAGE',
        'Ingestion timestamp is present',
        'FAIL',
        '0 missing records',
        CAST(COUNT_IF(ingestion_timestamp IS NULL) AS STRING),
        COUNT(*),
        COUNT(*) - COUNT_IF(ingestion_timestamp IS NULL),
        COUNT_IF(ingestion_timestamp IS NULL)
    FROM base

    UNION ALL

    SELECT
        'student_registration_silver',
        'ingestion_date',
        'LINEAGE',
        'Ingestion date is present',
        'FAIL',
        '0 missing records',
        CAST(COUNT_IF(ingestion_date IS NULL) AS STRING),
        COUNT(*),
        COUNT(*) - COUNT_IF(ingestion_date IS NULL),
        COUNT_IF(ingestion_date IS NULL)
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
            WHEN c.severity IN ('INFO', 'WARN') THEN NULL
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