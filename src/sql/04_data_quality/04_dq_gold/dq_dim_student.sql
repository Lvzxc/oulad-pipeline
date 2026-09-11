-- DIM_STUDENT GOLD DQ RESULTS

WITH run_info AS (
    SELECT
        uuid() AS run_id,
        current_timestamp() AS run_timestamp
),

base AS (
    SELECT *
    FROM oulad.oulad_gold.dim_student
),

expectations AS (
    SELECT COUNT(*) AS expected_row_count
    FROM oulad.oulad_silver.student_info_silver
),

checks AS (

    -- VOLUME
    SELECT
        'dim_student' AS table_name,
        'student_key' AS column_name,
        'VOLUME' AS dq_dimension,
        'Row count reconciliation' AS rule_name,
        'INFO' AS severity,
        CAST(e.expected_row_count AS STRING) AS expected_value,
        CAST(COUNT(*) AS STRING) AS actual_value,
        COUNT(*) AS total_records,
        COUNT(*) AS passed_records,
        ABS(COUNT(*) - e.expected_row_count) AS failed_records
    FROM base
    CROSS JOIN expectations e
    GROUP BY e.expected_row_count

    UNION ALL

    -- NULL: student_key
    SELECT
        'dim_student',
        'student_key',
        'NULL',
        'Missing student_key',
        'FAIL',
        '0',
        CAST(COUNT_IF(student_key IS NULL) AS STRING),
        COUNT(*),
        COUNT(*) - COUNT_IF(student_key IS NULL),
        COUNT_IF(student_key IS NULL)
    FROM base

    UNION ALL

    -- UNIQUE: student_key
    SELECT
        'dim_student',
        'student_key',
        'UNIQUE',
        'Duplicate student_key',
        'FAIL',
        '0',
        CAST(COUNT(*) - COUNT(DISTINCT student_key) AS STRING),
        COUNT(*),
        COUNT(DISTINCT student_key),
        COUNT(*) - COUNT(DISTINCT student_key)
    FROM base

    UNION ALL

    -- NULL: id_student
    SELECT
        'dim_student',
        'id_student',
        'NULL',
        'Missing id_student',
        'FAIL',
        '0',
        CAST(COUNT_IF(id_student IS NULL) AS STRING),
        COUNT(*),
        COUNT(*) - COUNT_IF(id_student IS NULL),
        COUNT_IF(id_student IS NULL)
    FROM base

    UNION ALL

    -- NULL: course_key
    SELECT
        'dim_student',
        'course_key',
        'NULL',
        'Missing course_key',
        'FAIL',
        '0',
        CAST(COUNT_IF(course_key IS NULL) AS STRING),
        COUNT(*),
        COUNT(*) - COUNT_IF(course_key IS NULL),
        COUNT_IF(course_key IS NULL)
    FROM base

    UNION ALL

    -- UNIQUE: student + course business key
    SELECT
        'dim_student',
        'id_student,course_key',
        'UNIQUE',
        'Duplicate student-course business key',
        'FAIL',
        '0',
        CAST(
            COUNT(*) - COUNT(
                DISTINCT CONCAT(
                    CAST(id_student AS STRING),
                    '|',
                    CAST(course_key AS STRING)
                )
            ) AS STRING
        ),
        COUNT(*),
        COUNT(
            DISTINCT CONCAT(
                CAST(id_student AS STRING),
                '|',
                CAST(course_key AS STRING)
            )
        ),
        COUNT(*) - COUNT(
            DISTINCT CONCAT(
                CAST(id_student AS STRING),
                '|',
                CAST(course_key AS STRING)
            )
        )
    FROM base

    UNION ALL

    -- BUSINESS: Silver lineage
    SELECT
        'dim_student',
        'silver_processed_timestamp',
        'BUSINESS',
        'Missing Silver processing timestamp',
        'FAIL',
        '0',
        CAST(
            COUNT_IF(silver_processed_timestamp IS NULL) AS STRING
        ),
        COUNT(*),
        COUNT(*) - COUNT_IF(silver_processed_timestamp IS NULL),
        COUNT_IF(silver_processed_timestamp IS NULL)
    FROM base

    UNION ALL

    -- BUSINESS: Gold lineage
    SELECT
        'dim_student',
        'gold_processed_timestamp',
        'BUSINESS',
        'Missing Gold processing timestamp',
        'FAIL',
        '0',
        CAST(
            COUNT_IF(gold_processed_timestamp IS NULL) AS STRING
        ),
        COUNT(*),
        COUNT(*) - COUNT_IF(gold_processed_timestamp IS NULL),
        COUNT_IF(gold_processed_timestamp IS NULL)
    FROM base
),

final_results AS (
    SELECT
        r.run_id,
        r.run_timestamp,
        'GOLD' AS layer,
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
            WHEN c.severity = 'INFO' THEN NULL
            WHEN c.failed_records = 0 THEN 100.0
            ELSE ROUND(
                c.passed_records * 100.0
                / NULLIF(c.total_records, 0),
                2
            )
        END AS dq_score,
        CASE
            WHEN c.severity = 'INFO' THEN NULL
            WHEN c.failed_records = 0 THEN 'PASS'
            ELSE 'FAIL'
        END AS status
    FROM checks c
    CROSS JOIN run_info r
)

INSERT INTO oulad.oulad_quality.dq_results
SELECT *
FROM final_results;