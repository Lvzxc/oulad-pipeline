-- ASSESSMENT BRONZE DATA QUALITY VALIDATION

WITH run_info AS (
    SELECT
        uuid() AS run_id,
        current_timestamp() AS run_timestamp
),

base AS (
    SELECT *
    FROM oulad.oulad_bronze.assessment_bronze
),

course_keys AS (
    SELECT DISTINCT
        TRIM(UPPER(code_module)) AS code_module,
        TRIM(UPPER(code_presentation)) AS code_presentation
    FROM oulad.oulad_bronze.courses_bronze
),

duplicate_assessment AS (
    SELECT
        id_assessment,
        code_module,
        code_presentation,
        COUNT(*) AS duplicate_count
    FROM base
    GROUP BY
        id_assessment,
        code_module,
        code_presentation
    HAVING COUNT(*) > 1
),

duplicate_exact AS (
    SELECT
        id_assessment,
        code_module,
        code_presentation,
        assessment_type,
        date,
        weight,
        COUNT(*) AS duplicate_count
    FROM base
    GROUP BY
        id_assessment,
        code_module,
        code_presentation,
        assessment_type,
        date,
        weight
    HAVING COUNT(*) > 1
),

conflicting_assessments AS (
    SELECT
        id_assessment
    FROM base
    GROUP BY id_assessment
    HAVING COUNT(
        DISTINCT CONCAT(
            COALESCE(code_module, ''),
            '|',
            COALESCE(code_presentation, ''),
            '|',
            COALESCE(assessment_type, ''),
            '|',
            COALESCE(CAST(date AS STRING), ''),
            '|',
            COALESCE(CAST(weight AS STRING), '')
        )
    ) > 1
),

table_count AS (
    SELECT COUNT(*) AS total_records
    FROM base
),

checks AS (

    -- Volume
    SELECT
        'assessment_bronze' AS table_name,
        'Row count' AS column_name,
        'VOLUME' AS dq_dimension,
        'Table should contain records' AS rule_name,
        'INFO' AS severity,
        CAST(tc.total_records AS STRING) AS expected_value,
        CAST(tc.total_records AS STRING) AS actual_value,
        tc.total_records,
        tc.total_records AS passed_records,
        0 AS failed_records,
        0.00 AS failure_pct,
        CAST(NULL AS DOUBLE) AS dq_score
    FROM table_count tc

    UNION ALL

    -- Required fields
    SELECT
        'assessment_bronze',
        'id_assessment',
        'NULL',
        'id_assessment is mandatory',
        'FAIL',
        '0% missing',
        CAST(COUNT_IF(id_assessment IS NULL) AS STRING),
        COUNT(*),
        COUNT(*) - COUNT_IF(id_assessment IS NULL),
        COUNT_IF(id_assessment IS NULL),
        ROUND(COUNT_IF(id_assessment IS NULL) * 100.0 / COUNT(*), 2),
        ROUND((COUNT(*) - COUNT_IF(id_assessment IS NULL)) * 100.0 / COUNT(*), 2)
    FROM base

    UNION ALL

    SELECT
        'assessment_bronze',
        'code_module',
        'NULL',
        'code_module is mandatory',
        'FAIL',
        '0% missing',
        CAST(COUNT_IF(code_module IS NULL) AS STRING),
        COUNT(*),
        COUNT(*) - COUNT_IF(code_module IS NULL),
        COUNT_IF(code_module IS NULL),
        ROUND(COUNT_IF(code_module IS NULL) * 100.0 / COUNT(*), 2),
        ROUND((COUNT(*) - COUNT_IF(code_module IS NULL)) * 100.0 / COUNT(*), 2)
    FROM base

    UNION ALL

    SELECT
        'assessment_bronze',
        'code_presentation',
        'NULL',
        'code_presentation is mandatory',
        'FAIL',
        '0% missing',
        CAST(COUNT_IF(code_presentation IS NULL) AS STRING),
        COUNT(*),
        COUNT(*) - COUNT_IF(code_presentation IS NULL),
        COUNT_IF(code_presentation IS NULL),
        ROUND(COUNT_IF(code_presentation IS NULL) * 100.0 / COUNT(*), 2),
        ROUND((COUNT(*) - COUNT_IF(code_presentation IS NULL)) * 100.0 / COUNT(*), 2)
    FROM base

    UNION ALL

    SELECT
        'assessment_bronze',
        'assessment_type',
        'NULL',
        'Assessment type should be populated',
        'FAIL',
        '0% missing',
        CAST(COUNT_IF(assessment_type IS NULL) AS STRING),
        COUNT(*),
        COUNT(*) - COUNT_IF(assessment_type IS NULL),
        COUNT_IF(assessment_type IS NULL),
        ROUND(COUNT_IF(assessment_type IS NULL) * 100.0 / COUNT(*), 2),
        ROUND((COUNT(*) - COUNT_IF(assessment_type IS NULL)) * 100.0 / COUNT(*), 2)
    FROM base

    UNION ALL

    SELECT
        'assessment_bronze',
        'weight',
        'NULL',
        'Weight should normally be populated',
        'FAIL',
        '0% missing',
        CAST(COUNT_IF(weight IS NULL) AS STRING),
        COUNT(*),
        COUNT(*) - COUNT_IF(weight IS NULL),
        COUNT_IF(weight IS NULL),
        ROUND(COUNT_IF(weight IS NULL) * 100.0 / COUNT(*), 2),
        ROUND((COUNT(*) - COUNT_IF(weight IS NULL)) * 100.0 / COUNT(*), 2)
    FROM base

    UNION ALL

    -- Uniqueness
    SELECT
        'assessment_bronze',
        'id_assessment + code_module + code_presentation',
        'UNIQUE',
        'Business key must be unique',
        'FAIL',
        '0 duplicate records',
        CAST(COALESCE(SUM(duplicate_count - 1), 0) AS STRING),
        tc.total_records,
        tc.total_records - COALESCE(SUM(duplicate_count - 1), 0),
        COALESCE(SUM(duplicate_count - 1), 0),
        ROUND(COALESCE(SUM(duplicate_count - 1), 0) * 100.0 / tc.total_records, 2),
        ROUND(
            (tc.total_records - COALESCE(SUM(duplicate_count - 1), 0))
            * 100.0 / tc.total_records,
            2
        )
    FROM table_count tc
    LEFT JOIN duplicate_assessment d ON TRUE
    GROUP BY tc.total_records

    UNION ALL

    SELECT
        'assessment_bronze',
        'Full assessment record',
        'UNIQUE',
        'Exact duplicate records should not exist',
        'FAIL',
        '0 duplicate records',
        CAST(COALESCE(SUM(duplicate_count - 1), 0) AS STRING),
        tc.total_records,
        tc.total_records - COALESCE(SUM(duplicate_count - 1), 0),
        COALESCE(SUM(duplicate_count - 1), 0),
        ROUND(COALESCE(SUM(duplicate_count - 1), 0) * 100.0 / tc.total_records, 2),
        ROUND(
            (tc.total_records - COALESCE(SUM(duplicate_count - 1), 0))
            * 100.0 / tc.total_records,
            2
        )
    FROM table_count tc
    LEFT JOIN duplicate_exact d ON TRUE
    GROUP BY tc.total_records

    UNION ALL

    -- Date format
    SELECT
        'assessment_bronze',
        'date',
        'TYPE / FORMAT',
        'Date must be numeric or ?',
        'FAIL',
        'Numeric value or ?',
        CAST(COUNT_IF(
            date IS NOT NULL
            AND date <> '?'
            AND TRY_CAST(date AS BIGINT) IS NULL
        ) AS STRING),
        COUNT(*),
        COUNT(*) - COUNT_IF(
            date IS NOT NULL
            AND date <> '?'
            AND TRY_CAST(date AS BIGINT) IS NULL
        ),
        COUNT_IF(
            date IS NOT NULL
            AND date <> '?'
            AND TRY_CAST(date AS BIGINT) IS NULL
        ),
        ROUND(
            COUNT_IF(
                date IS NOT NULL
                AND date <> '?'
                AND TRY_CAST(date AS BIGINT) IS NULL
            ) * 100.0 / COUNT(*),
            2
        ),
        ROUND(
            (
                COUNT(*) - COUNT_IF(
                    date IS NOT NULL
                    AND date <> '?'
                    AND TRY_CAST(date AS BIGINT) IS NULL
                )
            ) * 100.0 / COUNT(*),
            2
        )
    FROM base

    UNION ALL

    -- Weight format
    SELECT
        'assessment_bronze',
        'weight',
        'TYPE / FORMAT',
        'Weight must be numeric',
        'FAIL',
        'Numeric value',
        CAST(COUNT_IF(
            weight IS NOT NULL
            AND TRY_CAST(weight AS DOUBLE) IS NULL
        ) AS STRING),
        COUNT(*),
        COUNT(*) - COUNT_IF(
            weight IS NOT NULL
            AND TRY_CAST(weight AS DOUBLE) IS NULL
        ),
        COUNT_IF(
            weight IS NOT NULL
            AND TRY_CAST(weight AS DOUBLE) IS NULL
        ),
        ROUND(
            COUNT_IF(
                weight IS NOT NULL
                AND TRY_CAST(weight AS DOUBLE) IS NULL
            ) * 100.0 / COUNT(*),
            2
        ),
        ROUND(
            (
                COUNT(*) - COUNT_IF(
                    weight IS NOT NULL
                    AND TRY_CAST(weight AS DOUBLE) IS NULL
                )
            ) * 100.0 / COUNT(*),
            2
        )
    FROM base

    UNION ALL

    -- Weight range
    SELECT
        'assessment_bronze',
        'weight',
        'RANGE',
        'Weight must be between 0 and 100',
        'FAIL',
        '0 <= weight <= 100',
        CAST(COUNT_IF(
            TRY_CAST(weight AS DOUBLE) < 0
            OR TRY_CAST(weight AS DOUBLE) > 100
        ) AS STRING),
        COUNT(*),
        COUNT(*) - COUNT_IF(
            TRY_CAST(weight AS DOUBLE) < 0
            OR TRY_CAST(weight AS DOUBLE) > 100
        ),
        COUNT_IF(
            TRY_CAST(weight AS DOUBLE) < 0
            OR TRY_CAST(weight AS DOUBLE) > 100
        ),
        ROUND(
            COUNT_IF(
                TRY_CAST(weight AS DOUBLE) < 0
                OR TRY_CAST(weight AS DOUBLE) > 100
            ) * 100.0 / COUNT(*),
            2
        ),
        ROUND(
            (
                COUNT(*) - COUNT_IF(
                    TRY_CAST(weight AS DOUBLE) < 0
                    OR TRY_CAST(weight AS DOUBLE) > 100
                )
            ) * 100.0 / COUNT(*),
            2
        )
    FROM base

    UNION ALL

    -- Accepted assessment types
    SELECT
        'assessment_bronze',
        'assessment_type',
        'ACCEPTED VALUE',
        'Assessment type must be TMA, CMA, or Exam',
        'FAIL',
        'TMA, CMA, Exam',
        CAST(COUNT_IF(
            assessment_type IS NOT NULL
            AND TRIM(assessment_type) NOT IN ('TMA', 'CMA', 'Exam')
        ) AS STRING),
        COUNT(*),
        COUNT(*) - COUNT_IF(
            assessment_type IS NOT NULL
            AND TRIM(assessment_type) NOT IN ('TMA', 'CMA', 'Exam')
        ),
        COUNT_IF(
            assessment_type IS NOT NULL
            AND TRIM(assessment_type) NOT IN ('TMA', 'CMA', 'Exam')
        ),
        ROUND(
            COUNT_IF(
                assessment_type IS NOT NULL
                AND TRIM(assessment_type) NOT IN ('TMA', 'CMA', 'Exam')
            ) * 100.0 / COUNT(*),
            2
        ),
        ROUND(
            (
                COUNT(*) - COUNT_IF(
                    assessment_type IS NOT NULL
                    AND TRIM(assessment_type) NOT IN ('TMA', 'CMA', 'Exam')
                )
            ) * 100.0 / COUNT(*),
            2
        )
    FROM base

    UNION ALL

    -- Source sentinel
    SELECT
        'assessment_bronze',
        'date',
        'SOURCE SENTINEL',
        'Source may use ? for unavailable assessment date',
        'WARN',
        'No ? values required',
        CAST(COUNT_IF(TRIM(date) = '?') AS STRING),
        COUNT(*),
        COUNT(*) - COUNT_IF(TRIM(date) = '?'),
        COUNT_IF(TRIM(date) = '?'),
        ROUND(COUNT_IF(TRIM(date) = '?') * 100.0 / COUNT(*), 2),
        CAST(NULL AS DOUBLE)
    FROM base

    UNION ALL

    -- Course referential integrity
    SELECT
        'assessment_bronze',
        'code_module + code_presentation',
        'REFERENTIAL INTEGRITY',
        'Every assessment must match a course presentation',
        'FAIL',
        '0 unmatched assessments',
        CAST(COUNT_IF(
            a.code_module IS NOT NULL
            AND a.code_presentation IS NOT NULL
            AND c.code_module IS NULL
        ) AS STRING),
        COUNT(*),
        COUNT(*) - COUNT_IF(
            a.code_module IS NOT NULL
            AND a.code_presentation IS NOT NULL
            AND c.code_module IS NULL
        ),
        COUNT_IF(
            a.code_module IS NOT NULL
            AND a.code_presentation IS NOT NULL
            AND c.code_module IS NULL
        ),
        ROUND(
            COUNT_IF(
                a.code_module IS NOT NULL
                AND a.code_presentation IS NOT NULL
                AND c.code_module IS NULL
            ) * 100.0 / COUNT(*),
            2
        ),
        ROUND(
            (
                COUNT(*) - COUNT_IF(
                    a.code_module IS NOT NULL
                    AND a.code_presentation IS NOT NULL
                    AND c.code_module IS NULL
                )
            ) * 100.0 / COUNT(*),
            2
        )
    FROM base a
    LEFT JOIN course_keys c
        ON TRIM(UPPER(a.code_module)) = c.code_module
        AND TRIM(UPPER(a.code_presentation)) = c.code_presentation

    UNION ALL

    -- Business rule
    SELECT
        'assessment_bronze',
        'id_assessment',
        'BUSINESS RULE',
        'One id_assessment should represent one assessment definition',
        'FAIL',
        '0 conflicting assessment IDs',
        CAST(COUNT_IF(
            id_assessment IN (
                SELECT id_assessment
                FROM conflicting_assessments
            )
        ) AS STRING),
        COUNT(*),
        COUNT(*) - COUNT_IF(
            id_assessment IN (
                SELECT id_assessment
                FROM conflicting_assessments
            )
        ),
        COUNT_IF(
            id_assessment IN (
                SELECT id_assessment
                FROM conflicting_assessments
            )
        ),
        ROUND(
            COUNT_IF(
                id_assessment IN (
                    SELECT id_assessment
                    FROM conflicting_assessments
                )
            ) * 100.0 / COUNT(*),
            2
        ),
        ROUND(
            (
                COUNT(*) - COUNT_IF(
                    id_assessment IN (
                        SELECT id_assessment
                        FROM conflicting_assessments
                    )
                )
            ) * 100.0 / COUNT(*),
            2
        )
    FROM base
),

final_results AS (
    SELECT
        r.run_id,
        r.run_timestamp,
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
        c.failure_pct,
        c.dq_score,
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
SELECT
    run_id,
    run_timestamp,
    CASE
        WHEN table_name LIKE '%_bronze' THEN 'BRONZE'
        WHEN table_name LIKE '%_silver' THEN 'SILVER'
        WHEN table_name LIKE '%_gold' THEN 'GOLD'
        ELSE 'UNKNOWN'
    END AS layer,
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
FROM final_results;