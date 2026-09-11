WITH base AS (
    SELECT *
    FROM oulad.oulad_gold.fact_vle_interaction
),

expected AS (
    SELECT
        sv.id_student,
        sv.code_module,
        sv.code_presentation,
        sv.id_site,
        sv.date,
        sv.sum_click,
        ds.student_key,
        dv.course_key,
        dv.site_key,
        dd.date_key
    FROM oulad.oulad_silver.student_vle_silver sv

    JOIN oulad.oulad_gold.dim_student ds
        ON sv.id_student = ds.id_student
        AND sv.code_module = ds.code_module
        AND sv.code_presentation = ds.code_presentation

    JOIN oulad.oulad_gold.dim_vle dv
        ON sv.id_site = dv.id_site
        AND sv.code_module = dv.code_module
        AND sv.code_presentation = dv.code_presentation

    -- DATE: source date is a relative day
    JOIN oulad.oulad_gold.dim_date dd
        ON sv.date = dd.relative_day
),

checks AS (

    -- NULL: student_key
    SELECT
        'GOLD' AS layer,
        'fact_vle_interaction' AS table_name,
        'student_key' AS column_name,
        'NULL' AS dq_dimension,
        'Missing student_key' AS rule_name,
        'ERROR' AS severity,
        '0' AS expected_value,
        CAST(COUNT_IF(student_key IS NULL) AS STRING) AS actual_value,
        COUNT(*) AS total_records,
        COUNT(*) - COUNT_IF(student_key IS NULL) AS passed_records,
        COUNT_IF(student_key IS NULL) AS failed_records
    FROM base

    UNION ALL

    -- NULL: course_key
    SELECT
        'GOLD',
        'fact_vle_interaction',
        'course_key',
        'NULL',
        'Missing course_key',
        'ERROR',
        '0',
        CAST(COUNT_IF(course_key IS NULL) AS STRING),
        COUNT(*),
        COUNT(*) - COUNT_IF(course_key IS NULL),
        COUNT_IF(course_key IS NULL)
    FROM base

    UNION ALL

    -- NULL: site_key
    SELECT
        'GOLD',
        'fact_vle_interaction',
        'site_key',
        'NULL',
        'Missing site_key',
        'ERROR',
        '0',
        CAST(COUNT_IF(site_key IS NULL) AS STRING),
        COUNT(*),
        COUNT(*) - COUNT_IF(site_key IS NULL),
        COUNT_IF(site_key IS NULL)
    FROM base

    UNION ALL

    -- NULL: date_key
    SELECT
        'GOLD',
        'fact_vle_interaction',
        'date_key',
        'NULL',
        'Missing date_key',
        'ERROR',
        '0',
        CAST(COUNT_IF(date_key IS NULL) AS STRING),
        COUNT(*),
        COUNT(*) - COUNT_IF(date_key IS NULL),
        COUNT_IF(date_key IS NULL)
    FROM base

    UNION ALL

    -- UNIQUE: declared fact grain
    SELECT
        'GOLD',
        'fact_vle_interaction',
        'student_key + course_key + site_key + date_key',
        'UNIQUE',
        'Duplicate fact grain',
        'ERROR',
        '0',
        CAST(
            COUNT(*) - COUNT(
                DISTINCT CONCAT_WS(
                    '|',
                    student_key,
                    course_key,
                    site_key,
                    date_key
                )
            ) AS STRING
        ),
        COUNT(*),
        COUNT(
            DISTINCT CONCAT_WS(
                '|',
                student_key,
                course_key,
                site_key,
                date_key
            )
        ),
        COUNT(*) - COUNT(
            DISTINCT CONCAT_WS(
                '|',
                student_key,
                course_key,
                site_key,
                date_key
            )
        )
    FROM base

    UNION ALL

    -- RANGE: sum_click
    SELECT
        'GOLD',
        'fact_vle_interaction',
        'sum_click',
        'RANGE',
        'Negative sum_click',
        'ERROR',
        '0',
        CAST(COUNT_IF(sum_click < 0) AS STRING),
        COUNT(*),
        COUNT(*) - COUNT_IF(sum_click < 0),
        COUNT_IF(sum_click < 0)
    FROM base

    UNION ALL

    -- REFERENTIAL INTEGRITY: student
    SELECT
        'GOLD',
        'fact_vle_interaction',
        'student_key',
        'REFERENTIAL INTEGRITY',
        'Invalid student_key',
        'ERROR',
        '0',
        CAST(COUNT_IF(ds.student_key IS NULL) AS STRING),
        COUNT(*),
        COUNT(*) - COUNT_IF(ds.student_key IS NULL),
        COUNT_IF(ds.student_key IS NULL)
    FROM base b
    LEFT JOIN oulad.oulad_gold.dim_student ds
        ON b.student_key = ds.student_key

    UNION ALL

    -- REFERENTIAL INTEGRITY: course
    SELECT
        'GOLD',
        'fact_vle_interaction',
        'course_key',
        'REFERENTIAL INTEGRITY',
        'Invalid course_key',
        'ERROR',
        '0',
        CAST(COUNT_IF(dc.course_key IS NULL) AS STRING),
        COUNT(*),
        COUNT(*) - COUNT_IF(dc.course_key IS NULL),
        COUNT_IF(dc.course_key IS NULL)
    FROM base b
    LEFT JOIN oulad.oulad_gold.dim_course dc
        ON b.course_key = dc.course_key

    UNION ALL

    -- REFERENTIAL INTEGRITY: site
    SELECT
        'GOLD',
        'fact_vle_interaction',
        'site_key',
        'REFERENTIAL INTEGRITY',
        'Invalid site_key',
        'ERROR',
        '0',
        CAST(COUNT_IF(dv.site_key IS NULL) AS STRING),
        COUNT(*),
        COUNT(*) - COUNT_IF(dv.site_key IS NULL),
        COUNT_IF(dv.site_key IS NULL)
    FROM base b
    LEFT JOIN oulad.oulad_gold.dim_vle dv
        ON b.site_key = dv.site_key

    UNION ALL

    -- REFERENTIAL INTEGRITY: date
    SELECT
        'GOLD',
        'fact_vle_interaction',
        'date_key',
        'REFERENTIAL INTEGRITY',
        'Invalid date_key',
        'ERROR',
        '0',
        CAST(COUNT_IF(dd.date_key IS NULL) AS STRING),
        COUNT(*),
        COUNT(*) - COUNT_IF(dd.date_key IS NULL),
        COUNT_IF(dd.date_key IS NULL)
    FROM base b
    LEFT JOIN oulad.oulad_gold.dim_date dd
        ON b.date_key = dd.date_key

    UNION ALL

    -- BUSINESS RULE: student-course relationship
    SELECT
        'GOLD',
        'fact_vle_interaction',
        'student_key + course_key',
        'BUSINESS RULE',
        'Student-course relationship mismatch',
        'ERROR',
        '0',
        CAST(COUNT_IF(ds.student_key IS NULL) AS STRING),
        COUNT(*),
        COUNT(*) - COUNT_IF(ds.student_key IS NULL),
        COUNT_IF(ds.student_key IS NULL)
    FROM base b
    LEFT JOIN oulad.oulad_gold.dim_student ds
        ON b.student_key = ds.student_key
        AND b.course_key = ds.course_key

    UNION ALL

    -- BUSINESS RULE: course-site relationship
    SELECT
        'GOLD',
        'fact_vle_interaction',
        'course_key + site_key',
        'BUSINESS RULE',
        'Course-site relationship mismatch',
        'ERROR',
        '0',
        CAST(COUNT_IF(dv.site_key IS NULL) AS STRING),
        COUNT(*),
        COUNT(*) - COUNT_IF(dv.site_key IS NULL),
        COUNT_IF(dv.site_key IS NULL)
    FROM base b
    LEFT JOIN oulad.oulad_gold.dim_vle dv
        ON b.course_key = dv.course_key
        AND b.site_key = dv.site_key

    UNION ALL

    -- BUSINESS RULE: Gold processing timestamp
    SELECT
        'GOLD',
        'fact_vle_interaction',
        'gold_processed_timestamp',
        'BUSINESS RULE',
        'Missing Gold processing timestamp',
        'ERROR',
        '0',
        CAST(COUNT_IF(gold_processed_timestamp IS NULL) AS STRING),
        COUNT(*),
        COUNT(*) - COUNT_IF(gold_processed_timestamp IS NULL),
        COUNT_IF(gold_processed_timestamp IS NULL)
    FROM base

    UNION ALL

    -- BUSINESS RULE: Silver-to-Gold row count reconciliation
    SELECT
        'GOLD',
        'fact_vle_interaction',
        NULL,
        'BUSINESS RULE',
        'Silver-to-Gold row count reconciliation',
        'ERROR',
        CAST((SELECT COUNT(*) FROM expected) AS STRING),
        CAST((SELECT COUNT(*) FROM base) AS STRING),
        (SELECT COUNT(*) FROM expected),
        CASE
            WHEN (SELECT COUNT(*) FROM expected)
               = (SELECT COUNT(*) FROM base)
            THEN (SELECT COUNT(*) FROM expected)
            ELSE 0
        END,
        CASE
            WHEN (SELECT COUNT(*) FROM expected)
               = (SELECT COUNT(*) FROM base)
            THEN 0
            ELSE ABS(
                (SELECT COUNT(*) FROM expected)
                - (SELECT COUNT(*) FROM base)
            )
        END

    UNION ALL

    -- BUSINESS RULE: Silver-to-Gold click total reconciliation
    SELECT
        'GOLD',
        'fact_vle_interaction',
        'sum_click',
        'BUSINESS RULE',
        'Silver-to-Gold click total reconciliation',
        'ERROR',
        CAST((SELECT COALESCE(SUM(sum_click), 0) FROM expected) AS STRING),
        CAST((SELECT COALESCE(SUM(sum_click), 0) FROM base) AS STRING),
        (SELECT COUNT(*) FROM expected),
        CASE
            WHEN (SELECT COALESCE(SUM(sum_click), 0) FROM expected)
               = (SELECT COALESCE(SUM(sum_click), 0) FROM base)
            THEN (SELECT COUNT(*) FROM expected)
            ELSE 0
        END,
        CASE
            WHEN (SELECT COALESCE(SUM(sum_click), 0) FROM expected)
               = (SELECT COALESCE(SUM(sum_click), 0) FROM base)
            THEN 0
            ELSE 1
        END

    UNION ALL

    -- INFO: zero-click interaction records
    SELECT
        'GOLD',
        'fact_vle_interaction',
        'sum_click',
        'BUSINESS RULE',
        'Zero-click interaction records',
        'INFO',
        NULL,
        CAST(COUNT_IF(sum_click = 0) AS STRING),
        COUNT(*),
        COUNT_IF(sum_click != 0),
        COUNT_IF(sum_click = 0)
    FROM base

    UNION ALL

    -- VOLUME: actual Gold row count
    SELECT
        'GOLD',
        'fact_vle_interaction',
        NULL,
        'VOLUME',
        'Gold fact row count',
        'INFO',
        CAST((SELECT COUNT(*) FROM expected) AS STRING),
        CAST(COUNT(*) AS STRING),
        COUNT(*),
        COUNT(*),
        0
    FROM base
)

INSERT INTO oulad.oulad_quality.dq_results
SELECT
    UUID() AS run_id,
    CURRENT_TIMESTAMP AS run_timestamp,
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
    CASE
        WHEN total_records = 0 THEN 0
        ELSE ROUND(failed_records * 100.0 / total_records, 2)
    END AS failure_pct,
    CASE
        WHEN total_records = 0 THEN 100
        ELSE ROUND(passed_records * 100.0 / total_records, 2)
    END AS dq_score,
    CASE
        WHEN severity = 'INFO' THEN NULL
        WHEN failed_records = 0 THEN 'PASS'
        ELSE 'FAIL'
    END AS status
FROM checks;