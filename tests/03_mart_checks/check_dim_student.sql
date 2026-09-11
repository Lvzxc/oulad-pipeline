-- DIM_STUDENT GOLD DATA QUALITY VALIDATION

WITH base AS (
    SELECT *
    FROM oulad.oulad_gold.dim_student
),

-- Expected values are derived from Silver to avoid hard-coded counts.
expectations AS (
    SELECT
        COUNT(*) AS expected_student_enrollments
    FROM (
        SELECT DISTINCT
            id_student,
            code_module,
            code_presentation
        FROM oulad.oulad_silver.student_info_silver
    )
),

dq_results AS (

    -- Volume check
    SELECT
        'dim_student' AS table_name,
        'Row count' AS check_name,
        'VOLUME' AS check_type,
        COUNT(*) AS records_checked,
        ABS(
            COUNT(*) - e.expected_student_enrollments
        ) AS failures,
        CAST(e.expected_student_enrollments AS STRING) AS expected_value,
        CAST(COUNT(*) AS STRING) AS actual_value
    FROM base
    CROSS JOIN expectations e
    GROUP BY e.expected_student_enrollments

    UNION ALL

    -- Surrogate key completeness
    SELECT
        'dim_student',
        'Missing student_key',
        'NULL',
        COUNT(*),
        COUNT_IF(student_key IS NULL),
        '0',
        CAST(COUNT_IF(student_key IS NULL) AS STRING)
    FROM base

    UNION ALL

    -- Surrogate key uniqueness
    SELECT
        'dim_student',
        'Duplicate student_key',
        'UNIQUE',
        COUNT(*),
        COUNT(*) - COUNT(DISTINCT student_key),
        '0',
        CAST(
            COUNT(*) - COUNT(DISTINCT student_key)
            AS STRING
        )
    FROM base

    UNION ALL

    -- Natural enrollment key uniqueness
    SELECT
        'dim_student',
        'Duplicate student enrollment',
        'UNIQUE',
        COUNT(*),
        COUNT(*) - COUNT(
            DISTINCT CONCAT(
                id_student,
                '|',
                course_key
            )
        ),
        '0',
        CAST(
            COUNT(*) - COUNT(
                DISTINCT CONCAT(
                    id_student,
                    '|',
                    course_key
                )
            )
            AS STRING
        )
    FROM base

    UNION ALL

    -- Required student identifier
    SELECT
        'dim_student',
        'Missing id_student',
        'NULL',
        COUNT(*),
        COUNT_IF(id_student IS NULL),
        '0',
        CAST(COUNT_IF(id_student IS NULL) AS STRING)
    FROM base

    UNION ALL

    -- Required course key
    SELECT
        'dim_student',
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
        'dim_student',
        'Student without matching course',
        'FOREIGN KEY',
        COUNT(*),
        COUNT_IF(dc.course_key IS NULL),
        '0',
        CAST(COUNT_IF(dc.course_key IS NULL) AS STRING)
    FROM base s
    LEFT JOIN oulad.oulad_gold.dim_course dc
        ON s.course_key = dc.course_key

    UNION ALL

    -- Final result validation
    SELECT
        'dim_student',
        'Invalid final_result',
        'ACCEPTED VALUE',
        COUNT(*),
        COUNT_IF(
            final_result IS NULL
            OR final_result NOT IN (
                'Distinction',
                'Pass',
                'Fail',
                'Withdrawn'
            )
        ),
        'Distinction, Pass, Fail, Withdrawn',
        CAST(
            COUNT_IF(
                final_result IS NULL
                OR final_result NOT IN (
                    'Distinction',
                    'Pass',
                    'Fail',
                    'Withdrawn'
                )
            )
            AS STRING
        )
    FROM base

    UNION ALL

    -- Gender validation
    SELECT
        'dim_student',
        'Invalid gender',
        'ACCEPTED VALUE',
        COUNT(*),
        COUNT_IF(
            gender IS NULL
            OR gender NOT IN ('M', 'F')
        ),
        'M, F',
        CAST(
            COUNT_IF(
                gender IS NULL
                OR gender NOT IN ('M', 'F')
            )
            AS STRING
        )
    FROM base

    UNION ALL

    -- Age band validation
    SELECT
        'dim_student',
        'Invalid age_band',
        'ACCEPTED VALUE',
        COUNT(*),
        COUNT_IF(
            age_band IS NULL
            OR age_band NOT IN (
                '0-35',
                '35-55',
                '55<='
            )
        ),
        '0-35, 35-55, 55<=',
        CAST(
            COUNT_IF(
                age_band IS NULL
                OR age_band NOT IN (
                    '0-35',
                    '35-55',
                    '55<='
                )
            )
            AS STRING
        )
    FROM base

    UNION ALL

    -- Disability validation
    SELECT
        'dim_student',
        'Invalid disability',
        'ACCEPTED VALUE',
        COUNT(*),
        COUNT_IF(
            disability IS NULL
            OR disability NOT IN ('Y', 'N')
        ),
        'Y, N',
        CAST(
            COUNT_IF(
                disability IS NULL
                OR disability NOT IN ('Y', 'N')
            )
            AS STRING
        )
    FROM base

    UNION ALL

    -- Previous attempts should not be negative.
    SELECT
        'dim_student',
        'Invalid previous attempts',
        'RANGE',
        COUNT(*),
        COUNT_IF(
            num_of_prev_attempts IS NULL
            OR num_of_prev_attempts < 0
        ),
        '>= 0',
        CAST(
            COUNT_IF(
                num_of_prev_attempts IS NULL
                OR num_of_prev_attempts < 0
            )
            AS STRING
        )
    FROM base

    UNION ALL

    -- Studied credits should be positive.
    SELECT
        'dim_student',
        'Invalid studied credits',
        'RANGE',
        COUNT(*),
        COUNT_IF(
            studied_credits IS NULL
            OR studied_credits <= 0
        ),
        '> 0',
        CAST(
            COUNT_IF(
                studied_credits IS NULL
                OR studied_credits <= 0
            )
            AS STRING
        )
    FROM base

    UNION ALL

    -- Silver lineage
    SELECT
        'dim_student',
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
        'dim_student',
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

        -- No actual failures means the check passes.
        WHEN failures = 0
        THEN 'PASS'

        -- Mandatory key fields: any NULL is a FAIL.
        WHEN check_type = 'NULL'
             AND check_name IN (
                 'Missing student_key',
                 'Missing id_student',
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