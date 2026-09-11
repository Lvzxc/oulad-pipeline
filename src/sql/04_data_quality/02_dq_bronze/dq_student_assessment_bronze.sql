-- STUDENT ASSESSMENT BRONZE DATA QUALITY VALIDATION

WITH run_info AS (
    SELECT
        uuid() AS run_id,
        current_timestamp() AS run_timestamp
),

base AS (
    SELECT *
    FROM oulad.oulad_bronze.student_assessment_bronze
),

duplicate_student_assessment AS (
    SELECT
        id_assessment,
        id_student,
        COUNT(*) AS duplicate_count
    FROM base
    GROUP BY
        id_assessment,
        id_student
    HAVING COUNT(*) > 1
),

duplicate_exact AS (
    SELECT
        id_assessment,
        id_student,
        date_submitted,
        is_banked,
        score,
        COUNT(*) AS duplicate_count
    FROM base
    GROUP BY
        id_assessment,
        id_student,
        date_submitted,
        is_banked,
        score
    HAVING COUNT(*) > 1
),

assessment_keys AS (
    SELECT DISTINCT
        id_assessment
    FROM oulad.oulad_bronze.assessment_bronze
    WHERE id_assessment IS NOT NULL
),

student_keys AS (
    SELECT DISTINCT
        id_student
    FROM oulad.oulad_bronze.student_info_bronze
    WHERE id_student IS NOT NULL
),

table_count AS (
    SELECT COUNT(*) AS total_records
    FROM base
),

checks AS (

    -- Volume
    SELECT
        'student_assessment_bronze' AS table_name,
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
        'student_assessment_bronze',
        'id_assessment',
        'NULL',
        'id_assessment is mandatory',
        'FAIL',
        '0% missing',
        CAST(COUNT_IF(id_assessment IS NULL) AS STRING),
        COUNT(*),
        COUNT(*) - COUNT_IF(id_assessment IS NULL),
        COUNT_IF(id_assessment IS NULL),
        ROUND(COUNT_IF(id_assessment IS NULL) * 100.0 / COUNT(*), 2),
        ROUND(
            (COUNT(*) - COUNT_IF(id_assessment IS NULL))
            * 100.0 / COUNT(*),
            2
        )
    FROM base

    UNION ALL

    SELECT
        'student_assessment_bronze',
        'id_student',
        'NULL',
        'id_student is mandatory',
        'FAIL',
        '0% missing',
        CAST(COUNT_IF(id_student IS NULL) AS STRING),
        COUNT(*),
        COUNT(*) - COUNT_IF(id_student IS NULL),
        COUNT_IF(id_student IS NULL),
        ROUND(COUNT_IF(id_student IS NULL) * 100.0 / COUNT(*), 2),
        ROUND(
            (COUNT(*) - COUNT_IF(id_student IS NULL))
            * 100.0 / COUNT(*),
            2
        )
    FROM base

    UNION ALL

    SELECT
        'student_assessment_bronze',
        'date_submitted',
        'NULL',
        'Submission date should normally be populated',
        'FAIL',
        '0% missing',
        CAST(COUNT_IF(date_submitted IS NULL) AS STRING),
        COUNT(*),
        COUNT(*) - COUNT_IF(date_submitted IS NULL),
        COUNT_IF(date_submitted IS NULL),
        ROUND(COUNT_IF(date_submitted IS NULL) * 100.0 / COUNT(*), 2),
        ROUND(
            (COUNT(*) - COUNT_IF(date_submitted IS NULL))
            * 100.0 / COUNT(*),
            2
        )
    FROM base

    UNION ALL

    SELECT
        'student_assessment_bronze',
        'is_banked',
        'NULL',
        'is_banked should be populated',
        'FAIL',
        '0% missing',
        CAST(COUNT_IF(is_banked IS NULL) AS STRING),
        COUNT(*),
        COUNT(*) - COUNT_IF(is_banked IS NULL),
        COUNT_IF(is_banked IS NULL),
        ROUND(COUNT_IF(is_banked IS NULL) * 100.0 / COUNT(*), 2),
        ROUND(
            (COUNT(*) - COUNT_IF(is_banked IS NULL))
            * 100.0 / COUNT(*),
            2
        )
    FROM base

    UNION ALL

    SELECT
        'student_assessment_bronze',
        'score',
        'NULL',
        'Score should normally be populated',
        'FAIL',
        '0% missing',
        CAST(COUNT_IF(score IS NULL) AS STRING),
        COUNT(*),
        COUNT(*) - COUNT_IF(score IS NULL),
        COUNT_IF(score IS NULL),
        ROUND(COUNT_IF(score IS NULL) * 100.0 / COUNT(*), 2),
        ROUND(
            (COUNT(*) - COUNT_IF(score IS NULL))
            * 100.0 / COUNT(*),
            2
        )
    FROM base

    UNION ALL

    -- Business key uniqueness
    SELECT
        'student_assessment_bronze',
        'id_assessment + id_student',
        'UNIQUE',
        'Student-assessment business key must be unique',
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
    LEFT JOIN duplicate_student_assessment d
        ON TRUE
    GROUP BY tc.total_records

    UNION ALL

    -- Exact duplicates
    SELECT
        'student_assessment_bronze',
        'Full student-assessment record',
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

    -- Source sentinel
    SELECT
        'student_assessment_bronze',
        'score',
        'SOURCE SENTINEL',
        'Source may use ? for unavailable score',
        'WARN',
        'No ? values required',
        CAST(COUNT_IF(score = '?') AS STRING),
        COUNT(*),
        COUNT(*) - COUNT_IF(score = '?'),
        COUNT_IF(score = '?'),
        ROUND(
            COUNT_IF(score = '?') * 100.0 / COUNT(*),
            2
        ),
        CAST(NULL AS DOUBLE)
    FROM base

    UNION ALL

    -- Score range
    SELECT
        'student_assessment_bronze',
        'score',
        'RANGE',
        'Score must be between 0 and 100',
        'FAIL',
        '0 <= score <= 100',
        CAST(COUNT_IF(
            TRY_CAST(score AS DOUBLE) IS NOT NULL
            AND (
                TRY_CAST(score AS DOUBLE) < 0
                OR TRY_CAST(score AS DOUBLE) > 100
            )
        ) AS STRING),
        COUNT(*),
        COUNT(*) - COUNT_IF(
            TRY_CAST(score AS DOUBLE) IS NOT NULL
            AND (
                TRY_CAST(score AS DOUBLE) < 0
                OR TRY_CAST(score AS DOUBLE) > 100
            )
        ),
        COUNT_IF(
            TRY_CAST(score AS DOUBLE) IS NOT NULL
            AND (
                TRY_CAST(score AS DOUBLE) < 0
                OR TRY_CAST(score AS DOUBLE) > 100
            )
        ),
        ROUND(
            COUNT_IF(
                TRY_CAST(score AS DOUBLE) IS NOT NULL
                AND (
                    TRY_CAST(score AS DOUBLE) < 0
                    OR TRY_CAST(score AS DOUBLE) > 100
                )
            ) * 100.0 / COUNT(*),
            2
        ),
        ROUND(
            (
                COUNT(*) - COUNT_IF(
                    TRY_CAST(score AS DOUBLE) IS NOT NULL
                    AND (
                        TRY_CAST(score AS DOUBLE) < 0
                        OR TRY_CAST(score AS DOUBLE) > 100
                    )
                )
            ) * 100.0 / COUNT(*),
            2
        )
    FROM base

    UNION ALL

    -- Accepted values
    SELECT
        'student_assessment_bronze',
        'is_banked',
        'ACCEPTED VALUE',
        'is_banked must be 0 or 1',
        'FAIL',
        '0 or 1',
        CAST(COUNT_IF(
            is_banked IS NOT NULL
            AND is_banked NOT IN (0, 1)
        ) AS STRING),
        COUNT(*),
        COUNT(*) - COUNT_IF(
            is_banked IS NOT NULL
            AND is_banked NOT IN (0, 1)
        ),
        COUNT_IF(
            is_banked IS NOT NULL
            AND is_banked NOT IN (0, 1)
        ),
        ROUND(
            COUNT_IF(
                is_banked IS NOT NULL
                AND is_banked NOT IN (0, 1)
            ) * 100.0 / COUNT(*),
            2
        ),
        ROUND(
            (
                COUNT(*) - COUNT_IF(
                    is_banked IS NOT NULL
                    AND is_banked NOT IN (0, 1)
                )
            ) * 100.0 / COUNT(*),
            2
        )
    FROM base

    UNION ALL

    -- Assessment referential integrity
    SELECT
        'student_assessment_bronze',
        'id_assessment',
        'REFERENTIAL INTEGRITY',
        'Every id_assessment must exist in assessment_bronze',
        'FAIL',
        '0 unmatched assessments',
        CAST(COUNT_IF(
            sa.id_assessment IS NOT NULL
            AND ak.id_assessment IS NULL
        ) AS STRING),
        COUNT(*),
        COUNT(*) - COUNT_IF(
            sa.id_assessment IS NOT NULL
            AND ak.id_assessment IS NULL
        ),
        COUNT_IF(
            sa.id_assessment IS NOT NULL
            AND ak.id_assessment IS NULL
        ),
        ROUND(
            COUNT_IF(
                sa.id_assessment IS NOT NULL
                AND ak.id_assessment IS NULL
            ) * 100.0 / COUNT(*),
            2
        ),
        ROUND(
            (
                COUNT(*) - COUNT_IF(
                    sa.id_assessment IS NOT NULL
                    AND ak.id_assessment IS NULL
                )
            ) * 100.0 / COUNT(*),
            2
        )
    FROM base sa
    LEFT JOIN assessment_keys ak
        ON sa.id_assessment = ak.id_assessment

    UNION ALL

    -- Student referential integrity
    SELECT
        'student_assessment_bronze',
        'id_student',
        'REFERENTIAL INTEGRITY',
        'Every id_student must exist in student_info_bronze',
        'FAIL',
        '0 unmatched students',
        CAST(COUNT_IF(
            sa.id_student IS NOT NULL
            AND sk.id_student IS NULL
        ) AS STRING),
        COUNT(*),
        COUNT(*) - COUNT_IF(
            sa.id_student IS NOT NULL
            AND sk.id_student IS NULL
        ),
        COUNT_IF(
            sa.id_student IS NOT NULL
            AND sk.id_student IS NULL
        ),
        ROUND(
            COUNT_IF(
                sa.id_student IS NOT NULL
                AND sk.id_student IS NULL
            ) * 100.0 / COUNT(*),
            2
        ),
        ROUND(
            (
                COUNT(*) - COUNT_IF(
                    sa.id_student IS NOT NULL
                    AND sk.id_student IS NULL
                )
            ) * 100.0 / COUNT(*),
            2
        )
    FROM base sa
    LEFT JOIN student_keys sk
        ON sa.id_student = sk.id_student
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