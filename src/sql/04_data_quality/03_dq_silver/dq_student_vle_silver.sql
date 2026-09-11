-- STUDENT VLE SILVER DATA QUALITY VALIDATION

WITH base AS (
    SELECT *
    FROM oulad.oulad_silver.student_vle_silver
),

table_count AS (
    SELECT COUNT(*) AS total_records
    FROM base
),

-- Silver removes duplicate student-site-date records,
-- so the expected Silver volume is the distinct Bronze business-key count.
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

exact_duplicate_count AS (
    SELECT
        COALESCE(SUM(duplicate_count - 1), 0) AS duplicate_records
    FROM (
        SELECT
            id_student,
            code_module,
            code_presentation,
            id_site,
            date,
            sum_click,
            COUNT(*) AS duplicate_count
        FROM base
        GROUP BY
            id_student,
            code_module,
            code_presentation,
            id_site,
            date,
            sum_click
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
        'student_vle_silver',
        NULL,
        'VOLUME',
        'Silver row count matches expected distinct Bronze business-key count',
        'INFO',
        CAST(e.expected_silver_count AS STRING),
        CAST(tc.total_records AS STRING),
        tc.total_records,
        tc.total_records - ABS(
            tc.total_records - e.expected_silver_count
        ),
        ABS(
            tc.total_records - e.expected_silver_count
        )
    FROM table_count tc
    CROSS JOIN bronze_expectations e

    UNION ALL

    -- Required fields
    SELECT
        'student_vle_silver',
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

    SELECT
        'student_vle_silver',
        'id_site',
        'NULL',
        'Required id_site is not NULL',
        'FAIL',
        '0',
        CAST(COUNT_IF(id_site IS NULL) AS STRING),
        COUNT(*),
        COUNT(*) - COUNT_IF(id_site IS NULL),
        COUNT_IF(id_site IS NULL)
    FROM base

    UNION ALL

    SELECT
        'student_vle_silver',
        'date',
        'NULL',
        'Required date is not NULL',
        'FAIL',
        '0',
        CAST(COUNT_IF(date IS NULL) AS STRING),
        COUNT(*),
        COUNT(*) - COUNT_IF(date IS NULL),
        COUNT_IF(date IS NULL)
    FROM base

    UNION ALL

    SELECT
        'student_vle_silver',
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
        'student_vle_silver',
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
        'student_vle_silver',
        'sum_click',
        'NULL',
        'Required sum_click is not NULL',
        'FAIL',
        '0',
        CAST(COUNT_IF(sum_click IS NULL) AS STRING),
        COUNT(*),
        COUNT(*) - COUNT_IF(sum_click IS NULL),
        COUNT_IF(sum_click IS NULL)
    FROM base

    UNION ALL

    -- Business key uniqueness
    SELECT
        'student_vle_silver',
        NULL,
        'UNIQUE',
        'Student-VLE business key is unique',
        'FAIL',
        '0 duplicate records',
        CAST(
            COUNT(*) - COUNT(DISTINCT CONCAT(
                id_student, '|',
                code_module, '|',
                code_presentation, '|',
                id_site, '|',
                date
            ))
            AS STRING
        ),
        COUNT(*),
        COUNT(DISTINCT CONCAT(
            id_student, '|',
            code_module, '|',
            code_presentation, '|',
            id_site, '|',
            date
        )),
        COUNT(*) - COUNT(DISTINCT CONCAT(
            id_student, '|',
            code_module, '|',
            code_presentation, '|',
            id_site, '|',
            date
        ))
    FROM base

    UNION ALL

    -- Exact duplicates
    SELECT
        'student_vle_silver',
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

    -- No unresolved source sentinel values
    SELECT
        'student_vle_silver',
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
        'student_vle_silver',
        NULL,
        'STANDARDIZATION',
        'Module and presentation values are trimmed',
        'FAIL',
        '0 unstandardized records',
        CAST(COUNT_IF(
            code_module <> TRIM(code_module)
            OR code_presentation <> TRIM(code_presentation)
        ) AS STRING),
        COUNT(*),
        COUNT(*) - COUNT_IF(
            code_module <> TRIM(code_module)
            OR code_presentation <> TRIM(code_presentation)
        ),
        COUNT_IF(
            code_module <> TRIM(code_module)
            OR code_presentation <> TRIM(code_presentation)
        )
    FROM base

    UNION ALL

    -- Sum click range
    SELECT
        'student_vle_silver',
        'sum_click',
        'RANGE',
        'sum_click is not negative',
        'FAIL',
        '0 invalid records',
        CAST(COUNT_IF(
            sum_click IS NOT NULL
            AND sum_click < 0
        ) AS STRING),
        COUNT(*),
        COUNT(*) - COUNT_IF(
            sum_click IS NOT NULL
            AND sum_click < 0
        ),
        COUNT_IF(
            sum_click IS NOT NULL
            AND sum_click < 0
        )
    FROM base

    UNION ALL

    -- Student referential integrity
    SELECT
        'student_vle_silver',
        NULL,
        'REFERENTIAL INTEGRITY',
        'Every VLE activity references an existing student-course record',
        'FAIL',
        '0 unmatched records',
        CAST(COUNT_IF(s.id_student IS NULL) AS STRING),
        COUNT(*),
        COUNT(*) - COUNT_IF(s.id_student IS NULL),
        COUNT_IF(s.id_student IS NULL)
    FROM base sv
    LEFT JOIN student_keys s
        ON sv.id_student = s.id_student
       AND sv.code_module = s.code_module
       AND sv.code_presentation = s.code_presentation

    UNION ALL

    -- VLE site referential integrity
    SELECT
        'student_vle_silver',
        NULL,
        'REFERENTIAL INTEGRITY',
        'Every VLE activity references an existing VLE site',
        'FAIL',
        '0 unmatched records',
        CAST(COUNT_IF(v.id_site IS NULL) AS STRING),
        COUNT(*),
        COUNT(*) - COUNT_IF(v.id_site IS NULL),
        COUNT_IF(v.id_site IS NULL)
    FROM base sv
    LEFT JOIN vle_keys v
        ON sv.id_site = v.id_site

    UNION ALL

    -- Course referential integrity
    SELECT
        'student_vle_silver',
        NULL,
        'REFERENTIAL INTEGRITY',
        'Every VLE activity references an existing course presentation',
        'FAIL',
        '0 unmatched records',
        CAST(COUNT_IF(c.code_module IS NULL) AS STRING),
        COUNT(*),
        COUNT(*) - COUNT_IF(c.code_module IS NULL),
        COUNT_IF(c.code_module IS NULL)
    FROM base sv
    LEFT JOIN course_keys c
        ON sv.code_module = c.code_module
       AND sv.code_presentation = c.code_presentation

    UNION ALL

    -- Lineage
    SELECT
        'student_vle_silver',
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
        'student_vle_silver',
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