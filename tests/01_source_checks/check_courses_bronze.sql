-- COURSES BRONZE DATA QUALITY VALIDATION

WITH duplicate_course AS (
    -- Identify duplicate course business keys
    SELECT
        code_module,
        code_presentation,
        COUNT(*) AS duplicate_count
    FROM oulad.oulad_bronze.courses_bronze
    GROUP BY
        code_module,
        code_presentation
    HAVING COUNT(*) > 1
),

duplicate_exact AS (
    -- Identify exact duplicate records
    SELECT
        code_module,
        code_presentation,
        module_presentation_length,
        COUNT(*) AS duplicate_count
    FROM oulad.oulad_bronze.courses_bronze
    GROUP BY
        code_module,
        code_presentation,
        module_presentation_length
    HAVING COUNT(*) > 1
),

validation_results AS (

    -- Volume check
    SELECT
        'courses_bronze' AS table_name,
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
    FROM oulad.oulad_bronze.courses_bronze

    UNION ALL

    -- NULL checks
    SELECT
        'courses_bronze',
        'Missing code_module',
        'NULL',
        COUNT(*),
        COUNT_IF(code_module IS NULL),
        ROUND(
            COUNT_IF(code_module IS NULL) * 100.0 / COUNT(*),
            2
        ),
        '0% missing; mandatory key',
        CASE
            WHEN COUNT_IF(code_module IS NULL) = 0 THEN 'PASS'
            ELSE 'FAIL'
        END
    FROM oulad.oulad_bronze.courses_bronze

    UNION ALL

    SELECT
        'courses_bronze',
        'Missing code_presentation',
        'NULL',
        COUNT(*),
        COUNT_IF(code_presentation IS NULL),
        ROUND(
            COUNT_IF(code_presentation IS NULL) * 100.0 / COUNT(*),
            2
        ),
        '0% missing; mandatory key',
        CASE
            WHEN COUNT_IF(code_presentation IS NULL) = 0 THEN 'PASS'
            ELSE 'FAIL'
        END
    FROM oulad.oulad_bronze.courses_bronze

    UNION ALL

    SELECT
        'courses_bronze',
        'Missing module_presentation_length',
        'NULL',
        COUNT(*),
        COUNT_IF(module_presentation_length IS NULL),
        ROUND(
            COUNT_IF(module_presentation_length IS NULL) * 100.0 / COUNT(*),
            2
        ),
        'Length should be populated',
        CASE
            WHEN COUNT_IF(module_presentation_length IS NULL) = 0 THEN 'PASS'
            WHEN COUNT_IF(module_presentation_length IS NULL) * 100.0 / COUNT(*) <= 1
                THEN 'WARN'
            ELSE 'FAIL'
        END
    FROM oulad.oulad_bronze.courses_bronze

    UNION ALL

    -- Uniqueness checks
    SELECT
        'courses_bronze',
        'Duplicate course business key',
        'UNIQUE',
        COUNT(*),
        COALESCE(
            (SELECT SUM(duplicate_count - 1) FROM duplicate_course),
            0
        ),
        ROUND(
            COALESCE(
                (SELECT SUM(duplicate_count - 1) FROM duplicate_course),
                0
            ) * 100.0 / COUNT(*),
            2
        ),
        '0% duplicate code_module + code_presentation',
        CASE
            WHEN COALESCE(
                (SELECT SUM(duplicate_count - 1) FROM duplicate_course),
                0
            ) = 0 THEN 'PASS'
            WHEN COALESCE(
                (SELECT SUM(duplicate_count - 1) FROM duplicate_course),
                0
            ) * 100.0 / COUNT(*) <= 1 THEN 'WARN'
            ELSE 'FAIL'
        END
    FROM oulad.oulad_bronze.courses_bronze

    UNION ALL

    SELECT
        'courses_bronze',
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
    FROM oulad.oulad_bronze.courses_bronze

    UNION ALL

    -- Format checks for text fields
    SELECT
        'courses_bronze',
        'Invalid code_module format',
        'TYPE / FORMAT',
        COUNT(*),
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
        'code_module must contain a value',
        CASE
            WHEN COUNT_IF(
                code_module IS NOT NULL
                AND TRIM(code_module) = ''
            ) = 0 THEN 'PASS'
            WHEN COUNT_IF(
                code_module IS NOT NULL
                AND TRIM(code_module) = ''
            ) * 100.0 / COUNT(*) <= 1 THEN 'WARN'
            ELSE 'FAIL'
        END
    FROM oulad.oulad_bronze.courses_bronze

    UNION ALL

    SELECT
        'courses_bronze',
        'Invalid code_presentation format',
        'TYPE / FORMAT',
        COUNT(*),
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
        'code_presentation must contain a value',
        CASE
            WHEN COUNT_IF(
                code_presentation IS NOT NULL
                AND TRIM(code_presentation) = ''
            ) = 0 THEN 'PASS'
            WHEN COUNT_IF(
                code_presentation IS NOT NULL
                AND TRIM(code_presentation) = ''
            ) * 100.0 / COUNT(*) <= 1 THEN 'WARN'
            ELSE 'FAIL'
        END
    FROM oulad.oulad_bronze.courses_bronze

    UNION ALL

    -- Range check
    SELECT
        'courses_bronze',
        'Invalid module_presentation_length range',
        'RANGE',
        COUNT(*),
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
        'module_presentation_length must be greater than 0',
        CASE
            WHEN COUNT_IF(
                module_presentation_length IS NOT NULL
                AND module_presentation_length <= 0
            ) = 0 THEN 'PASS'
            WHEN COUNT_IF(
                module_presentation_length IS NOT NULL
                AND module_presentation_length <= 0
            ) * 100.0 / COUNT(*) <= 1 THEN 'WARN'
            ELSE 'FAIL'
        END
    FROM oulad.oulad_bronze.courses_bronze
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
        ELSE 6
    END,
    check_name;