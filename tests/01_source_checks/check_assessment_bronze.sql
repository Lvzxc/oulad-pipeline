-- ASSESSMENT BRONZE DATA QUALITY VALIDATION

WITH duplicate_assessment AS (
    -- Identify duplicate assessment business keys
    SELECT
        id_assessment,
        code_module,
        code_presentation,
        COUNT(*) AS duplicate_count
    FROM oulad.oulad_bronze.assessment_bronze
    GROUP BY
        id_assessment,
        code_module,
        code_presentation
    HAVING COUNT(*) > 1
),

duplicate_exact AS (
    -- Identify exact duplicate records
    SELECT
        id_assessment,
        code_module,
        code_presentation,
        assessment_type,
        date,
        weight,
        COUNT(*) AS duplicate_count
    FROM oulad.oulad_bronze.assessment_bronze
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
    -- Identify assessment IDs associated with conflicting definitions
    SELECT
        id_assessment
    FROM oulad.oulad_bronze.assessment_bronze
    GROUP BY
        id_assessment
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

validation_results AS (

    -- Volume check
    SELECT
        'assessment_bronze' AS table_name,
        'Row count' AS check_name,
        'VOLUME' AS dq_category,
        COUNT(*) AS total_rows,
        0 AS failed_rows,
        0.00 AS failure_pct,
        'Table should contain records' AS expected_value,
        CASE
            WHEN COUNT(*) > 0 THEN 'PASS'
            ELSE 'FAIL'
        END AS status
    FROM oulad.oulad_bronze.assessment_bronze

    UNION ALL

    -- NULL checks
    SELECT
        'assessment_bronze',
        'Missing id_assessment',
        'NULL',
        COUNT(*),
        COUNT_IF(id_assessment IS NULL),
        ROUND(COUNT_IF(id_assessment IS NULL) * 100.0 / COUNT(*), 2),
        '0% missing; mandatory key',
        CASE
            WHEN COUNT_IF(id_assessment IS NULL) = 0 THEN 'PASS'
            ELSE 'FAIL'
        END
    FROM oulad.oulad_bronze.assessment_bronze

    UNION ALL

    SELECT
        'assessment_bronze',
        'Missing code_module',
        'NULL',
        COUNT(*),
        COUNT_IF(code_module IS NULL),
        ROUND(COUNT_IF(code_module IS NULL) * 100.0 / COUNT(*), 2),
        '0% missing; mandatory key',
        CASE
            WHEN COUNT_IF(code_module IS NULL) = 0 THEN 'PASS'
            ELSE 'FAIL'
        END
    FROM oulad.oulad_bronze.assessment_bronze

    UNION ALL

    SELECT
        'assessment_bronze',
        'Missing code_presentation',
        'NULL',
        COUNT(*),
        COUNT_IF(code_presentation IS NULL),
        ROUND(COUNT_IF(code_presentation IS NULL) * 100.0 / COUNT(*), 2),
        '0% missing; mandatory key',
        CASE
            WHEN COUNT_IF(code_presentation IS NULL) = 0 THEN 'PASS'
            ELSE 'FAIL'
        END
    FROM oulad.oulad_bronze.assessment_bronze

    UNION ALL

    SELECT
        'assessment_bronze',
        'Missing assessment_type',
        'NULL',
        COUNT(*),
        COUNT_IF(assessment_type IS NULL),
        ROUND(COUNT_IF(assessment_type IS NULL) * 100.0 / COUNT(*), 2),
        'Assessment type should be populated',
        CASE
            WHEN COUNT_IF(assessment_type IS NULL) = 0 THEN 'PASS'
            WHEN COUNT_IF(assessment_type IS NULL) * 100.0 / COUNT(*) <= 1 THEN 'WARN'
            ELSE 'FAIL'
        END
    FROM oulad.oulad_bronze.assessment_bronze

    UNION ALL

    SELECT
        'assessment_bronze',
        'Missing date',
        'NULL',
        COUNT(*),
        COUNT_IF(date IS NULL),
        ROUND(COUNT_IF(date IS NULL) * 100.0 / COUNT(*), 2),
        'Missing date may be retained',
        CASE
            WHEN COUNT_IF(date IS NULL) = 0 THEN 'PASS'
            WHEN COUNT_IF(date IS NULL) * 100.0 / COUNT(*) <= 1 THEN 'WARN'
            ELSE 'FAIL'
        END
    FROM oulad.oulad_bronze.assessment_bronze

    UNION ALL

    SELECT
        'assessment_bronze',
        'Missing weight',
        'NULL',
        COUNT(*),
        COUNT_IF(weight IS NULL),
        ROUND(COUNT_IF(weight IS NULL) * 100.0 / COUNT(*), 2),
        'Weight should normally be populated',
        CASE
            WHEN COUNT_IF(weight IS NULL) = 0 THEN 'PASS'
            WHEN COUNT_IF(weight IS NULL) * 100.0 / COUNT(*) <= 1 THEN 'WARN'
            ELSE 'FAIL'
        END
    FROM oulad.oulad_bronze.assessment_bronze

    UNION ALL

    -- Uniqueness checks
    SELECT
        'assessment_bronze',
        'Duplicate assessment business key',
        'UNIQUE',
        COUNT(*),
        COALESCE(
            (SELECT SUM(duplicate_count - 1) FROM duplicate_assessment),
            0
        ),
        ROUND(
            COALESCE(
                (SELECT SUM(duplicate_count - 1) FROM duplicate_assessment),
                0
            ) * 100.0 / COUNT(*),
            2
        ),
        '0% duplicate id_assessment + module + presentation',
        CASE
            WHEN COALESCE(
                (SELECT SUM(duplicate_count - 1) FROM duplicate_assessment),
                0
            ) = 0 THEN 'PASS'
            WHEN COALESCE(
                (SELECT SUM(duplicate_count - 1) FROM duplicate_assessment),
                0
            ) * 100.0 / COUNT(*) <= 1 THEN 'WARN'
            ELSE 'FAIL'
        END
    FROM oulad.oulad_bronze.assessment_bronze

    UNION ALL

    SELECT
        'assessment_bronze',
        'Exact duplicate records',
        'UNIQUE',
        COUNT(*),
        COALESCE(
            (SELECT SUM(duplicate_count - 1) FROM duplicate_exact),
            0
        ),
        ROUND(
            COALESCE(
                (SELECT SUM(duplicate_count - 1) FROM duplicate_exact),
                0
            ) * 100.0 / COUNT(*),
            2
        ),
        '0% duplicate records',
        CASE
            WHEN COALESCE(
                (SELECT SUM(duplicate_count - 1) FROM duplicate_exact),
                0
            ) = 0 THEN 'PASS'
            WHEN COALESCE(
                (SELECT SUM(duplicate_count - 1) FROM duplicate_exact),
                0
            ) * 100.0 / COUNT(*) <= 1 THEN 'WARN'
            ELSE 'FAIL'
        END
    FROM oulad.oulad_bronze.assessment_bronze

    UNION ALL

    -- Type and format checks
    SELECT
        'assessment_bronze',
        'Invalid id_assessment format',
        'TYPE / FORMAT',
        COUNT(*),
        COUNT_IF(
            id_assessment IS NOT NULL
            AND TRY_CAST(id_assessment AS BIGINT) IS NULL
        ),
        ROUND(
            COUNT_IF(
                id_assessment IS NOT NULL
                AND TRY_CAST(id_assessment AS BIGINT) IS NULL
            ) * 100.0 / COUNT(*),
            2
        ),
        'id_assessment must be numeric',
        CASE
            WHEN COUNT_IF(
                id_assessment IS NOT NULL
                AND TRY_CAST(id_assessment AS BIGINT) IS NULL
            ) = 0 THEN 'PASS'
            WHEN COUNT_IF(
                id_assessment IS NOT NULL
                AND TRY_CAST(id_assessment AS BIGINT) IS NULL
            ) * 100.0 / COUNT(*) <= 1 THEN 'WARN'
            ELSE 'FAIL'
        END
    FROM oulad.oulad_bronze.assessment_bronze

    UNION ALL

    SELECT
        'assessment_bronze',
        'Invalid date format',
        'TYPE / FORMAT',
        COUNT(*),
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
        'Date must be numeric or ?',
        CASE
            WHEN COUNT_IF(
                date IS NOT NULL
                AND date <> '?'
                AND TRY_CAST(date AS BIGINT) IS NULL
            ) = 0 THEN 'PASS'
            WHEN COUNT_IF(
                date IS NOT NULL
                AND date <> '?'
                AND TRY_CAST(date AS BIGINT) IS NULL
            ) * 100.0 / COUNT(*) <= 1 THEN 'WARN'
            ELSE 'FAIL'
        END
    FROM oulad.oulad_bronze.assessment_bronze

    UNION ALL

    SELECT
        'assessment_bronze',
        'Invalid weight format',
        'TYPE / FORMAT',
        COUNT(*),
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
        'Weight must be numeric',
        CASE
            WHEN COUNT_IF(
                weight IS NOT NULL
                AND TRY_CAST(weight AS DOUBLE) IS NULL
            ) = 0 THEN 'PASS'
            WHEN COUNT_IF(
                weight IS NOT NULL
                AND TRY_CAST(weight AS DOUBLE) IS NULL
            ) * 100.0 / COUNT(*) <= 1 THEN 'WARN'
            ELSE 'FAIL'
        END
    FROM oulad.oulad_bronze.assessment_bronze

    UNION ALL

    -- Range check
    SELECT
        'assessment_bronze',
        'Weight outside valid range',
        'RANGE',
        COUNT(*),
        COUNT_IF(
            weight IS NOT NULL
            AND TRY_CAST(weight AS DOUBLE) IS NOT NULL
            AND (
                TRY_CAST(weight AS DOUBLE) < 0
                OR TRY_CAST(weight AS DOUBLE) > 100
            )
        ),
        ROUND(
            COUNT_IF(
                weight IS NOT NULL
                AND TRY_CAST(weight AS DOUBLE) IS NOT NULL
                AND (
                    TRY_CAST(weight AS DOUBLE) < 0
                    OR TRY_CAST(weight AS DOUBLE) > 100
                )
            ) * 100.0 / COUNT(*),
            2
        ),
        '0 <= weight <= 100',
        CASE
            WHEN COUNT_IF(
                weight IS NOT NULL
                AND TRY_CAST(weight AS DOUBLE) IS NOT NULL
                AND (
                    TRY_CAST(weight AS DOUBLE) < 0
                    OR TRY_CAST(weight AS DOUBLE) > 100
                )
            ) = 0 THEN 'PASS'
            WHEN COUNT_IF(
                weight IS NOT NULL
                AND TRY_CAST(weight AS DOUBLE) IS NOT NULL
                AND (
                    TRY_CAST(weight AS DOUBLE) < 0
                    OR TRY_CAST(weight AS DOUBLE) > 100
                )
            ) * 100.0 / COUNT(*) <= 1 THEN 'WARN'
            ELSE 'FAIL'
        END
    FROM oulad.oulad_bronze.assessment_bronze

    UNION ALL

    -- Accepted value check
    SELECT
        'assessment_bronze',
        'Invalid assessment_type',
        'ACCEPTED VALUE',
        COUNT(*),
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
        'TMA, CMA, Exam',
        CASE
            WHEN COUNT_IF(
                assessment_type IS NOT NULL
                AND TRIM(assessment_type) NOT IN ('TMA', 'CMA', 'Exam')
            ) = 0 THEN 'PASS'
            WHEN COUNT_IF(
                assessment_type IS NOT NULL
                AND TRIM(assessment_type) NOT IN ('TMA', 'CMA', 'Exam')
            ) * 100.0 / COUNT(*) <= 1 THEN 'WARN'
            ELSE 'FAIL'
        END
    FROM oulad.oulad_bronze.assessment_bronze

    UNION ALL

    -- Source sentinel check
    SELECT
        'assessment_bronze',
        'Source sentinel (?) in date',
        'SENTINEL',
        COUNT(*),
        COUNT_IF(date = '?'),
        ROUND(COUNT_IF(date = '?') * 100.0 / COUNT(*), 2),
        'Source may use ? for unavailable assessment date',
        CASE
            WHEN COUNT_IF(date = '?') = 0 THEN 'PASS'
            ELSE 'WARN'
        END
    FROM oulad.oulad_bronze.assessment_bronze

    UNION ALL

    -- Foreign key check
    SELECT
        'assessment_bronze',
        'Assessment without matching course',
        'FOREIGN KEY',
        COUNT(*),
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
        'Every assessment should match code_module + code_presentation',
        CASE
            WHEN COUNT_IF(
                a.code_module IS NOT NULL
                AND a.code_presentation IS NOT NULL
                AND c.code_module IS NULL
            ) = 0 THEN 'PASS'
            WHEN COUNT_IF(
                a.code_module IS NOT NULL
                AND a.code_presentation IS NOT NULL
                AND c.code_module IS NULL
            ) * 100.0 / COUNT(*) <= 0.1 THEN 'WARN'
            ELSE 'FAIL'
        END
    FROM oulad.oulad_bronze.assessment_bronze a
    LEFT JOIN oulad.oulad_bronze.courses_bronze c
        ON a.code_module = c.code_module
        AND a.code_presentation = c.code_presentation

    UNION ALL

    -- Business rule check
    SELECT
        'assessment_bronze',
        'Conflicting records for assessment ID',
        'BUSINESS RULE',
        COUNT(*),
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
        'One id_assessment should represent one assessment definition',
        CASE
            WHEN COUNT_IF(
                id_assessment IN (
                    SELECT id_assessment
                    FROM conflicting_assessments
                )
            ) = 0 THEN 'PASS'
            WHEN COUNT_IF(
                id_assessment IN (
                    SELECT id_assessment
                    FROM conflicting_assessments
                )
            ) * 100.0 / COUNT(*) <= 1 THEN 'WARN'
            ELSE 'FAIL'
        END
    FROM oulad.oulad_bronze.assessment_bronze
)

SELECT
    table_name,
    check_name,
    dq_category,
    total_rows,
    failed_rows,
    failure_pct,
    expected_value,
    status
FROM validation_results
ORDER BY
    CASE dq_category
        WHEN 'VOLUME' THEN 1
        WHEN 'NULL' THEN 2
        WHEN 'UNIQUE' THEN 3
        WHEN 'TYPE / FORMAT' THEN 4
        WHEN 'RANGE' THEN 5
        WHEN 'ACCEPTED VALUE' THEN 6
        WHEN 'SENTINEL' THEN 7
        WHEN 'FOREIGN KEY' THEN 8
        WHEN 'BUSINESS RULE' THEN 9
        ELSE 10
    END,
    check_name;