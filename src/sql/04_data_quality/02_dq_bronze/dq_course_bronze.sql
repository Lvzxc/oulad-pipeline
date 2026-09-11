-- COURSES BRONZE DATA QUALITY VALIDATION

WITH run_info AS (
    SELECT
        uuid() AS run_id,
        current_timestamp() AS run_timestamp
),

base AS (
    SELECT *
    FROM oulad.oulad_bronze.courses_bronze
),

duplicate_course AS (
    SELECT
        code_module,
        code_presentation,
        COUNT(*) AS duplicate_count
    FROM base
    GROUP BY
        code_module,
        code_presentation
    HAVING COUNT(*) > 1
),

duplicate_exact AS (
    SELECT
        code_module,
        code_presentation,
        module_presentation_length,
        COUNT(*) AS duplicate_count
    FROM base
    GROUP BY
        code_module,
        code_presentation,
        module_presentation_length
    HAVING COUNT(*) > 1
),

table_count AS (
    SELECT COUNT(*) AS total_records
    FROM base
),

checks AS (

    -- Volume
    SELECT
        'courses_bronze' AS table_name,
        'Row count' AS column_name,
        'VOLUME' AS dq_dimension,
        'Table should contain records' AS rule_name,
        'INFO' AS severity,
        'Greater than 0' AS expected_value,
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
        'courses_bronze',
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
        ROUND(
            (COUNT(*) - COUNT_IF(code_module IS NULL))
            * 100.0 / COUNT(*),
            2
        )
    FROM base

    UNION ALL

    SELECT
        'courses_bronze',
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
        ROUND(
            (COUNT(*) - COUNT_IF(code_presentation IS NULL))
            * 100.0 / COUNT(*),
            2
        )
    FROM base

    UNION ALL

    SELECT
        'courses_bronze',
        'module_presentation_length',
        'NULL',
        'Module presentation length should be populated',
        'FAIL',
        '0% missing',
        CAST(COUNT_IF(module_presentation_length IS NULL) AS STRING),
        COUNT(*),
        COUNT(*) - COUNT_IF(module_presentation_length IS NULL),
        COUNT_IF(module_presentation_length IS NULL),
        ROUND(
            COUNT_IF(module_presentation_length IS NULL)
            * 100.0 / COUNT(*),
            2
        ),
        ROUND(
            (COUNT(*) - COUNT_IF(module_presentation_length IS NULL))
            * 100.0 / COUNT(*),
            2
        )
    FROM base

    UNION ALL

    -- Business key uniqueness
    SELECT
        'courses_bronze',
        'code_module + code_presentation',
        'UNIQUE',
        'Course business key must be unique',
        'FAIL',
        '0 duplicate records',
        CAST(COALESCE(SUM(d.duplicate_count - 1), 0) AS STRING),
        tc.total_records,
        tc.total_records - COALESCE(SUM(d.duplicate_count - 1), 0),
        COALESCE(SUM(d.duplicate_count - 1), 0),
        ROUND(
            COALESCE(SUM(d.duplicate_count - 1), 0)
            * 100.0 / tc.total_records,
            2
        ),
        ROUND(
            (
                tc.total_records
                - COALESCE(SUM(d.duplicate_count - 1), 0)
            ) * 100.0 / tc.total_records,
            2
        )
    FROM table_count tc
    LEFT JOIN duplicate_course d
        ON TRUE
    GROUP BY tc.total_records

    UNION ALL

    -- Exact duplicates
    SELECT
        'courses_bronze',
        'Full course record',
        'UNIQUE',
        'Exact duplicate records should not exist',
        'FAIL',
        '0 duplicate records',
        CAST(COALESCE(SUM(d.duplicate_count - 1), 0) AS STRING),
        tc.total_records,
        tc.total_records - COALESCE(SUM(d.duplicate_count - 1), 0),
        COALESCE(SUM(d.duplicate_count - 1), 0),
        ROUND(
            COALESCE(SUM(d.duplicate_count - 1), 0)
            * 100.0 / tc.total_records,
            2
        ),
        ROUND(
            (
                tc.total_records
                - COALESCE(SUM(d.duplicate_count - 1), 0)
            ) * 100.0 / tc.total_records,
            2
        )
    FROM table_count tc
    LEFT JOIN duplicate_exact d
        ON TRUE
    GROUP BY tc.total_records

    UNION ALL

    -- Text format checks
    SELECT
        'courses_bronze',
        'code_module',
        'TYPE / FORMAT',
        'code_module must contain a value',
        'FAIL',
        'Non-empty value',
        CAST(COUNT_IF(
            code_module IS NOT NULL
            AND TRIM(code_module) = ''
        ) AS STRING),
        COUNT(*),
        COUNT(*) - COUNT_IF(
            code_module IS NOT NULL
            AND TRIM(code_module) = ''
        ),
        COUNT_IF(
            code_module IS NOT NULL
            AND TRIM(code_module) = ''
        ),
        ROUND(
            COUNT_IF(
                code_module IS NOT NULL
                AND TRIM(code_module) = ''
            ) * 100.0 / COUNT(*),
            2
        ),
        ROUND(
            (
                COUNT(*) - COUNT_IF(
                    code_module IS NOT NULL
                    AND TRIM(code_module) = ''
                )
            ) * 100.0 / COUNT(*),
            2
        )
    FROM base

    UNION ALL

    SELECT
        'courses_bronze',
        'code_presentation',
        'TYPE / FORMAT',
        'code_presentation must contain a value',
        'FAIL',
        'Non-empty value',
        CAST(COUNT_IF(
            code_presentation IS NOT NULL
            AND TRIM(code_presentation) = ''
        ) AS STRING),
        COUNT(*),
        COUNT(*) - COUNT_IF(
            code_presentation IS NOT NULL
            AND TRIM(code_presentation) = ''
        ),
        COUNT_IF(
            code_presentation IS NOT NULL
            AND TRIM(code_presentation) = ''
        ),
        ROUND(
            COUNT_IF(
                code_presentation IS NOT NULL
                AND TRIM(code_presentation) = ''
            ) * 100.0 / COUNT(*),
            2
        ),
        ROUND(
            (
                COUNT(*) - COUNT_IF(
                    code_presentation IS NOT NULL
                    AND TRIM(code_presentation) = ''
                )
            ) * 100.0 / COUNT(*),
            2
        )
    FROM base

    UNION ALL

    -- Range
    SELECT
        'courses_bronze',
        'module_presentation_length',
        'RANGE',
        'Module presentation length must be greater than 0',
        'FAIL',
        '> 0',
        CAST(COUNT_IF(
            module_presentation_length IS NOT NULL
            AND module_presentation_length <= 0
        ) AS STRING),
        COUNT(*),
        COUNT(*) - COUNT_IF(
            module_presentation_length IS NOT NULL
            AND module_presentation_length <= 0
        ),
        COUNT_IF(
            module_presentation_length IS NOT NULL
            AND module_presentation_length <= 0
        ),
        ROUND(
            COUNT_IF(
                module_presentation_length IS NOT NULL
                AND module_presentation_length <= 0
            ) * 100.0 / COUNT(*),
            2
        ),
        ROUND(
            (
                COUNT(*) - COUNT_IF(
                    module_presentation_length IS NOT NULL
                    AND module_presentation_length <= 0
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
    'BRONZE' AS layer,
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