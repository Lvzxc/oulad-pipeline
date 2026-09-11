-- STUDENT ASSESSMENT SILVER DATA QUALITY VALIDATION

WITH base AS (
    SELECT *
    FROM oulad.oulad_silver.student_assessment_silver
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
                WHEN CAST(score AS STRING) = '?' THEN 1
                ELSE 0
            END
        ) AS expected_null_scores
    FROM oulad.oulad_bronze.student_assessment_bronze
),

assessment_keys AS (
    SELECT DISTINCT
        id_assessment
    FROM oulad.oulad_silver.assessment_silver
    WHERE id_assessment IS NOT NULL
),

student_keys AS (
    SELECT DISTINCT
        id_student
    FROM oulad.oulad_silver.student_info_silver
    WHERE id_student IS NOT NULL
),

exact_duplicate_count AS (
    SELECT
        COALESCE(SUM(duplicate_count - 1), 0) AS duplicate_records
    FROM (
        SELECT
            id_assessment,
            id_student,
            date_submitted,
            score,
            is_banked,
            COUNT(*) AS duplicate_count
        FROM base
        GROUP BY
            id_assessment,
            id_student,
            date_submitted,
            score,
            is_banked
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
        'student_assessment_silver',
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

    -- Required key fields
    SELECT
        'student_assessment_silver',
        'id_assessment',
        'NULL',
        'Required id_assessment is not NULL',
        'FAIL',
        '0',
        CAST(COUNT_IF(id_assessment IS NULL) AS STRING),
        COUNT(*),
        COUNT(*) - COUNT_IF(id_assessment IS NULL),
        COUNT_IF(id_assessment IS NULL)
    FROM base

    UNION ALL

    SELECT
        'student_assessment_silver',
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

    -- Other required fields
    SELECT
        'student_assessment_silver',
        'date_submitted',
        'NULL',
        'date_submitted is not NULL',
        'FAIL',
        '0',
        CAST(COUNT_IF(date_submitted IS NULL) AS STRING),
        COUNT(*),
        COUNT(*) - COUNT_IF(date_submitted IS NULL),
        COUNT_IF(date_submitted IS NULL)
    FROM base

    UNION ALL

    SELECT
        'student_assessment_silver',
        'is_banked',
        'NULL',
        'is_banked is not NULL',
        'FAIL',
        '0',
        CAST(COUNT_IF(is_banked IS NULL) AS STRING),
        COUNT(*),
        COUNT(*) - COUNT_IF(is_banked IS NULL),
        COUNT_IF(is_banked IS NULL)
    FROM base

    UNION ALL

    -- Expected NULL scores originate from Bronze '?'
    SELECT
        'student_assessment_silver',
        'score',
        'NULL',
        'NULL scores match expected Bronze sentinel count',
        'WARN',
        CAST(e.expected_null_scores AS STRING),
        CAST(COUNT_IF(b.score IS NULL) AS STRING),
        COUNT(*),
        COUNT(*) - COUNT_IF(b.score IS NULL),
        COUNT_IF(b.score IS NULL)
    FROM base b
    CROSS JOIN bronze_expectations e
    GROUP BY e.expected_null_scores

    UNION ALL

    -- Business key uniqueness
    SELECT
        'student_assessment_silver',
        NULL,
        'UNIQUE',
        'Student-assessment business key is unique',
        'FAIL',
        '0 duplicate records',
        CAST(
            COUNT(*) - COUNT(DISTINCT STRUCT(id_assessment, id_student))
            AS STRING
        ),
        COUNT(*),
        COUNT(DISTINCT STRUCT(id_assessment, id_student)),
        COUNT(*) - COUNT(DISTINCT STRUCT(id_assessment, id_student))
    FROM base

    UNION ALL

    -- Exact duplicates
    SELECT
        'student_assessment_silver',
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
        'student_assessment_silver',
        'score',
        'SOURCE SENTINEL',
        'No unresolved sentinel (?) values remain in score',
        'FAIL',
        '0',
        CAST(COUNT_IF(CAST(score AS STRING) = '?') AS STRING),
        COUNT(*),
        COUNT(*) - COUNT_IF(CAST(score AS STRING) = '?'),
        COUNT_IF(CAST(score AS STRING) = '?')
    FROM base

    UNION ALL

    -- Score range
    SELECT
        'student_assessment_silver',
        'score',
        'RANGE',
        'Score is between 0 and 100',
        'FAIL',
        '0 invalid records',
        CAST(COUNT_IF(
            score IS NOT NULL
            AND (score < 0 OR score > 100)
        ) AS STRING),
        COUNT(*),
        COUNT(*) - COUNT_IF(
            score IS NOT NULL
            AND (score < 0 OR score > 100)
        ),
        COUNT_IF(
            score IS NOT NULL
            AND (score < 0 OR score > 100)
        )
    FROM base

    UNION ALL

    -- Accepted values for is_banked
    SELECT
        'student_assessment_silver',
        'is_banked',
        'ACCEPTED VALUE',
        'is_banked contains only 0 or 1',
        'FAIL',
        '0 or 1',
        CAST(COUNT_IF(
            is_banked IS NOT NULL
            AND is_banked NOT IN (0, 1)
        ) AS STRING),
        COUNT(*),
        COUNT(*) - COUNT_IF(
            is_banked IS NOT NULL
            AND is_banked NOT IN (0, 1)
        ),
        COUNT_IF(
            is_banked IS NOT NULL
            AND is_banked NOT IN (0, 1)
        )
    FROM base

    UNION ALL

    -- Assessment referential integrity
    SELECT
        'student_assessment_silver',
        'id_assessment',
        'REFERENTIAL INTEGRITY',
        'Every record references an existing assessment',
        'FAIL',
        '0 unmatched records',
        CAST(COUNT_IF(a.id_assessment IS NULL) AS STRING),
        COUNT(*),
        COUNT(*) - COUNT_IF(a.id_assessment IS NULL),
        COUNT_IF(a.id_assessment IS NULL)
    FROM base b
    LEFT JOIN assessment_keys a
        ON b.id_assessment = a.id_assessment

    UNION ALL

    -- Student referential integrity
    SELECT
        'student_assessment_silver',
        'id_student',
        'REFERENTIAL INTEGRITY',
        'Every record references an existing student',
        'FAIL',
        '0 unmatched records',
        CAST(COUNT_IF(s.id_student IS NULL) AS STRING),
        COUNT(*),
        COUNT(*) - COUNT_IF(s.id_student IS NULL),
        COUNT_IF(s.id_student IS NULL)
    FROM base b
    LEFT JOIN student_keys s
        ON b.id_student = s.id_student

    UNION ALL

    -- Bronze ingestion lineage
    SELECT
        'student_assessment_silver',
        'ingestion_timestamp',
        'LINEAGE',
        'Bronze ingestion timestamp is present',
        'FAIL',
        '0 missing records',
        CAST(COUNT_IF(ingestion_timestamp IS NULL) AS STRING),
        COUNT(*),
        COUNT(*) - COUNT_IF(ingestion_timestamp IS NULL),
        COUNT_IF(ingestion_timestamp IS NULL)
    FROM base

    UNION ALL

    -- Bronze ingestion date
    SELECT
        'student_assessment_silver',
        'ingestion_date',
        'LINEAGE',
        'Bronze ingestion date is present',
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