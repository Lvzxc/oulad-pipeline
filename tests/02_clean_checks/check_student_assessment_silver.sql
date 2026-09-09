-- STUDENT ASSESSMENT SILVER DATA QUALITY VALIDATION

WITH base AS (
    SELECT *
    FROM oulad.oulad_silver.student_assessment_silver
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
    -- Bronze contained 173,912 rows and all business keys were valid.
    SELECT
        'student_assessment_silver' AS table_name,
        'Row count' AS check_name,
        'VOLUME' AS check_type,
        COUNT(*) AS records_checked,
        CASE
            WHEN COUNT(*) = 173912 THEN 0
            ELSE ABS(COUNT(*) - 173912)
        END AS failures
    FROM base

    UNION ALL

    -- Required key checks
    SELECT
        'student_assessment_silver',
        'Missing id_assessment',
        'NULL',
        COUNT(*),
        COUNT_IF(id_assessment IS NULL)
    FROM base

    UNION ALL

    SELECT
        'student_assessment_silver',
        'Missing id_student',
        'NULL',
        COUNT(*),
        COUNT_IF(id_student IS NULL)
    FROM base

    UNION ALL

    -- Other field completeness checks
    SELECT
        'student_assessment_silver',
        'Missing date_submitted',
        'NULL',
        COUNT(*),
        COUNT_IF(date_submitted IS NULL)
    FROM base

    UNION ALL

    SELECT
        'student_assessment_silver',
        'Missing is_banked',
        'NULL',
        COUNT(*),
        COUNT_IF(is_banked IS NULL)
    FROM base

    UNION ALL

    -- Bronze contained 173 '?' values in score.
    -- Silver intentionally converts these to NULL.
    SELECT
        'student_assessment_silver',
        'Missing score',
        'NULL',
        COUNT(*),
        COUNT_IF(score IS NULL)
    FROM base

    UNION ALL

    -- Business grain uniqueness
    SELECT
        'student_assessment_silver',
        'Duplicate student-assessment business key',
        'UNIQUE',
        COUNT(*),
        COUNT(*) - COUNT(DISTINCT STRUCT(id_assessment, id_student))
    FROM base

    UNION ALL

    -- Score should no longer contain unresolved source sentinels.
    -- STRING casting is used only for validation across the typed Silver column.
    SELECT
        'student_assessment_silver',
        'Unresolved sentinel (?) in score',
        'SENTINEL',
        COUNT(*),
        COUNT_IF(CAST(score AS STRING) = '?')
    FROM base

    UNION ALL

    -- Score range
    SELECT
        'student_assessment_silver',
        'Score outside valid range',
        'RANGE',
        COUNT(*),
        COUNT_IF(score IS NOT NULL AND (score < 0 OR score > 100))
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
        )
    FROM base

    UNION ALL

    -- Referential integrity: assessment
    SELECT
        'student_assessment_silver',
        'Assessment without matching assessment definition',
        'FOREIGN KEY',
        COUNT(*),
        COUNT_IF(a.id_assessment IS NULL)
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
        COUNT_IF(s.id_student IS NULL)
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
        COUNT_IF(ingestion_timestamp IS NULL)
    FROM base

    UNION ALL

    SELECT
        'student_assessment_silver',
        'Missing ingestion date',
        'LINEAGE',
        COUNT(*),
        COUNT_IF(ingestion_date IS NULL)
    FROM base
)

SELECT
    table_name,
    check_name,
    check_type,
    records_checked,
    failures,
    ROUND(
        failures * 100.0 / NULLIF(records_checked, 0),
        2
    ) AS failure_percentage,

    CASE
        -- Expected volume after transformation
        WHEN check_type = 'VOLUME'
             AND failures = 0 THEN 'PASS'
        WHEN check_type = 'VOLUME'
             AND failures > 0 THEN 'FAIL'

        -- Required fields
        WHEN check_name IN (
            'Missing id_assessment',
            'Missing id_student',
            'Missing date_submitted',
            'Missing is_banked'
        )
        AND failures = 0 THEN 'PASS'
        WHEN check_name IN (
            'Missing id_assessment',
            'Missing id_student',
            'Missing date_submitted',
            'Missing is_banked'
        )
        AND failures > 0 THEN 'FAIL'

        -- Score NULLs are expected from Bronze '?' sentinel conversion.
        WHEN check_name = 'Missing score'
             AND failures = 173 THEN 'PASS'
        WHEN check_name = 'Missing score'
             AND failures <> 173 THEN 'REVIEW'

        -- These checks should have zero failures in Silver.
        WHEN check_type IN (
            'UNIQUE',
            'SENTINEL',
            'RANGE',
            'ACCEPTED VALUE',
            'FOREIGN KEY',
            'LINEAGE'
        )
        AND failures = 0 THEN 'PASS'

        WHEN check_type IN (
            'UNIQUE',
            'SENTINEL',
            'RANGE',
            'ACCEPTED VALUE',
            'FOREIGN KEY',
            'LINEAGE'
        )
        AND failures > 0 THEN 'FAIL'

        ELSE 'REVIEW'
    END AS status

FROM dq_results

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