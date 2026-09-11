-- DIM_COURSE GOLD DQ RESULTS

WITH base AS (
    SELECT *
    FROM oulad.oulad_gold.dim_course
),

expectations AS (
    SELECT COUNT(*) AS silver_count
    FROM oulad.oulad_silver.courses_silver
),

checks AS (

    -- VOLUME
    SELECT
        'dim_course' AS table_name,
        'code_module,code_presentation' AS column_name,
        'VOLUME' AS dq_dimension,
        'Row count reconciliation' AS rule_name,
        'INFO' AS severity,
        CAST(e.silver_count AS STRING) AS expected_value,
        CAST(COUNT(*) AS STRING) AS actual_value,
        COUNT(*) AS total_records,
        COUNT(*) AS passed_records,
        ABS(COUNT(*) - e.silver_count) AS failed_records
    FROM base
    CROSS JOIN expectations e
    GROUP BY e.silver_count

    UNION ALL

    -- NULL: course_key
    SELECT
        'dim_course',
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

    -- UNIQUE: course_key
    SELECT
        'dim_course',
        'course_key',
        'UNIQUE',
        'Duplicate course_key',
        'FAIL',
        '0',
        CAST(COUNT(*) - COUNT(DISTINCT course_key) AS STRING),
        COUNT(*),
        COUNT(*) - (COUNT(*) - COUNT(DISTINCT course_key)),
        COUNT(*) - COUNT(DISTINCT course_key)
    FROM base

    UNION ALL

    -- UNIQUE: natural business key
    SELECT
        'dim_course',
        'code_module,code_presentation',
        'UNIQUE',
        'Duplicate course business key',
        'FAIL',
        '0',
        CAST(
            COUNT(*) - COUNT(
                DISTINCT CONCAT(code_module, '|', code_presentation)
            ) AS STRING
        ),
        COUNT(*),
        COUNT(*) - (
            COUNT(*) - COUNT(
                DISTINCT CONCAT(code_module, '|', code_presentation)
            )
        ),
        COUNT(*) - COUNT(
            DISTINCT CONCAT(code_module, '|', code_presentation)
        )
    FROM base

    UNION ALL

    -- NULL: code_module
    SELECT
        'dim_course',
        'code_module',
        'NULL',
        'Missing code_module',
        'FAIL',
        '0',
        CAST(COUNT_IF(code_module IS NULL OR TRIM(code_module) = '') AS STRING),
        COUNT(*),
        COUNT(*) - COUNT_IF(code_module IS NULL OR TRIM(code_module) = ''),
        COUNT_IF(code_module IS NULL OR TRIM(code_module) = '')
    FROM base

    UNION ALL

    -- NULL: code_presentation
    SELECT
        'dim_course',
        'code_presentation',
        'NULL',
        'Missing code_presentation',
        'FAIL',
        '0',
        CAST(COUNT_IF(code_presentation IS NULL OR TRIM(code_presentation) = '') AS STRING),
        COUNT(*),
        COUNT(*) - COUNT_IF(code_presentation IS NULL OR TRIM(code_presentation) = ''),
        COUNT_IF(code_presentation IS NULL OR TRIM(code_presentation) = '')
    FROM base

    UNION ALL

    -- RANGE: module presentation length
    SELECT
        'dim_course',
        'module_presentation_length',
        'RANGE',
        'Invalid module presentation length',
        'FAIL',
        '> 0',
        CAST(
            COUNT_IF(
                module_presentation_length IS NULL
                OR module_presentation_length <= 0
            ) AS STRING
        ),
        COUNT(*),
        COUNT(*) - COUNT_IF(
            module_presentation_length IS NULL
            OR module_presentation_length <= 0
        ),
        COUNT_IF(
            module_presentation_length IS NULL
            OR module_presentation_length <= 0
        )
    FROM base

    UNION ALL

    -- BUSINESS: Silver lineage
    SELECT
        'dim_course',
        'silver_processed_timestamp',
        'BUSINESS',
        'Missing Silver processing timestamp',
        'FAIL',
        '0',
        CAST(COUNT_IF(silver_processed_timestamp IS NULL) AS STRING),
        COUNT(*),
        COUNT(*) - COUNT_IF(silver_processed_timestamp IS NULL),
        COUNT_IF(silver_processed_timestamp IS NULL)
    FROM base

    UNION ALL

    -- BUSINESS: Gold lineage
    SELECT
        'dim_course',
        'gold_processed_timestamp',
        'BUSINESS',
        'Missing Gold processing timestamp',
        'FAIL',
        '0',
        CAST(COUNT_IF(gold_processed_timestamp IS NULL) AS STRING),
        COUNT(*),
        COUNT(*) - COUNT_IF(gold_processed_timestamp IS NULL),
        COUNT_IF(gold_processed_timestamp IS NULL)
    FROM base
),

final_results AS (
    SELECT
        uuid() AS run_id,
        current_timestamp() AS run_timestamp,
        'GOLD' AS layer,
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
        ROUND(
            failed_records * 100.0 / NULLIF(total_records, 0),
            2
        ) AS failure_pct,
        CASE
            WHEN severity = 'INFO' THEN NULL
            WHEN failed_records = 0 THEN 100.0
            ELSE ROUND(
                (passed_records * 100.0) / NULLIF(total_records, 0),
                2
            )
        END AS dq_score,
        CASE
            WHEN severity = 'INFO' THEN NULL
            WHEN failed_records = 0 THEN 'PASS'
            ELSE 'FAIL'
        END AS status
    FROM checks
)

INSERT INTO oulad.oulad_quality.dq_results
SELECT *
FROM final_results;