-- DIM_ASSESSMENT GOLD DATA QUALITY VALIDATION

WITH base AS (
    SELECT *
    FROM oulad.oulad_gold.dim_assessment
),

-- Expected values are derived from Silver to avoid hard-coded counts.
expectations AS (
    SELECT
        COUNT(*) AS silver_count,
        SUM(
            CASE
                WHEN date IS NULL
                     OR CAST(date AS STRING) = '?'
                THEN 1
                ELSE 0
            END
        ) AS expected_null_dates
    FROM oulad.oulad_silver.assessment_silver
),

dq_checks AS (

    -- VOLUME
    SELECT
        'dim_assessment' AS table_name,
        'Row count' AS rule_name,
        'VOLUME' AS dq_dimension,
        'INFO' AS severity,
        COUNT(*) AS total_records,
        COUNT(*) - ABS(COUNT(*) - e.silver_count) AS passed_records,
        ABS(COUNT(*) - e.silver_count) AS failed_records,
        CAST(e.silver_count AS STRING) AS expected_value,
        CAST(COUNT(*) AS STRING) AS actual_value
    FROM base
    CROSS JOIN expectations e
    GROUP BY e.silver_count

    UNION ALL

    -- NULL: assessment_key
    SELECT
        'dim_assessment',
        'Missing assessment_key',
        'NULL',
        'ERROR',
        COUNT(*),
        COUNT(*) - COUNT_IF(assessment_key IS NULL),
        COUNT_IF(assessment_key IS NULL),
        '0',
        CAST(COUNT_IF(assessment_key IS NULL) AS STRING)
    FROM base

    UNION ALL

    -- NULL: id_assessment
    SELECT
        'dim_assessment',
        'Missing id_assessment',
        'NULL',
        'ERROR',
        COUNT(*),
        COUNT(*) - COUNT_IF(id_assessment IS NULL),
        COUNT_IF(id_assessment IS NULL),
        '0',
        CAST(COUNT_IF(id_assessment IS NULL) AS STRING)
    FROM base

    UNION ALL

    -- NULL: course_key
    SELECT
        'dim_assessment',
        'Missing course_key',
        'NULL',
        'ERROR',
        COUNT(*),
        COUNT(*) - COUNT_IF(course_key IS NULL),
        COUNT_IF(course_key IS NULL),
        '0',
        CAST(COUNT_IF(course_key IS NULL) AS STRING)
    FROM base

    UNION ALL

    -- UNIQUE: assessment_key
    SELECT
        'dim_assessment',
        'Duplicate assessment_key',
        'UNIQUE',
        'ERROR',
        COUNT(*),
        COUNT(DISTINCT assessment_key),
        COUNT(*) - COUNT(DISTINCT assessment_key),
        '0',
        CAST(
            COUNT(*) - COUNT(DISTINCT assessment_key)
            AS STRING
        )
    FROM base

    UNION ALL

    -- UNIQUE: assessment business key
    SELECT
        'dim_assessment',
        'Duplicate assessment business key',
        'UNIQUE',
        'ERROR',
        COUNT(*),
        COUNT(DISTINCT CONCAT(
            id_assessment,
            '|',
            code_module,
            '|',
            code_presentation
        )),
        COUNT(*) - COUNT(DISTINCT CONCAT(
            id_assessment,
            '|',
            code_module,
            '|',
            code_presentation
        )),
        '0',
        CAST(
            COUNT(*) - COUNT(DISTINCT CONCAT(
                id_assessment,
                '|',
                code_module,
                '|',
                code_presentation
            ))
            AS STRING
        )
    FROM base

    UNION ALL

    -- RANGE: assessment date
    SELECT
        'dim_assessment',
        'Invalid assessment date range',
        'RANGE',
        'ERROR',
        COUNT(*),
        COUNT(*) - COUNT_IF(
            assessment_date IS NOT NULL
            AND (
                assessment_date < 0
                OR assessment_date > 300
            )
        ),
        COUNT_IF(
            assessment_date IS NOT NULL
            AND (
                assessment_date < 0
                OR assessment_date > 300
            )
        ),
        '0-300',
        CAST(
            COUNT_IF(
                assessment_date IS NOT NULL
                AND (
                    assessment_date < 0
                    OR assessment_date > 300
                )
            )
            AS STRING
        )
    FROM base

    UNION ALL

    -- RANGE: assessment weight
    SELECT
        'dim_assessment',
        'Invalid weight range',
        'RANGE',
        'ERROR',
        COUNT(*),
        COUNT(*) - COUNT_IF(
            weight IS NULL
            OR weight < 0
            OR weight > 100
        ),
        COUNT_IF(
            weight IS NULL
            OR weight < 0
            OR weight > 100
        ),
        '0-100',
        CAST(
            COUNT_IF(
                weight IS NULL
                OR weight < 0
                OR weight > 100
            )
            AS STRING
        )
    FROM base

    UNION ALL

    -- ACCEPTED VALUE: assessment type
    SELECT
        'dim_assessment',
        'Invalid assessment_type',
        'ACCEPTED VALUE',
        'ERROR',
        COUNT(*),
        COUNT(*) - COUNT_IF(
            assessment_type IS NULL
            OR assessment_type NOT IN ('TMA', 'CMA', 'Exam')
        ),
        COUNT_IF(
            assessment_type IS NULL
            OR assessment_type NOT IN ('TMA', 'CMA', 'Exam')
        ),
        'TMA, CMA, Exam',
        CAST(
            COUNT_IF(
                assessment_type IS NULL
                OR assessment_type NOT IN ('TMA', 'CMA', 'Exam')
            )
            AS STRING
        )
    FROM base

    UNION ALL

    -- NULL: assessment date
    -- Missing dates are expected when Silver contains source '?' values.
    SELECT
        'dim_assessment',
        'Missing assessment date',
        'NULL',
        'INFO',
        COUNT(*),
        COUNT(*) - COUNT_IF(assessment_date IS NULL),
        COUNT_IF(assessment_date IS NULL),
        CAST(e.expected_null_dates AS STRING),
        CAST(COUNT_IF(assessment_date IS NULL) AS STRING)
    FROM base
    CROSS JOIN expectations e
    GROUP BY e.expected_null_dates

    UNION ALL

    -- REFERENTIAL INTEGRITY: course
    SELECT
        'dim_assessment',
        'Assessment without matching course',
        'REFERENTIAL INTEGRITY',
        'ERROR',
        COUNT(*),
        COUNT(*) - COUNT_IF(dc.course_key IS NULL),
        COUNT_IF(dc.course_key IS NULL),
        '0',
        CAST(COUNT_IF(dc.course_key IS NULL) AS STRING)
    FROM base a
    LEFT JOIN oulad.oulad_gold.dim_course dc
        ON a.course_key = dc.course_key

    UNION ALL

    -- BUSINESS RULE: assessment must match its Silver course
    SELECT
        'dim_assessment',
        'Assessment-course relationship mismatch',
        'BUSINESS RULE',
        'ERROR',
        COUNT(*),
        COUNT(*) - COUNT_IF(s.id_assessment IS NULL),
        COUNT_IF(s.id_assessment IS NULL),
        '0',
        CAST(COUNT_IF(s.id_assessment IS NULL) AS STRING)
    FROM base a
    LEFT JOIN oulad.oulad_silver.assessment_silver s
        ON a.id_assessment = s.id_assessment
        AND a.code_module = s.code_module
        AND a.code_presentation = s.code_presentation

    UNION ALL

    -- BUSINESS RULE: Gold processing timestamp
    SELECT
        'dim_assessment',
        'Missing Gold processing timestamp',
        'BUSINESS RULE',
        'ERROR',
        COUNT(*),
        COUNT(*) - COUNT_IF(gold_processed_timestamp IS NULL),
        COUNT_IF(gold_processed_timestamp IS NULL),
        '0',
        CAST(COUNT_IF(gold_processed_timestamp IS NULL) AS STRING)
    FROM base

    UNION ALL

    -- BUSINESS RULE: Silver processing timestamp
    SELECT
        'dim_assessment',
        'Missing Silver processing timestamp',
        'BUSINESS RULE',
        'ERROR',
        COUNT(*),
        COUNT(*) - COUNT_IF(silver_processed_timestamp IS NULL),
        COUNT_IF(silver_processed_timestamp IS NULL),
        '0',
        CAST(COUNT_IF(silver_processed_timestamp IS NULL) AS STRING)
    FROM base

    UNION ALL

    -- BUSINESS RULE: Gold row count must reconcile with Silver.
    SELECT
        'dim_assessment',
        'Silver-to-Gold row count reconciliation',
        'BUSINESS RULE',
        'ERROR',
        e.silver_count,
        CASE
            WHEN COUNT(*) = e.silver_count THEN e.silver_count
            ELSE LEAST(COUNT(*), e.silver_count)
        END,
        ABS(COUNT(*) - e.silver_count),
        CAST(e.silver_count AS STRING),
        CAST(COUNT(*) AS STRING)
    FROM base
    CROSS JOIN expectations e
    GROUP BY e.silver_count
),

measured AS (
    SELECT
        table_name,
        rule_name,
        dq_dimension,
        severity,
        total_records,
        passed_records,
        failed_records,
        expected_value,
        actual_value,
        ROUND(
            failed_records * 100.0
            / NULLIF(total_records, 0),
            2
        ) AS failure_pct
    FROM dq_checks
),

evaluated AS (
    SELECT
        table_name,
        rule_name,
        dq_dimension,
        severity,
        expected_value,
        actual_value,
        total_records,
        passed_records,
        failed_records,
        failure_pct,

        CASE
            -- Informational checks do not determine pass/fail.
            WHEN severity = 'INFO'
                THEN NULL

            -- Expected assessment-date NULLs pass when
            -- Gold matches the Silver source expectation.
            WHEN rule_name = 'Missing assessment date'
                 AND actual_value = expected_value
                THEN 'PASS'

            -- No failures.
            WHEN failed_records = 0
                THEN 'PASS'

            -- Structural and business checks fail
            -- whenever an unexpected failure exists.
            ELSE 'FAIL'
        END AS status,

        CASE
            WHEN severity = 'INFO'
                THEN NULL
            WHEN failed_records = 0
                THEN 100.0
            ELSE ROUND(
                passed_records * 100.0
                / NULLIF(total_records, 0),
                2
            )
        END AS dq_score

    FROM measured
)

INSERT INTO oulad.oulad_quality.dq_results (
    run_id,
    run_timestamp,
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
    failure_pct,
    dq_score,
    status
)

SELECT
    uuid() AS run_id,
    CURRENT_TIMESTAMP AS run_timestamp,
    'GOLD' AS layer,
    table_name,

    CASE
        WHEN rule_name LIKE '%assessment_key%' THEN 'assessment_key'
        WHEN rule_name LIKE '%id_assessment%' THEN 'id_assessment'
        WHEN rule_name LIKE '%course%' THEN 'course_key'
        WHEN rule_name LIKE '%assessment date%' THEN 'assessment_date'
        WHEN rule_name LIKE '%weight%' THEN 'weight'
        WHEN rule_name LIKE '%assessment_type%' THEN 'assessment_type'
        WHEN rule_name LIKE '%Silver%' THEN NULL
        WHEN rule_name LIKE '%Gold%' THEN NULL
        WHEN rule_name LIKE '%Row count%' THEN NULL
        ELSE NULL
    END AS column_name,

    dq_dimension,
    rule_name,
    severity,
    expected_value,
    actual_value,
    total_records,
    passed_records,
    failed_records,
    failure_pct,
    dq_score,
    status
FROM evaluated;