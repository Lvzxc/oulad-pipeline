-- VLE SILVER DATA QUALITY VALIDATION

WITH base AS (
    SELECT *
    FROM oulad.oulad_silver.vle_silver
),

table_count AS (
    SELECT COUNT(*) AS total_records
    FROM base
),

-- Silver is expected to contain the same or fewer records than Bronze
-- after Silver transformations and deduplication.
bronze_expectations AS (
    SELECT
        COUNT(*) AS bronze_count
    FROM oulad.oulad_bronze.vle_bronze
),

course_keys AS (
    SELECT DISTINCT
        code_module,
        code_presentation
    FROM oulad.oulad_silver.courses_silver
),

exact_duplicate_count AS (
    SELECT
        COALESCE(SUM(duplicate_count - 1), 0) AS duplicate_records
    FROM (
        SELECT
            id_site,
            code_module,
            code_presentation,
            activity_type,
            week_from,
            week_to,
            COUNT(*) AS duplicate_count
        FROM base
        GROUP BY
            id_site,
            code_module,
            code_presentation,
            activity_type,
            week_from,
            week_to
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
        'vle_silver',
        NULL,
        'VOLUME',
        'Silver row count does not exceed Bronze row count',
        'INFO',
        CONCAT('< or = ', CAST(e.bronze_count AS STRING)),
        CAST(tc.total_records AS STRING),
        tc.total_records,
        CASE
            WHEN tc.total_records <= e.bronze_count
            THEN tc.total_records
            ELSE 0
        END,
        CASE
            WHEN tc.total_records <= e.bronze_count
            THEN 0
            ELSE tc.total_records - e.bronze_count
        END
    FROM table_count tc
    CROSS JOIN bronze_expectations e

    UNION ALL

    -- Required fields
    SELECT
        'vle_silver',
        'id_site',
        'NULL',
        'Required id_site is not NULL',
        'FAIL',
        '0',
        CAST(COUNT_IF(id_site IS NULL) AS STRING),
        COUNT(*),
        COUNT(*) - COUNT_IF(id_site IS NULL),
        COUNT_IF(id_site IS NULL)
    FROM base

    UNION ALL

    SELECT
        'vle_silver',
        'code_module',
        'NULL',
        'Required code_module is not NULL',
        'FAIL',
        '0',
        CAST(COUNT_IF(code_module IS NULL) AS STRING),
        COUNT(*),
        COUNT(*) - COUNT_IF(code_module IS NULL),
        COUNT_IF(code_module IS NULL)
    FROM base

    UNION ALL

    SELECT
        'vle_silver',
        'code_presentation',
        'NULL',
        'Required code_presentation is not NULL',
        'FAIL',
        '0',
        CAST(COUNT_IF(code_presentation IS NULL) AS STRING),
        COUNT(*),
        COUNT(*) - COUNT_IF(code_presentation IS NULL),
        COUNT_IF(code_presentation IS NULL)
    FROM base

    UNION ALL

    SELECT
        'vle_silver',
        'activity_type',
        'NULL',
        'Required activity_type is not NULL',
        'FAIL',
        '0',
        CAST(COUNT_IF(activity_type IS NULL) AS STRING),
        COUNT(*),
        COUNT(*) - COUNT_IF(activity_type IS NULL),
        COUNT_IF(activity_type IS NULL)
    FROM base

    UNION ALL

    -- Business key uniqueness
    SELECT
        'vle_silver',
        NULL,
        'UNIQUE',
        'VLE site business key is unique',
        'FAIL',
        '0 duplicate records',
        CAST(
            COUNT(*) - COUNT(DISTINCT CONCAT(
                id_site, '|',
                code_module, '|',
                code_presentation
            ))
            AS STRING
        ),
        COUNT(*),
        COUNT(DISTINCT CONCAT(
            id_site, '|',
            code_module, '|',
            code_presentation
        )),
        COUNT(*) - COUNT(DISTINCT CONCAT(
            id_site, '|',
            code_module, '|',
            code_presentation
        ))
    FROM base

    UNION ALL

    -- Exact duplicates
    SELECT
        'vle_silver',
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
        'vle_silver',
        NULL,
        'SOURCE SENTINEL',
        'No unresolved sentinel (?) values remain',
        'FAIL',
        '0',
        CAST(COUNT_IF(
            code_module = '?'
            OR code_presentation = '?'
            OR activity_type = '?'
        ) AS STRING),
        COUNT(*),
        COUNT(*) - COUNT_IF(
            code_module = '?'
            OR code_presentation = '?'
            OR activity_type = '?'
        ),
        COUNT_IF(
            code_module = '?'
            OR code_presentation = '?'
            OR activity_type = '?'
        )
    FROM base

    UNION ALL

    -- Standardization
    SELECT
        'vle_silver',
        NULL,
        'STANDARDIZATION',
        'Module and presentation values are uppercase and trimmed; activity type is lowercase and trimmed',
        'FAIL',
        '0 unstandardized records',
        CAST(COUNT_IF(
            code_module <> UPPER(TRIM(code_module))
            OR code_presentation <> UPPER(TRIM(code_presentation))
            OR activity_type <> LOWER(TRIM(activity_type))
        ) AS STRING),
        COUNT(*),
        COUNT(*) - COUNT_IF(
            code_module <> UPPER(TRIM(code_module))
            OR code_presentation <> UPPER(TRIM(code_presentation))
            OR activity_type <> LOWER(TRIM(activity_type))
        ),
        COUNT_IF(
            code_module <> UPPER(TRIM(code_module))
            OR code_presentation <> UPPER(TRIM(code_presentation))
            OR activity_type <> LOWER(TRIM(activity_type))
        )
    FROM base

    UNION ALL

    -- Course referential integrity
    SELECT
        'vle_silver',
        NULL,
        'REFERENTIAL INTEGRITY',
        'Every VLE site references an existing course presentation',
        'FAIL',
        '0 unmatched records',
        CAST(COUNT_IF(c.code_module IS NULL) AS STRING),
        COUNT(*),
        COUNT(*) - COUNT_IF(c.code_module IS NULL),
        COUNT_IF(c.code_module IS NULL)
    FROM base v
    LEFT JOIN course_keys c
        ON v.code_module = c.code_module
       AND v.code_presentation = c.code_presentation

    UNION ALL

    -- Lineage
    SELECT
        'vle_silver',
        'ingestion_timestamp',
        'LINEAGE',
        'Ingestion timestamp is present',
        'FAIL',
        '0 missing records',
        CAST(COUNT_IF(ingestion_timestamp IS NULL) AS STRING),
        COUNT(*),
        COUNT(*) - COUNT_IF(ingestion_timestamp IS NULL),
        COUNT_IF(ingestion_timestamp IS NULL)
    FROM base

    UNION ALL

    SELECT
        'vle_silver',
        'ingestion_date',
        'LINEAGE',
        'Ingestion date is present',
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