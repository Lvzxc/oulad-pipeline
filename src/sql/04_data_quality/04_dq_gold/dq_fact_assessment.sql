-- GOLD DQ: FACT ASSESSMENT

WITH base AS (
    SELECT *
    FROM oulad.oulad_gold.fact_assessment
),

-- Expected Gold records from Silver
expected AS (
    SELECT
        sa.id_student,
        sa.id_assessment,
        sa.score,
        sa.is_banked,
        da.course_key,
        dd.date_key
    FROM oulad.oulad_silver.student_assessment_silver sa
    JOIN oulad.oulad_gold.dim_assessment da
        ON sa.id_assessment = da.id_assessment
    JOIN oulad.oulad_gold.dim_student ds
        ON sa.id_student = ds.id_student
        AND da.code_module = ds.code_module
        AND da.code_presentation = ds.code_presentation
    JOIN oulad.oulad_gold.dim_date dd
        ON sa.date_submitted = dd.relative_day
),

checks AS (

    -- NULL: student_key
    SELECT
        'NULL' AS dq_dimension,
        'Missing student_key' AS rule_name,
        'student_key' AS column_name,
        COUNT(*) AS total_records,
        COUNT_IF(student_key IS NULL) AS failed_records,
        '0 missing' AS expected_value,
        CAST(COUNT_IF(student_key IS NULL) AS STRING) AS actual_value
    FROM base

    UNION ALL

    -- NULL: course_key
    SELECT
        'NULL',
        'Missing course_key',
        'course_key',
        COUNT(*),
        COUNT_IF(course_key IS NULL),
        '0 missing',
        CAST(COUNT_IF(course_key IS NULL) AS STRING)
    FROM base

    UNION ALL

    -- NULL: assessment_key
    SELECT
        'NULL',
        'Missing assessment_key',
        'assessment_key',
        COUNT(*),
        COUNT_IF(assessment_key IS NULL),
        '0 missing',
        CAST(COUNT_IF(assessment_key IS NULL) AS STRING)
    FROM base

    UNION ALL

    -- NULL: date_key
    SELECT
        'NULL',
        'Missing date_key',
        'date_key',
        COUNT(*),
        COUNT_IF(date_key IS NULL),
        '0 missing',
        CAST(COUNT_IF(date_key IS NULL) AS STRING)
    FROM base

    UNION ALL

    -- UNIQUE: declared fact grain
    SELECT
        'UNIQUE',
        'Duplicate fact grain',
        NULL,
        COUNT(*),
        COUNT(*) - COUNT(DISTINCT
            CONCAT_WS(
                '|',
                CAST(student_key AS STRING),
                CAST(assessment_key AS STRING)
            )
        ),
        '0 duplicate records',
        CAST(
            COUNT(*) - COUNT(DISTINCT
                CONCAT_WS(
                    '|',
                    CAST(student_key AS STRING),
                    CAST(assessment_key AS STRING)
                )
            ) AS STRING
        )
    FROM base

    UNION ALL

    -- RANGE: score
    SELECT
        'RANGE',
        'Score outside valid range',
        'score',
        COUNT(*),
        COUNT_IF(
            score IS NOT NULL
            AND (score < 0 OR score > 100)
        ),
        '0 invalid scores; valid range 0-100',
        CAST(
            COUNT_IF(
                score IS NOT NULL
                AND (score < 0 OR score > 100)
            ) AS STRING
        )
    FROM base

    UNION ALL

    -- ACCEPTED VALUE: is_banked
    SELECT
        'ACCEPTED VALUE',
        'Invalid is_banked value',
        'is_banked',
        COUNT(*),
        COUNT_IF(
            is_banked IS NOT NULL
            AND is_banked NOT IN (0, 1)
        ),
        'Only 0 or 1',
        CAST(
            COUNT_IF(
                is_banked IS NOT NULL
                AND is_banked NOT IN (0, 1)
            ) AS STRING
        )
    FROM base

    UNION ALL

    -- REFERENTIAL INTEGRITY: student
    SELECT
        'REFERENTIAL INTEGRITY',
        'Student key does not resolve',
        'student_key',
        COUNT(*),
        COUNT_IF(ds.student_key IS NULL),
        '0 unresolved student keys',
        CAST(COUNT_IF(ds.student_key IS NULL) AS STRING)
    FROM base b
    LEFT JOIN oulad.oulad_gold.dim_student ds
        ON b.student_key = ds.student_key

    UNION ALL

    -- REFERENTIAL INTEGRITY: assessment
    SELECT
        'REFERENTIAL INTEGRITY',
        'Assessment key does not resolve',
        'assessment_key',
        COUNT(*),
        COUNT_IF(da.assessment_key IS NULL),
        '0 unresolved assessment keys',
        CAST(COUNT_IF(da.assessment_key IS NULL) AS STRING)
    FROM base b
    LEFT JOIN oulad.oulad_gold.dim_assessment da
        ON b.assessment_key = da.assessment_key

    UNION ALL

    -- REFERENTIAL INTEGRITY: date
    SELECT
        'REFERENTIAL INTEGRITY',
        'Date key does not resolve',
        'date_key',
        COUNT(*),
        COUNT_IF(dd.date_key IS NULL),
        '0 unresolved date keys',
        CAST(COUNT_IF(dd.date_key IS NULL) AS STRING)
    FROM base b
    LEFT JOIN oulad.oulad_gold.dim_date dd
        ON b.date_key = dd.date_key

    UNION ALL

    -- BUSINESS RULE: student and course must agree
    SELECT
        'BUSINESS RULE',
        'Student-course relationship mismatch',
        NULL,
        COUNT(*),
        COUNT_IF(
            ds.course_key IS NULL
            OR ds.course_key <> b.course_key
        ),
        '0 mismatched student-course relationships',
        CAST(
            COUNT_IF(
                ds.course_key IS NULL
                OR ds.course_key <> b.course_key
            ) AS STRING
        )
    FROM base b
    LEFT JOIN oulad.oulad_gold.dim_student ds
        ON b.student_key = ds.student_key

    UNION ALL

    -- BUSINESS RULE: Gold processing timestamp
    SELECT
        'BUSINESS RULE',
        'Missing Gold processing timestamp',
        'gold_processed_timestamp',
        COUNT(*),
        COUNT_IF(gold_processed_timestamp IS NULL),
        '0 missing timestamps',
        CAST(COUNT_IF(gold_processed_timestamp IS NULL) AS STRING)
    FROM base

    UNION ALL

    -- BUSINESS RULE: Silver-to-Gold row reconciliation
    SELECT
        'BUSINESS RULE',
        'Silver-to-Gold row count mismatch',
        NULL,
        (SELECT COUNT(*) FROM expected),
        ABS(
            (SELECT COUNT(*) FROM expected)
            - (SELECT COUNT(*) FROM base)
        ),
        CAST((SELECT COUNT(*) FROM expected) AS STRING),
        CAST((SELECT COUNT(*) FROM base) AS STRING)

    UNION ALL

    -- BUSINESS RULE: Silver-to-Gold score reconciliation
    SELECT
        'BUSINESS RULE',
        'Silver-to-Gold score total mismatch',
        'score',
        (SELECT COUNT(*) FROM expected WHERE score IS NOT NULL),
        CASE
            WHEN COALESCE((SELECT SUM(score) FROM expected), 0)
               = COALESCE((SELECT SUM(score) FROM base), 0)
            THEN 0
            ELSE 1
        END,
        CAST(
            COALESCE((SELECT SUM(score) FROM expected), 0)
            AS STRING
        ),
        CAST(
            COALESCE((SELECT SUM(score) FROM base), 0)
            AS STRING
        )

    UNION ALL

    -- BUSINESS RULE: informational measure
    SELECT
        'BUSINESS RULE',
        'Missing assessment scores',
        'score',
        COUNT(*),
        COUNT_IF(score IS NULL),
        'Informational measure',
        CAST(COUNT_IF(score IS NULL) AS STRING)
    FROM base

    UNION ALL

    -- BUSINESS RULE: informational measure
    SELECT
        'BUSINESS RULE',
        'Banked assessment records',
        'is_banked',
        COUNT(*),
        COUNT_IF(is_banked = 1),
        'Informational measure',
        CAST(COUNT_IF(is_banked = 1) AS STRING)
    FROM base

    UNION ALL

    -- VOLUME: actual Gold row count
    SELECT
        'VOLUME',
        'Gold fact row count',
        NULL,
        COUNT(*),
        0,
        CAST((SELECT COUNT(*) FROM expected) AS STRING),
        CAST(COUNT(*) AS STRING)
    FROM base
),

run_context AS (
    SELECT
        UUID() AS run_id,
        CURRENT_TIMESTAMP AS run_timestamp
),

measured AS (
    SELECT
        *,
        ROUND(
            failed_records * 100.0
            / NULLIF(total_records, 0),
            2
        ) AS failure_pct,

        ROUND(
            100.0 -
            (
                failed_records * 100.0
                / NULLIF(total_records, 0)
            ),
            2
        ) AS dq_score
    FROM checks
)

INSERT INTO oulad.oulad_quality.dq_results
SELECT
    r.run_id,
    r.run_timestamp,
    'GOLD' AS layer,
    'fact_assessment' AS table_name,
    m.column_name,
    m.dq_dimension,
    m.rule_name,

    CASE
        WHEN m.dq_dimension = 'VOLUME' THEN 'INFO'
        WHEN m.rule_name IN (
            'Missing assessment scores',
            'Banked assessment records'
        ) THEN 'INFO'
        ELSE 'ERROR'
    END AS severity,

    m.expected_value,
    m.actual_value,
    m.total_records,
    m.total_records - m.failed_records AS passed_records,
    m.failed_records,
    m.failure_pct,
    m.dq_score,

    CASE
        WHEN m.dq_dimension = 'VOLUME' THEN NULL

        WHEN m.rule_name IN (
            'Missing assessment scores',
            'Banked assessment records'
        ) THEN NULL

        WHEN m.failed_records = 0 THEN 'PASS'

        ELSE 'FAIL'
    END AS status

FROM measured m
CROSS JOIN run_context r;