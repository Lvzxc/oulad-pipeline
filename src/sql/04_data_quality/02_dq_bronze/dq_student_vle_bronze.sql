-- STUDENT VLE BRONZE DATA QUALITY VALIDATION

WITH base AS (
    SELECT *
    FROM oulad.oulad_bronze.student_vle_bronze
),

run_info AS (
    SELECT
        uuid() AS run_id,
        current_timestamp() AS run_timestamp
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

checks AS (

    -- Volume
    SELECT
        'VOLUME' AS dq_dimension,
        'Row count' AS rule_name,
        'INFO' AS severity,
        'EXPECTED ROW COUNT > 0' AS expected_value,
        CAST(COUNT(*) AS STRING) AS actual_value,
        COUNT(*) AS total_records,
        COUNT(*) AS passed_records,
        0 AS failed_records
    FROM base

    UNION ALL

    -- Required fields
    SELECT
        'NULL',
        'Missing code_module',
        'FAIL',
        '0% missing; mandatory key',
        CAST(COUNT_IF(code_module IS NULL) AS STRING),
        COUNT(*),
        COUNT(*) - COUNT_IF(code_module IS NULL),
        COUNT_IF(code_module IS NULL)
    FROM base

    UNION ALL

    SELECT
        'NULL',
        'Missing code_presentation',
        'FAIL',
        '0% missing; mandatory key',
        CAST(COUNT_IF(code_presentation IS NULL) AS STRING),
        COUNT(*),
        COUNT(*) - COUNT_IF(code_presentation IS NULL),
        COUNT_IF(code_presentation IS NULL)
    FROM base

    UNION ALL

    SELECT
        'NULL',
        'Missing id_student',
        'FAIL',
        '0% missing; mandatory key',
        CAST(COUNT_IF(id_student IS NULL) AS STRING),
        COUNT(*),
        COUNT(*) - COUNT_IF(id_student IS NULL),
        COUNT_IF(id_student IS NULL)
    FROM base

    UNION ALL

    SELECT
        'NULL',
        'Missing id_site',
        'FAIL',
        '0% missing; mandatory key',
        CAST(COUNT_IF(id_site IS NULL) AS STRING),
        COUNT(*),
        COUNT(*) - COUNT_IF(id_site IS NULL),
        COUNT_IF(id_site IS NULL)
    FROM base

    UNION ALL

    SELECT
        'NULL',
        'Missing date',
        'WARN',
        'Date should normally be populated',
        CAST(COUNT_IF(date IS NULL) AS STRING),
        COUNT(*),
        COUNT(*) - COUNT_IF(date IS NULL),
        COUNT_IF(date IS NULL)
    FROM base

    UNION ALL

    SELECT
        'NULL',
        'Missing sum_click',
        'WARN',
        'sum_click should normally be populated',
        CAST(COUNT_IF(sum_click IS NULL) AS STRING),
        COUNT(*),
        COUNT(*) - COUNT_IF(sum_click IS NULL),
        COUNT_IF(sum_click IS NULL)
    FROM base

    UNION ALL

    -- Business key uniqueness
    SELECT
        'UNIQUE',
        'Duplicate student-VLE business key',
        'FAIL',
        '0% duplicate student + module + presentation + site + date',
        CAST(
            COUNT(*) - COUNT(DISTINCT CONCAT(
                CAST(id_student AS STRING), '|',
                TRIM(UPPER(code_module)), '|',
                TRIM(UPPER(code_presentation)), '|',
                CAST(id_site AS STRING), '|',
                CAST(date AS STRING)
            ))
            AS STRING
        ),
        COUNT(*),
        COUNT(DISTINCT CONCAT(
            CAST(id_student AS STRING), '|',
            TRIM(UPPER(code_module)), '|',
            TRIM(UPPER(code_presentation)), '|',
            CAST(id_site AS STRING), '|',
            CAST(date AS STRING)
        )),
        COUNT(*) - COUNT(DISTINCT CONCAT(
            CAST(id_student AS STRING), '|',
            TRIM(UPPER(code_module)), '|',
            TRIM(UPPER(code_presentation)), '|',
            CAST(id_site AS STRING), '|',
            CAST(date AS STRING)
        ))
    FROM base

    UNION ALL

    -- Exact duplicates
    SELECT
        'UNIQUE',
        'Exact duplicate records',
        'FAIL',
        '0% exact duplicate records',
        CAST(
            COUNT(*) - COUNT(DISTINCT
                code_module,
                code_presentation,
                id_student,
                id_site,
                date,
                sum_click
            )
            AS STRING
        ),
        COUNT(*),
        COUNT(DISTINCT
            code_module,
            code_presentation,
            id_student,
            id_site,
            date,
            sum_click
        ),
        COUNT(*) - COUNT(DISTINCT
            code_module,
            code_presentation,
            id_student,
            id_site,
            date,
            sum_click
        )
    FROM base

    UNION ALL

    -- Range
    SELECT
        'RANGE',
        'Negative sum_click',
        'FAIL',
        'sum_click >= 0',
        CAST(COUNT_IF(sum_click < 0) AS STRING),
        COUNT(*),
        COUNT(*) - COUNT_IF(sum_click < 0),
        COUNT_IF(sum_click < 0)
    FROM base

    UNION ALL

    -- Referential integrity: course
    SELECT
        'REFERENTIAL INTEGRITY',
        'Activity without matching course presentation',
        'FAIL',
        'Every code_module + code_presentation should exist in courses_bronze',
        CAST(
            COUNT_IF(
                c.code_module IS NULL
                OR c.code_presentation IS NULL
            ) AS STRING
        ),
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

    -- Referential integrity: student
    SELECT
        'REFERENTIAL INTEGRITY',
        'Activity without matching student',
        'FAIL',
        'Every id_student should exist in student_info_bronze',
        CAST(COUNT_IF(s.id_student IS NULL) AS STRING),
        COUNT(*),
        COUNT(*) - COUNT_IF(s.id_student IS NULL),
        COUNT_IF(s.id_student IS NULL)
    FROM base b
    LEFT JOIN student_keys s
        ON b.id_student = s.id_student

    UNION ALL

    -- Referential integrity: VLE site
    SELECT
        'REFERENTIAL INTEGRITY',
        'Activity without matching VLE site',
        'FAIL',
        'Every id_site + module + presentation should exist in vle_bronze',
        CAST(COUNT_IF(v.id_site IS NULL) AS STRING),
        COUNT(*),
        COUNT(*) - COUNT_IF(v.id_site IS NULL),
        COUNT_IF(v.id_site IS NULL)
    FROM base b
    LEFT JOIN vle_keys v
        ON b.id_site = v.id_site
        AND TRIM(UPPER(b.code_module)) = v.code_module
        AND TRIM(UPPER(b.code_presentation)) = v.code_presentation
),

final_results AS (
    SELECT
        r.run_id,
        r.run_timestamp,
        'BRONZE' AS layer,
        'student_vle_bronze' AS table_name,

        CASE
            WHEN c.rule_name LIKE '%code_module%' THEN 'code_module'
            WHEN c.rule_name LIKE '%code_presentation%' THEN 'code_presentation'
            WHEN c.rule_name LIKE '%id_student%' THEN 'id_student'
            WHEN c.rule_name LIKE '%id_site%' THEN 'id_site'
            WHEN c.rule_name LIKE '%date%' THEN 'date'
            WHEN c.rule_name LIKE '%sum_click%' THEN 'sum_click'
            ELSE NULL
        END AS column_name,

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
    CROSS JOIN run_info r
)

INSERT INTO oulad.oulad_quality.dq_results
SELECT *
FROM final_results;