-- ASSESSMENT SILVER DATA QUALITY VALIDATION

WITH base AS (
    SELECT *
    FROM oulad.oulad_silver.assessment_silver
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
                WHEN CAST(date AS STRING) = '?' THEN 1
                ELSE 0
            END
        ) AS expected_null_dates
    FROM oulad.oulad_bronze.assessment_bronze
),

course_keys AS (
    SELECT DISTINCT
        TRIM(UPPER(code_module)) AS code_module,
        TRIM(UPPER(code_presentation)) AS code_presentation
    FROM oulad.oulad_silver.courses_silver
),

exact_duplicate_count AS (
    SELECT
        COALESCE(SUM(duplicate_count - 1), 0) AS duplicate_records
    FROM (
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
        'assessment_silver',
        NULL,
        'VOLUME',
        'Silver row count matches Bronze row count',
        'WARN',
        CAST(e.bronze_count AS STRING),
        CAST(tc.total_records AS STRING),
        tc.total_records,
        tc.total_records - ABS(tc.total_records - e.bronze_count),
        ABS(tc.total_records - e.bronze_count)
    FROM table_count tc
    CROSS JOIN bronze_expectations e

    UNION ALL

    -- Required fields
    SELECT
        'assessment_silver',
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
        'assessment_silver',
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

    SELECT
        'assessment_silver',
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

    SELECT
        'assessment_silver',
        'assessment_type',
        'NULL',
        'Required assessment_type is not NULL or blank',
        'FAIL',
        '0',
        CAST(COUNT_IF(
            assessment_type IS NULL
            OR TRIM(assessment_type) = ''
        ) AS STRING),
        COUNT(*),
        COUNT(*) - COUNT_IF(
            assessment_type IS NULL
            OR TRIM(assessment_type) = ''
        ),
        COUNT_IF(
            assessment_type IS NULL
            OR TRIM(assessment_type) = ''
        )
    FROM base

    UNION ALL

    -- Expected NULL dates originate from Bronze '?'
    SELECT
        'assessment_silver',
        'date',
        'NULL',
        'NULL assessment dates match expected Bronze sentinel count',
        'WARN',
        CAST(e.expected_null_dates AS STRING),
        CAST(COUNT_IF(a.date IS NULL) AS STRING),
        COUNT(*),
        COUNT(*) - COUNT_IF(a.date IS NULL),
        COUNT_IF(a.date IS NULL)
    FROM base a
    CROSS JOIN bronze_expectations e
    GROUP BY e.expected_null_dates

    UNION ALL

    -- Weight should be available
    SELECT
        'assessment_silver',
        'weight',
        'NULL',
        'Assessment weight is not NULL',
        'FAIL',
        '0',
        CAST(COUNT_IF(weight IS NULL) AS STRING),
        COUNT(*),
        COUNT(*) - COUNT_IF(weight IS NULL),
        COUNT_IF(weight IS NULL)
    FROM base

    UNION ALL

    -- Business key uniqueness
    SELECT
        'assessment_silver',
        'id_assessment',
        'UNIQUE',
        'Assessment business key is unique',
        'FAIL',
        '0 duplicate records',
        CAST(COUNT(*) - COUNT(DISTINCT id_assessment) AS STRING),
        COUNT(*),
        COUNT(DISTINCT id_assessment),
        COUNT(*) - COUNT(DISTINCT id_assessment)
    FROM base

    UNION ALL

    -- Exact duplicates
    SELECT
        'assessment_silver',
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

    -- Weight range
    SELECT
        'assessment_silver',
        'weight',
        'RANGE',
        'Assessment weight is between 0 and 100',
        'FAIL',
        '0 invalid records',
        CAST(COUNT_IF(
            weight < 0
            OR weight > 100
        ) AS STRING),
        COUNT(*),
        COUNT(*) - COUNT_IF(
            weight < 0
            OR weight > 100
        ),
        COUNT_IF(
            weight < 0
            OR weight > 100
        )
    FROM base

    UNION ALL

    -- Accepted assessment types
    SELECT
        'assessment_silver',
        'assessment_type',
        'ACCEPTED VALUE',
        'Assessment type is TMA, CMA, or Exam',
        'FAIL',
        'TMA, CMA, Exam',
        CAST(COUNT_IF(
            assessment_type IS NOT NULL
            AND assessment_type NOT IN ('TMA', 'CMA', 'Exam')
        ) AS STRING),
        COUNT(*),
        COUNT(*) - COUNT_IF(
            assessment_type IS NOT NULL
            AND assessment_type NOT IN ('TMA', 'CMA', 'Exam')
        ),
        COUNT_IF(
            assessment_type IS NOT NULL
            AND assessment_type NOT IN ('TMA', 'CMA', 'Exam')
        )
    FROM base

    UNION ALL

    -- Standardization
    SELECT
        'assessment_silver',
        NULL,
        'STANDARDIZATION',
        'Categorical values are trimmed and standardized',
        'FAIL',
        '0 untrimmed records',
        CAST(COUNT_IF(
            code_module <> TRIM(code_module)
            OR code_presentation <> TRIM(code_presentation)
            OR assessment_type <> TRIM(assessment_type)
        ) AS STRING),
        COUNT(*),
        COUNT(*) - COUNT_IF(
            code_module <> TRIM(code_module)
            OR code_presentation <> TRIM(code_presentation)
            OR assessment_type <> TRIM(assessment_type)
        ),
        COUNT_IF(
            code_module <> TRIM(code_module)
            OR code_presentation <> TRIM(code_presentation)
            OR assessment_type <> TRIM(assessment_type)
        )
    FROM base

    UNION ALL

    -- Course referential integrity
    SELECT
        'assessment_silver',
        NULL,
        'REFERENTIAL INTEGRITY',
        'Every assessment references an existing course presentation',
        'FAIL',
        '0 unmatched records',
        CAST(COUNT_IF(c.code_module IS NULL) AS STRING),
        COUNT(*),
        COUNT(*) - COUNT_IF(c.code_module IS NULL),
        COUNT_IF(c.code_module IS NULL)
    FROM base a
    LEFT JOIN course_keys c
        ON TRIM(UPPER(a.code_module)) = c.code_module
       AND TRIM(UPPER(a.code_presentation)) = c.code_presentation

    UNION ALL

    -- Bronze lineage
    SELECT
        'assessment_silver',
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

    -- Silver processing metadata
    SELECT
        'assessment_silver',
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