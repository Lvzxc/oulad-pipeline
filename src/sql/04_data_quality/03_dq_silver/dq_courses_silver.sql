-- COURSES SILVER DATA QUALITY VALIDATION

WITH base AS (
    SELECT *
    FROM oulad.oulad_silver.courses_silver
),

table_count AS (
    SELECT COUNT(*) AS total_records
    FROM base
),

bronze_expectations AS (
    SELECT
        COUNT(*) AS bronze_count
    FROM oulad.oulad_bronze.courses_bronze
),

exact_duplicate_count AS (
    SELECT
        COALESCE(SUM(duplicate_count - 1), 0) AS duplicate_records
    FROM (
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
        'courses_silver',
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

    -- Required module
    SELECT
        'courses_silver',
        'code_module',
        'NULL',
        'Required code_module is not NULL or blank',
        'FAIL',
        '0',
        CAST(COUNT_IF(
            code_module IS NULL
            OR TRIM(code_module) = ''
        ) AS STRING),
        COUNT(*),
        COUNT(*) - COUNT_IF(
            code_module IS NULL
            OR TRIM(code_module) = ''
        ),
        COUNT_IF(
            code_module IS NULL
            OR TRIM(code_module) = ''
        )
    FROM base

    UNION ALL

    -- Required presentation
    SELECT
        'courses_silver',
        'code_presentation',
        'NULL',
        'Required code_presentation is not NULL or blank',
        'FAIL',
        '0',
        CAST(COUNT_IF(
            code_presentation IS NULL
            OR TRIM(code_presentation) = ''
        ) AS STRING),
        COUNT(*),
        COUNT(*) - COUNT_IF(
            code_presentation IS NULL
            OR TRIM(code_presentation) = ''
        ),
        COUNT_IF(
            code_presentation IS NULL
            OR TRIM(code_presentation) = ''
        )
    FROM base

    UNION ALL

    -- Required duration
    SELECT
        'courses_silver',
        'module_presentation_length',
        'NULL',
        'Module presentation length is not NULL',
        'FAIL',
        '0',
        CAST(COUNT_IF(
            module_presentation_length IS NULL
        ) AS STRING),
        COUNT(*),
        COUNT(*) - COUNT_IF(
            module_presentation_length IS NULL
        ),
        COUNT_IF(
            module_presentation_length IS NULL
        )
    FROM base

    UNION ALL

    -- Positive duration
    SELECT
        'courses_silver',
        'module_presentation_length',
        'RANGE',
        'Module presentation length is greater than 0',
        'FAIL',
        '0 invalid records',
        CAST(COUNT_IF(
            module_presentation_length <= 0
        ) AS STRING),
        COUNT(*),
        COUNT(*) - COUNT_IF(
            module_presentation_length <= 0
        ),
        COUNT_IF(
            module_presentation_length <= 0
        )
    FROM base

    UNION ALL

    -- Business key uniqueness
    SELECT
        'courses_silver',
        NULL,
        'UNIQUE',
        'Course business key is unique',
        'FAIL',
        '0 duplicate records',
        CAST(
            COUNT(*) - COUNT(DISTINCT CONCAT(
                code_module,
                '|',
                code_presentation
            ))
            AS STRING
        ),
        COUNT(*),
        COUNT(DISTINCT CONCAT(
            code_module,
            '|',
            code_presentation
        )),
        COUNT(*) - COUNT(DISTINCT CONCAT(
            code_module,
            '|',
            code_presentation
        ))
    FROM base

    UNION ALL

    -- Exact duplicates
    SELECT
        'courses_silver',
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
        'courses_silver',
        NULL,
        'SOURCE SENTINEL',
        'No unresolved sentinel (?) values remain',
        'FAIL',
        '0',
        CAST(COUNT_IF(
            code_module = '?'
            OR code_presentation = '?'
        ) AS STRING),
        COUNT(*),
        COUNT(*) - COUNT_IF(
            code_module = '?'
            OR code_presentation = '?'
        ),
        COUNT_IF(
            code_module = '?'
            OR code_presentation = '?'
        )
    FROM base

    UNION ALL

    -- Standardization
    SELECT
        'courses_silver',
        NULL,
        'STANDARDIZATION',
        'Module and presentation values are uppercase and trimmed',
        'FAIL',
        '0 unstandardized records',
        CAST(COUNT_IF(
            code_module <> UPPER(TRIM(code_module))
            OR code_presentation <> UPPER(TRIM(code_presentation))
        ) AS STRING),
        COUNT(*),
        COUNT(*) - COUNT_IF(
            code_module <> UPPER(TRIM(code_module))
            OR code_presentation <> UPPER(TRIM(code_presentation))
        ),
        COUNT_IF(
            code_module <> UPPER(TRIM(code_module))
            OR code_presentation <> UPPER(TRIM(code_presentation))
        )
    FROM base

    UNION ALL

    -- Bronze lineage
    SELECT
        'courses_silver',
        'bronze_ingestion_timestamp',
        'LINEAGE',
        'Bronze ingestion timestamp is present',
        'FAIL',
        '0 missing records',
        CAST(COUNT_IF(
            bronze_ingestion_timestamp IS NULL
        ) AS STRING),
        COUNT(*),
        COUNT(*) - COUNT_IF(
            bronze_ingestion_timestamp IS NULL
        ),
        COUNT_IF(
            bronze_ingestion_timestamp IS NULL
        )
    FROM base

    UNION ALL

    -- Silver processing lineage
    SELECT
        'courses_silver',
        'silver_processed_timestamp',
        'LINEAGE',
        'Silver processing timestamp is present',
        'FAIL',
        '0 missing records',
        CAST(COUNT_IF(
            silver_processed_timestamp IS NULL
        ) AS STRING),
        COUNT(*),
        COUNT(*) - COUNT_IF(
            silver_processed_timestamp IS NULL
        ),
        COUNT_IF(
            silver_processed_timestamp IS NULL
        )
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