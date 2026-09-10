-- STUDENT ASSESSMENT BRONZE DATA QUALITY VALIDATION

WITH duplicate_student_assessment AS (
    -- Duplicate student-assessment business key
    SELECT
        id_assessment,
        id_student,
        COUNT(*) AS duplicate_count
    FROM oulad.oulad_bronze.student_assessment_bronze
    GROUP BY
        id_assessment,
        id_student
    HAVING COUNT(*) > 1
),

duplicate_exact AS (
    -- Exact duplicate records
    SELECT
        id_assessment,
        id_student,
        date_submitted,
        is_banked,
        score,
        COUNT(*) AS duplicate_count
    FROM oulad.oulad_bronze.student_assessment_bronze
    GROUP BY
        id_assessment,
        id_student,
        date_submitted,
        is_banked,
        score
    HAVING COUNT(*) > 1
),

assessment_keys AS (
    -- Distinct assessment identifiers for referential integrity
    SELECT DISTINCT
        TRY_CAST(id_assessment AS BIGINT) AS id_assessment
    FROM oulad.oulad_bronze.assessment_bronze
    WHERE TRY_CAST(id_assessment AS BIGINT) IS NOT NULL
),

student_keys AS (
    -- Distinct student identifiers for referential integrity
    SELECT DISTINCT
        TRY_CAST(id_student AS BIGINT) AS id_student
    FROM oulad.oulad_bronze.student_info_bronze
    WHERE TRY_CAST(id_student AS BIGINT) IS NOT NULL
),

validation_results AS (

    -- Volume check
    SELECT
        'student_assessment_bronze' AS table_name,
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
    FROM oulad.oulad_bronze.student_assessment_bronze

    UNION ALL

    -- NULL checks
    SELECT
        'student_assessment_bronze',
        'Missing id_assessment',
        'NULL',
        COUNT(*),
        COUNT_IF(id_assessment IS NULL),
        ROUND(
            COUNT_IF(id_assessment IS NULL) * 100.0 / COUNT(*),
            2
        ),
        '0% missing; mandatory key',
        CASE
            WHEN COUNT_IF(id_assessment IS NULL) = 0 THEN 'PASS'
            ELSE 'FAIL'
        END
    FROM oulad.oulad_bronze.student_assessment_bronze

    UNION ALL

    SELECT
        'student_assessment_bronze',
        'Missing id_student',
        'NULL',
        COUNT(*),
        COUNT_IF(id_student IS NULL),
        ROUND(
            COUNT_IF(id_student IS NULL) * 100.0 / COUNT(*),
            2
        ),
        '0% missing; mandatory key',
        CASE
            WHEN COUNT_IF(id_student IS NULL) = 0 THEN 'PASS'
            ELSE 'FAIL'
        END
    FROM oulad.oulad_bronze.student_assessment_bronze

    UNION ALL

    SELECT
        'student_assessment_bronze',
        'Missing date_submitted',
        'NULL',
        COUNT(*),
        COUNT_IF(date_submitted IS NULL),
        ROUND(
            COUNT_IF(date_submitted IS NULL) * 100.0 / COUNT(*),
            2
        ),
        'Submission date should normally be populated',
        CASE
            WHEN COUNT_IF(date_submitted IS NULL) = 0 THEN 'PASS'
            WHEN COUNT_IF(date_submitted IS NULL) * 100.0 / COUNT(*) <= 1
                THEN 'WARN'
            ELSE 'FAIL'
        END
    FROM oulad.oulad_bronze.student_assessment_bronze

    UNION ALL

    SELECT
        'student_assessment_bronze',
        'Missing is_banked',
        'NULL',
        COUNT(*),
        COUNT_IF(is_banked IS NULL),
        ROUND(
            COUNT_IF(is_banked IS NULL) * 100.0 / COUNT(*),
            2
        ),
        'is_banked should be populated',
        CASE
            WHEN COUNT_IF(is_banked IS NULL) = 0 THEN 'PASS'
            WHEN COUNT_IF(is_banked IS NULL) * 100.0 / COUNT(*) <= 1
                THEN 'WARN'
            ELSE 'FAIL'
        END
    FROM oulad.oulad_bronze.student_assessment_bronze

    UNION ALL

    SELECT
        'student_assessment_bronze',
        'Missing score',
        'NULL',
        COUNT(*),
        COUNT_IF(score IS NULL),
        ROUND(
            COUNT_IF(score IS NULL) * 100.0 / COUNT(*),
            2
        ),
        'Score should normally be populated',
        CASE
            WHEN COUNT_IF(score IS NULL) = 0 THEN 'PASS'
            WHEN COUNT_IF(score IS NULL) * 100.0 / COUNT(*) <= 1
                THEN 'WARN'
            ELSE 'FAIL'
        END
    FROM oulad.oulad_bronze.student_assessment_bronze

    UNION ALL

    -- Uniqueness checks
    SELECT
        'student_assessment_bronze',
        'Duplicate student-assessment business key',
        'UNIQUE',
        COUNT(*),
        COALESCE(
            (
                SELECT SUM(duplicate_count - 1)
                FROM duplicate_student_assessment
            ),
            0
        ),
        ROUND(
            COALESCE(
                (
                    SELECT SUM(duplicate_count - 1)
                    FROM duplicate_student_assessment
                ),
                0
            ) * 100.0 / COUNT(*),
            2
        ),
        '0% duplicate id_assessment + id_student',
        CASE
            WHEN COALESCE(
                (
                    SELECT SUM(duplicate_count - 1)
                    FROM duplicate_student_assessment
                ),
                0
            ) = 0 THEN 'PASS'
            WHEN COALESCE(
                (
                    SELECT SUM(duplicate_count - 1)
                    FROM duplicate_student_assessment
                ),
                0
            ) * 100.0 / COUNT(*) <= 1 THEN 'WARN'
            ELSE 'FAIL'
        END
    FROM oulad.oulad_bronze.student_assessment_bronze

    UNION ALL

    SELECT
        'student_assessment_bronze',
        'Exact duplicate records',
        'UNIQUE',
        COUNT(*),
        COALESCE(
            (
                SELECT SUM(duplicate_count - 1)
                FROM duplicate_exact
            ),
            0
        ),
        ROUND(
            COALESCE(
                (
                    SELECT SUM(duplicate_count - 1)
                    FROM duplicate_exact
                ),
                0
            ) * 100.0 / COUNT(*),
            2
        ),
        '0% duplicate records',
        CASE
            WHEN COALESCE(
                (
                    SELECT SUM(duplicate_count - 1)
                    FROM duplicate_exact
                ),
                0
            ) = 0 THEN 'PASS'
            WHEN COALESCE(
                (
                    SELECT SUM(duplicate_count - 1)
                    FROM duplicate_exact
                ),
                0
            ) * 100.0 / COUNT(*) <= 1 THEN 'WARN'
            ELSE 'FAIL'
        END
    FROM oulad.oulad_bronze.student_assessment_bronze

    UNION ALL

    -- Type and format checks
    SELECT
        'student_assessment_bronze',
        'Invalid id_assessment format',
        'TYPE / FORMAT',
        COUNT(*),
        COUNT_IF(
            id_assessment IS NOT NULL
            AND TRY_CAST(id_assessment AS BIGINT) IS NULL
        ),
        ROUND(
            COUNT_IF(
                id_assessment IS NOT NULL
                AND TRY_CAST(id_assessment AS BIGINT) IS NULL
            ) * 100.0 / COUNT(*),
            2
        ),
        'id_assessment must be numeric',
        CASE
            WHEN COUNT_IF(
                id_assessment IS NOT NULL
                AND TRY_CAST(id_assessment AS BIGINT) IS NULL
            ) = 0 THEN 'PASS'
            WHEN COUNT_IF(
                id_assessment IS NOT NULL
                AND TRY_CAST(id_assessment AS BIGINT) IS NULL
            ) * 100.0 / COUNT(*) <= 1 THEN 'WARN'
            ELSE 'FAIL'
        END
    FROM oulad.oulad_bronze.student_assessment_bronze

    UNION ALL

    SELECT
        'student_assessment_bronze',
        'Invalid id_student format',
        'TYPE / FORMAT',
        COUNT(*),
        COUNT_IF(
            id_student IS NOT NULL
            AND TRY_CAST(id_student AS BIGINT) IS NULL
        ),
        ROUND(
            COUNT_IF(
                id_student IS NOT NULL
                AND TRY_CAST(id_student AS BIGINT) IS NULL
            ) * 100.0 / COUNT(*),
            2
        ),
        'id_student must be numeric',
        CASE
            WHEN COUNT_IF(
                id_student IS NOT NULL
                AND TRY_CAST(id_student AS BIGINT) IS NULL
            ) = 0 THEN 'PASS'
            WHEN COUNT_IF(
                id_student IS NOT NULL
                AND TRY_CAST(id_student AS BIGINT) IS NULL
            ) * 100.0 / COUNT(*) <= 1 THEN 'WARN'
            ELSE 'FAIL'
        END
    FROM oulad.oulad_bronze.student_assessment_bronze

    UNION ALL

    SELECT
        'student_assessment_bronze',
        'Invalid date_submitted format',
        'TYPE / FORMAT',
        COUNT(*),
        COUNT_IF(
            date_submitted IS NOT NULL
            AND TRY_CAST(date_submitted AS BIGINT) IS NULL
        ),
        ROUND(
            COUNT_IF(
                date_submitted IS NOT NULL
                AND TRY_CAST(date_submitted AS BIGINT) IS NULL
            ) * 100.0 / COUNT(*),
            2
        ),
        'date_submitted must be numeric',
        CASE
            WHEN COUNT_IF(
                date_submitted IS NOT NULL
                AND TRY_CAST(date_submitted AS BIGINT) IS NULL
            ) = 0 THEN 'PASS'
            WHEN COUNT_IF(
                date_submitted IS NOT NULL
                AND TRY_CAST(date_submitted AS BIGINT) IS NULL
            ) * 100.0 / COUNT(*) <= 1 THEN 'WARN'
            ELSE 'FAIL'
        END
    FROM oulad.oulad_bronze.student_assessment_bronze

    UNION ALL

    SELECT
        'student_assessment_bronze',
        'Invalid is_banked format',
        'TYPE / FORMAT',
        COUNT(*),
        COUNT_IF(
            is_banked IS NOT NULL
            AND TRY_CAST(is_banked AS INT) IS NULL
        ),
        ROUND(
            COUNT_IF(
                is_banked IS NOT NULL
                AND TRY_CAST(is_banked AS INT) IS NULL
            ) * 100.0 / COUNT(*),
            2
        ),
        'is_banked must be numeric',
        CASE
            WHEN COUNT_IF(
                is_banked IS NOT NULL
                AND TRY_CAST(is_banked AS INT) IS NULL
            ) = 0 THEN 'PASS'
            WHEN COUNT_IF(
                is_banked IS NOT NULL
                AND TRY_CAST(is_banked AS INT) IS NULL
            ) * 100.0 / COUNT(*) <= 1 THEN 'WARN'
            ELSE 'FAIL'
        END
    FROM oulad.oulad_bronze.student_assessment_bronze

    UNION ALL

    -- Source sentinel check
    SELECT
        'student_assessment_bronze',
        'Source sentinel (?) in score',
        'SENTINEL',
        COUNT(*),
        COUNT_IF(score = '?'),
        ROUND(
            COUNT_IF(score = '?') * 100.0 / COUNT(*),
            2
        ),
        'Source may use ? for unavailable score',
        CASE
            WHEN COUNT_IF(score = '?') = 0 THEN 'PASS'
            ELSE 'WARN'
        END
    FROM oulad.oulad_bronze.student_assessment_bronze

    UNION ALL

    -- Score range check
    SELECT
        'student_assessment_bronze',
        'Score outside valid range',
        'RANGE',
        COUNT(*),
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
        '0 <= score <= 100',
        CASE
            WHEN COUNT_IF(
                TRY_CAST(score AS DOUBLE) IS NOT NULL
                AND (
                    TRY_CAST(score AS DOUBLE) < 0
                    OR TRY_CAST(score AS DOUBLE) > 100
                )
            ) = 0 THEN 'PASS'
            WHEN COUNT_IF(
                TRY_CAST(score AS DOUBLE) IS NOT NULL
                AND (
                    TRY_CAST(score AS DOUBLE) < 0
                    OR TRY_CAST(score AS DOUBLE) > 100
                )
            ) * 100.0 / COUNT(*) <= 1 THEN 'WARN'
            ELSE 'FAIL'
        END
    FROM oulad.oulad_bronze.student_assessment_bronze

    UNION ALL

    -- Accepted value check
    SELECT
        'student_assessment_bronze',
        'Invalid is_banked value',
        'ACCEPTED VALUE',
        COUNT(*),
        COUNT_IF(
            TRY_CAST(is_banked AS INT) IS NOT NULL
            AND TRY_CAST(is_banked AS INT) NOT IN (0, 1)
        ),
        ROUND(
            COUNT_IF(
                TRY_CAST(is_banked AS INT) IS NOT NULL
                AND TRY_CAST(is_banked AS INT) NOT IN (0, 1)
            ) * 100.0 / COUNT(*),
            2
        ),
        'is_banked must be 0 or 1',
        CASE
            WHEN COUNT_IF(
                TRY_CAST(is_banked AS INT) IS NOT NULL
                AND TRY_CAST(is_banked AS INT) NOT IN (0, 1)
            ) = 0 THEN 'PASS'
            WHEN COUNT_IF(
                TRY_CAST(is_banked AS INT) IS NOT NULL
                AND TRY_CAST(is_banked AS INT) NOT IN (0, 1)
            ) * 100.0 / COUNT(*) <= 1 THEN 'WARN'
            ELSE 'FAIL'
        END
    FROM oulad.oulad_bronze.student_assessment_bronze

    UNION ALL

    -- Foreign key check to assessments
    SELECT
        'student_assessment_bronze',
        'Assessment without matching assessment definition',
        'FOREIGN KEY',
        COUNT(*),
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
        'Every id_assessment should exist in assessment_bronze',
        CASE
            WHEN COUNT_IF(
                sa.id_assessment IS NOT NULL
                AND ak.id_assessment IS NULL
            ) = 0 THEN 'PASS'
            WHEN COUNT_IF(
                sa.id_assessment IS NOT NULL
                AND ak.id_assessment IS NULL
            ) * 100.0 / COUNT(*) <= 0.1 THEN 'WARN'
            ELSE 'FAIL'
        END
    FROM oulad.oulad_bronze.student_assessment_bronze sa
    LEFT JOIN assessment_keys ak
        ON TRY_CAST(sa.id_assessment AS BIGINT) = ak.id_assessment

    UNION ALL

    -- Foreign key check to student information
    SELECT
        'student_assessment_bronze',
        'Assessment without matching student',
        'FOREIGN KEY',
        COUNT(*),
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
        'Every id_student should exist in student_info_bronze',
        CASE
            WHEN COUNT_IF(
                sa.id_student IS NOT NULL
                AND sk.id_student IS NULL
            ) = 0 THEN 'PASS'
            WHEN COUNT_IF(
                sa.id_student IS NOT NULL
                AND sk.id_student IS NULL
            ) * 100.0 / COUNT(*) <= 0.1 THEN 'WARN'
            ELSE 'FAIL'
        END
    FROM oulad.oulad_bronze.student_assessment_bronze sa
    LEFT JOIN student_keys sk
        ON TRY_CAST(sa.id_student AS BIGINT) = sk.id_student
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
        WHEN 'SENTINEL' THEN 5
        WHEN 'RANGE' THEN 6
        WHEN 'ACCEPTED VALUE' THEN 7
        WHEN 'FOREIGN KEY' THEN 8
        ELSE 9
    END,
    check_name;