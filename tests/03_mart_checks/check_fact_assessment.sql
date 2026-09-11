-- FACT_ASSESSMENT GOLD DATA QUALITY VALIDATION

WITH base AS (
    SELECT *
    FROM oulad.oulad_gold.fact_assessment
),

expectations AS (
    -- Expected fact rows come from Silver assessment records
    -- that successfully map to all required Gold dimensions.
    SELECT
        COUNT(*) AS expected_row_count
    FROM oulad.oulad_silver.student_assessment_silver sa
    INNER JOIN oulad.oulad_gold.dim_student ds
        ON sa.id_student = ds.id_student
    INNER JOIN oulad.oulad_gold.dim_assessment da
        ON sa.id_assessment = da.id_assessment
    INNER JOIN oulad.oulad_gold.dim_date dd
        ON sa.date_submitted = dd.date_key
),

dq_results AS (

    -- Volume
    SELECT
        'fact_assessment' AS table_name,
        'Row count' AS check_name,
        'VOLUME' AS check_type,
        COUNT(*) AS records_checked,
        ABS(COUNT(*) - e.expected_row_count) AS failures,
        CAST(e.expected_row_count AS STRING) AS expected_value,
        CAST(COUNT(*) AS STRING) AS actual_value
    FROM base
    CROSS JOIN expectations e
    GROUP BY e.expected_row_count

    UNION ALL

    -- Required keys
    SELECT
        'fact_assessment',
        'Missing student_key',
        'NULL',
        COUNT(*),
        COUNT_IF(student_key IS NULL),
        '0',
        CAST(COUNT_IF(student_key IS NULL) AS STRING)
    FROM base

    UNION ALL

    SELECT
        'fact_assessment',
        'Missing course_key',
        'NULL',
        COUNT(*),
        COUNT_IF(course_key IS NULL),
        '0',
        CAST(COUNT_IF(course_key IS NULL) AS STRING)
    FROM base

    UNION ALL

    SELECT
        'fact_assessment',
        'Missing assessment_key',
        'NULL',
        COUNT(*),
        COUNT_IF(assessment_key IS NULL),
        '0',
        CAST(COUNT_IF(assessment_key IS NULL) AS STRING)
    FROM base

    UNION ALL

    SELECT
        'fact_assessment',
        'Missing date_key',
        'NULL',
        COUNT(*),
        COUNT_IF(date_key IS NULL),
        '0',
        CAST(COUNT_IF(date_key IS NULL) AS STRING)
    FROM base

    UNION ALL

    -- Fact grain uniqueness
    SELECT
        'fact_assessment',
        'Duplicate assessment fact',
        'UNIQUE',
        COUNT(*),
        COUNT(*) - COUNT(
            DISTINCT CONCAT(
                student_key,
                '|',
                course_key,
                '|',
                assessment_key,
                '|',
                date_key
            )
        ),
        '0',
        CAST(
            COUNT(*) - COUNT(
                DISTINCT CONCAT(
                    student_key,
                    '|',
                    course_key,
                    '|',
                    assessment_key,
                    '|',
                    date_key
                )
            )
            AS STRING
        )
    FROM base

    UNION ALL

    -- Student foreign key
    SELECT
        'fact_assessment',
        'Assessment without matching student',
        'FOREIGN KEY',
        COUNT(*),
        COUNT_IF(ds.student_key IS NULL),
        '0',
        CAST(
            COUNT_IF(ds.student_key IS NULL)
            AS STRING
        )
    FROM base f
    LEFT JOIN oulad.oulad_gold.dim_student ds
        ON f.student_key = ds.student_key

    UNION ALL

    -- Course foreign key
    SELECT
        'fact_assessment',
        'Assessment without matching course',
        'FOREIGN KEY',
        COUNT(*),
        COUNT_IF(dc.course_key IS NULL),
        '0',
        CAST(
            COUNT_IF(dc.course_key IS NULL)
            AS STRING
        )
    FROM base f
    LEFT JOIN oulad.oulad_gold.dim_course dc
        ON f.course_key = dc.course_key

    UNION ALL

    -- Assessment foreign key
    SELECT
        'fact_assessment',
        'Assessment without matching assessment',
        'FOREIGN KEY',
        COUNT(*),
        COUNT_IF(da.assessment_key IS NULL),
        '0',
        CAST(
            COUNT_IF(da.assessment_key IS NULL)
            AS STRING
        )
    FROM base f
    LEFT JOIN oulad.oulad_gold.dim_assessment da
        ON f.assessment_key = da.assessment_key

    UNION ALL

    -- Date foreign key
    SELECT
        'fact_assessment',
        'Assessment without matching date',
        'FOREIGN KEY',
        COUNT(*),
        COUNT_IF(dd.date_key IS NULL),
        '0',
        CAST(
            COUNT_IF(dd.date_key IS NULL)
            AS STRING
        )
    FROM base f
    LEFT JOIN oulad.oulad_gold.dim_date dd
        ON f.date_key = dd.date_key

    UNION ALL

    -- Verify that the student belongs to the same course
    -- as the assessment.
    SELECT
        'fact_assessment',
        'Student-course mismatch',
        'RELATIONSHIP',
        COUNT(*),
        COUNT_IF(ds.course_key <> da.course_key),
        '0',
        CAST(
            COUNT_IF(ds.course_key <> da.course_key)
            AS STRING
        )
    FROM base f
    JOIN oulad.oulad_gold.dim_student ds
        ON f.student_key = ds.student_key
    JOIN oulad.oulad_gold.dim_assessment da
        ON f.assessment_key = da.assessment_key

    UNION ALL

    -- Score range
    SELECT
        'fact_assessment',
        'Invalid score range',
        'RANGE',
        COUNT(*),
        COUNT_IF(
            score IS NOT NULL
            AND (score < 0 OR score > 100)
        ),
        '0-100',
        CAST(
            COUNT_IF(
                score IS NOT NULL
                AND (score < 0 OR score > 100)
            )
            AS STRING
        )
    FROM base

    UNION ALL

    -- is_banked accepted values
    SELECT
        'fact_assessment',
        'Invalid is_banked value',
        'ACCEPTED VALUE',
        COUNT(*),
        COUNT_IF(
            is_banked IS NOT NULL
            AND is_banked NOT IN (0, 1)
        ),
        '0, 1',
        CAST(
            COUNT_IF(
                is_banked IS NOT NULL
                AND is_banked NOT IN (0, 1)
            )
            AS STRING
        )
    FROM base

    UNION ALL

    -- Gold lineage
    SELECT
        'fact_assessment',
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

    CASE
        WHEN failures = 0
        THEN 'PASS'

        -- Required fact keys are critical.
        WHEN check_type = 'NULL'
        THEN 'FAIL'

        -- Relationship integrity
        WHEN check_type = 'RELATIONSHIP'
             AND failure_pct <= 0.1
        THEN 'WARN'

        WHEN check_type = 'RELATIONSHIP'
        THEN 'FAIL'

        -- UNIQUE / RANGE / ACCEPTED VALUE
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

        -- FOREIGN KEY
        WHEN check_type = 'FOREIGN KEY'
             AND failure_pct <= 0.1
        THEN 'WARN'

        WHEN check_type = 'FOREIGN KEY'
        THEN 'FAIL'

        -- VOLUME
        WHEN check_type = 'VOLUME'
             AND failure_pct <= 2
        THEN 'WARN'

        WHEN check_type = 'VOLUME'
        THEN 'FAIL'

        -- LINEAGE
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