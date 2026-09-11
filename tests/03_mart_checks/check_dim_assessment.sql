-- DIM_ASSESSMENT GOLD DATA QUALITY VALIDATION

WITH base AS (
    SELECT *
    FROM oulad.oulad_gold.dim_assessment
),

-- Expected values are derived from upstream layers to avoid hard-coded counts.
expectations AS (
    SELECT
        COUNT(*) AS silver_count,
        SUM(
            CASE
                WHEN date IS NULL OR CAST(date AS STRING) = '?' THEN 1
                ELSE 0
            END
        ) AS expected_null_dates
    FROM oulad.oulad_silver.assessment_silver
),

dq_results AS (

    -- Volume check
    SELECT
        'dim_assessment' AS table_name,
        'Row count' AS check_name,
        'VOLUME' AS check_type,
        COUNT(*) AS records_checked,
        ABS(COUNT(*) - e.silver_count) AS failures,
        CAST(e.silver_count AS STRING) AS expected_value,
        CAST(COUNT(*) AS STRING) AS actual_value
    FROM base
    CROSS JOIN expectations e
    GROUP BY e.silver_count

    UNION ALL

    -- Surrogate key completeness
    SELECT
        'dim_assessment',
        'Missing assessment_key',
        'NULL',
        COUNT(*),
        COUNT_IF(assessment_key IS NULL),
        '0',
        CAST(COUNT_IF(assessment_key IS NULL) AS STRING)
    FROM base

    UNION ALL

    -- Surrogate key uniqueness
    SELECT
        'dim_assessment',
        'Duplicate assessment_key',
        'UNIQUE',
        COUNT(*),
        COUNT(*) - COUNT(DISTINCT assessment_key),
        '0',
        CAST(
            COUNT(*) - COUNT(DISTINCT assessment_key)
            AS STRING
        )
    FROM base

    UNION ALL

    -- Business key uniqueness
    SELECT
        'dim_assessment',
        'Duplicate assessment business key',
        'UNIQUE',
        COUNT(*),
        COUNT(*) - COUNT(
            DISTINCT CONCAT(
                id_assessment,
                '|',
                code_module,
                '|',
                code_presentation
            )
        ),
        '0',
        CAST(
            COUNT(*) - COUNT(
                DISTINCT CONCAT(
                    id_assessment,
                    '|',
                    code_module,
                    '|',
                    code_presentation
                )
            )
            AS STRING
        )
    FROM base

    UNION ALL

    -- Required assessment ID
    SELECT
        'dim_assessment',
        'Missing id_assessment',
        'NULL',
        COUNT(*),
        COUNT_IF(id_assessment IS NULL),
        '0',
        CAST(COUNT_IF(id_assessment IS NULL) AS STRING)
    FROM base

    UNION ALL

    -- Required course key
    SELECT
        'dim_assessment',
        'Missing course_key',
        'NULL',
        COUNT(*),
        COUNT_IF(course_key IS NULL),
        '0',
        CAST(COUNT_IF(course_key IS NULL) AS STRING)
    FROM base

    UNION ALL

    -- Foreign key to dim_course
    SELECT
        'dim_assessment',
        'Assessment without matching course',
        'FOREIGN KEY',
        COUNT(*),
        COUNT_IF(dc.course_key IS NULL),
        '0',
        CAST(COUNT_IF(dc.course_key IS NULL) AS STRING)
    FROM base a
    LEFT JOIN oulad.oulad_gold.dim_course dc
        ON a.course_key = dc.course_key

    UNION ALL

    -- Assessment type validation
    SELECT
        'dim_assessment',
        'Invalid assessment_type',
        'ACCEPTED VALUE',
        COUNT(*),
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

    -- Assessment date NULLs should match the Silver source expectation.
    SELECT
        'dim_assessment',
        'Missing assessment date',
        'NULL',
        COUNT(*),
        COUNT_IF(assessment_date IS NULL),
        CAST(e.expected_null_dates AS STRING),
        CAST(COUNT_IF(assessment_date IS NULL) AS STRING)
    FROM base
    CROSS JOIN expectations e
    GROUP BY e.expected_null_dates

    UNION ALL

    -- Assessment weight should be within the valid range.
    SELECT
        'dim_assessment',
        'Invalid weight range',
        'RANGE',
        COUNT(*),
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

    -- Silver lineage
    SELECT
        'dim_assessment',
        'Missing Silver processing timestamp',
        'LINEAGE',
        COUNT(*),
        COUNT_IF(silver_processed_timestamp IS NULL),
        '0',
        CAST(
            COUNT_IF(silver_processed_timestamp IS NULL)
            AS STRING
        )
    FROM base

    UNION ALL

    -- Gold lineage
    SELECT
        'dim_assessment',
        'Missing Gold processing timestamp',
        'LINEAGE',
        COUNT(*),
        COUNT_IF(gold_processed_timestamp IS NULL),
        '0',
        CAST(
            COUNT_IF(gold_processed_timestamp IS NULL)
            AS STRING
        )
    FROM base
),

-- Calculate failure percentage before applying thresholds.
measured AS (
    SELECT
        table_name,
        check_name,
        check_type,
        records_checked,
        failures,
        expected_value,
        actual_value,
        ROUND(
            failures * 100.0 / NULLIF(records_checked, 0),
            2
        ) AS failure_pct
    FROM dq_results
)

SELECT
    table_name,
    check_name,
    check_type,
    records_checked,
    failures,
    expected_value,
    actual_value,
    failure_pct,

    -- Apply the thresholds defined in the DQ framework.
    CASE

        -- Expected NULL assessment dates are acceptable
        -- when the actual count matches the source expectation.
        WHEN check_name = 'Missing assessment date'
             AND actual_value = expected_value
        THEN 'PASS'

        -- No actual failures means the check passes.
        WHEN failures = 0
        THEN 'PASS'

        -- Mandatory key fields: any NULL is a FAIL.
        WHEN check_type = 'NULL'
             AND check_name IN (
                 'Missing assessment_key',
                 'Missing id_assessment',
                 'Missing course_key'
             )
        THEN 'FAIL'

        -- UNIQUE / RANGE / ACCEPTED VALUE: 1% warning threshold.
        WHEN check_type IN (
            'UNIQUE',
            'RANGE',
            'ACCEPTED VALUE'
        )
        AND failure_pct <= 1
        THEN 'WARN'

        WHEN check_type IN (
            'UNIQUE',
            'RANGE',
            'ACCEPTED VALUE'
        )
        THEN 'FAIL'

        -- FOREIGN KEY: 0.1% warning threshold.
        WHEN check_type = 'FOREIGN KEY'
             AND failure_pct <= 0.1
        THEN 'WARN'

        WHEN check_type = 'FOREIGN KEY'
        THEN 'FAIL'

        -- VOLUME: 2% warning threshold.
        WHEN check_type = 'VOLUME'
             AND failure_pct <= 2
        THEN 'WARN'

        WHEN check_type = 'VOLUME'
        THEN 'FAIL'

        -- Other NULL checks: 1% warning threshold.
        WHEN check_type = 'NULL'
             AND failure_pct <= 1
        THEN 'WARN'

        WHEN check_type = 'NULL'
        THEN 'FAIL'

        -- Lineage checks: 1% warning threshold.
        WHEN check_type = 'LINEAGE'
             AND failure_pct <= 1
        THEN 'WARN'

        ELSE 'FAIL'
    END AS status

FROM measured

ORDER BY
    CASE
        WHEN status = 'FAIL' THEN 1
        WHEN status = 'WARN' THEN 2
        ELSE 3
    END,
    check_type,
    check_name;