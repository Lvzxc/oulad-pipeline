-- STUDENT ASSESSMENT SILVER DATA QUALITY VALIDATION

WITH base AS (
    SELECT *
    FROM oulad.oulad_silver.student_assessment_silver
),

-- Expected values are derived from Bronze to avoid hard-coded counts.
bronze_expectations AS (
    SELECT
        COUNT(*) AS bronze_count,
        SUM(
            CASE
                WHEN CAST(score AS STRING) = '?' THEN 1
                ELSE 0
            END
        ) AS expected_null_scores
    FROM oulad.oulad_bronze.student_assessment_bronze
),

assessment_keys AS (
    SELECT DISTINCT
        id_assessment
    FROM oulad.oulad_silver.assessment_silver
    WHERE id_assessment IS NOT NULL
),

student_keys AS (
    SELECT DISTINCT
        id_student
    FROM oulad.oulad_silver.student_info_silver
    WHERE id_student IS NOT NULL
),

dq_results AS (

    -- Volume check
    SELECT
        'student_assessment_silver' AS table_name,
        'Row count' AS check_name,
        'VOLUME' AS check_type,
        COUNT(*) AS records_checked,
        ABS(COUNT(*) - e.bronze_count) AS failures,
        CAST(e.bronze_count AS STRING) AS expected_value
    FROM base
    CROSS JOIN bronze_expectations e
    GROUP BY e.bronze_count

    UNION ALL

    -- Required key checks
    SELECT
        'student_assessment_silver',
        'Missing id_assessment',
        'NULL',
        COUNT(*),
        COUNT_IF(id_assessment IS NULL),
        '0'
    FROM base

    UNION ALL

    SELECT
        'student_assessment_silver',
        'Missing id_student',
        'NULL',
        COUNT(*),
        COUNT_IF(id_student IS NULL),
        '0'
    FROM base

    UNION ALL

    -- Other field completeness checks
    SELECT
        'student_assessment_silver',
        'Missing date_submitted',
        'NULL',
        COUNT(*),
        COUNT_IF(date_submitted IS NULL),
        '0'
    FROM base

    UNION ALL

    SELECT
        'student_assessment_silver',
        'Missing is_banked',
        'NULL',
        COUNT(*),
        COUNT_IF(is_banked IS NULL),
        '0'
    FROM base

    UNION ALL

    -- Score NULLs are expected when Bronze contains '?' values.
    SELECT
        'student_assessment_silver',
        'Missing score',
        'NULL',
        COUNT(*),
        COUNT_IF(score IS NULL),
        CAST(e.expected_null_scores AS STRING)
    FROM base
    CROSS JOIN bronze_expectations e
    GROUP BY e.expected_null_scores

    UNION ALL

    -- Business grain uniqueness
    SELECT
        'student_assessment_silver',
        'Duplicate student-assessment business key',
        'UNIQUE',
        COUNT(*),
        COUNT(*) - COUNT(DISTINCT STRUCT(id_assessment, id_student)),
        '0'
    FROM base

    UNION ALL

    -- Score should no longer contain unresolved source sentinels.
    SELECT
        'student_assessment_silver',
        'Unresolved sentinel (?) in score',
        'SENTINEL',
        COUNT(*),
        COUNT_IF(CAST(score AS STRING) = '?'),
        '0'
    FROM base

    UNION ALL

    -- Score range
    SELECT
        'student_assessment_silver',
        'Score outside valid range',
        'RANGE',
        COUNT(*),
        COUNT_IF(
            score IS NOT NULL
            AND (score < 0 OR score > 100)
        ),
        '0'
    FROM base

    UNION ALL

    -- Accepted values for is_banked
    SELECT
        'student_assessment_silver',
        'Invalid is_banked value',
        'ACCEPTED VALUE',
        COUNT(*),
        COUNT_IF(
            is_banked IS NOT NULL
            AND is_banked NOT IN (0, 1)
        ),
        '0'
    FROM base

    UNION ALL

    -- Referential integrity: assessment
    SELECT
        'student_assessment_silver',
        'Assessment without matching assessment definition',
        'FOREIGN KEY',
        COUNT(*),
        COUNT_IF(a.id_assessment IS NULL),
        '0'
    FROM base b
    LEFT JOIN assessment_keys a
        ON b.id_assessment = a.id_assessment

    UNION ALL

    -- Referential integrity: student
    SELECT
        'student_assessment_silver',
        'Assessment without matching student',
        'FOREIGN KEY',
        COUNT(*),
        COUNT_IF(s.id_student IS NULL),
        '0'
    FROM base b
    LEFT JOIN student_keys s
        ON b.id_student = s.id_student

    UNION ALL

    -- Lineage checks
    SELECT
        'student_assessment_silver',
        'Missing ingestion timestamp',
        'LINEAGE',
        COUNT(*),
        COUNT_IF(ingestion_timestamp IS NULL),
        '0'
    FROM base

    UNION ALL

    SELECT
        'student_assessment_silver',
        'Missing ingestion date',
        'LINEAGE',
        COUNT(*),
        COUNT_IF(ingestion_date IS NULL),
        '0'
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
    failure_pct,

    -- Apply the thresholds defined in the DQ framework.
    CASE

        -- Expected score NULLs are acceptable when they match Bronze.
        WHEN check_name = 'Missing score'
             AND CAST(failures AS STRING) = expected_value
        THEN 'PASS'

        -- No actual failures means the check passes.
        WHEN failures = 0
        THEN 'PASS'

        -- Mandatory key fields: any NULL is a FAIL.
        WHEN check_name IN (
            'Missing id_assessment',
            'Missing id_student'
        )
        THEN 'FAIL'

        -- Other NULL fields: 1% warning threshold.
        WHEN check_type = 'NULL'
             AND failure_pct <= 1
        THEN 'WARN'

        WHEN check_type = 'NULL'
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

        -- Other checks: 1% warning threshold.
        WHEN check_type IN (
            'SENTINEL',
            'LINEAGE'
        )
        AND failure_pct <= 1
        THEN 'WARN'

        ELSE 'FAIL'
    END AS status

FROM measured

ORDER BY
    CASE check_type
        WHEN 'VOLUME' THEN 1
        WHEN 'NULL' THEN 2
        WHEN 'UNIQUE' THEN 3
        WHEN 'SENTINEL' THEN 4
        WHEN 'RANGE' THEN 5
        WHEN 'ACCEPTED VALUE' THEN 6
        WHEN 'FOREIGN KEY' THEN 7
        WHEN 'LINEAGE' THEN 8
        ELSE 9
    END,
    check_name;