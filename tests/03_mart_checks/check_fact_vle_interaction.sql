-- FACT_VLE_INTERACTION GOLD DATA QUALITY VALIDATION

WITH base AS (
    SELECT *
    FROM oulad.oulad_gold.fact_vle_interaction
),

expectations AS (
    -- Expected fact rows come from Silver student-VLE records
    -- that successfully map to the required Gold dimensions.
    SELECT
        COUNT(*) AS expected_row_count
    FROM oulad.oulad_silver.student_vle_silver sv
    INNER JOIN oulad.oulad_gold.dim_student ds
        ON sv.id_student = ds.id_student
    INNER JOIN oulad.oulad_gold.dim_vle dv
        ON sv.id_site = dv.id_site
    INNER JOIN oulad.oulad_gold.dim_date dd
        ON sv.date = dd.date_key
),

dq_results AS (

    -- Volume
    SELECT
        'fact_vle_interaction' AS table_name,
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
        'fact_vle_interaction',
        'Missing student_key',
        'NULL',
        COUNT(*),
        COUNT_IF(student_key IS NULL),
        '0',
        CAST(COUNT_IF(student_key IS NULL) AS STRING)
    FROM base

    UNION ALL

    SELECT
        'fact_vle_interaction',
        'Missing course_key',
        'NULL',
        COUNT(*),
        COUNT_IF(course_key IS NULL),
        '0',
        CAST(COUNT_IF(course_key IS NULL) AS STRING)
    FROM base

    UNION ALL

    SELECT
        'fact_vle_interaction',
        'Missing site_key',
        'NULL',
        COUNT(*),
        COUNT_IF(site_key IS NULL),
        '0',
        CAST(COUNT_IF(site_key IS NULL) AS STRING)
    FROM base

    UNION ALL

    SELECT
        'fact_vle_interaction',
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
        'fact_vle_interaction',
        'Duplicate VLE interaction',
        'UNIQUE',
        COUNT(*),
        COUNT(*) - COUNT(
            DISTINCT CONCAT(
                student_key,
                '|',
                course_key,
                '|',
                site_key,
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
                    site_key,
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
        'fact_vle_interaction',
        'Interaction without matching student',
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
        'fact_vle_interaction',
        'Interaction without matching course',
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

    -- VLE site foreign key
    SELECT
        'fact_vle_interaction',
        'Interaction without matching VLE site',
        'FOREIGN KEY',
        COUNT(*),
        COUNT_IF(dv.site_key IS NULL),
        '0',
        CAST(
            COUNT_IF(dv.site_key IS NULL)
            AS STRING
        )
    FROM base f
    LEFT JOIN oulad.oulad_gold.dim_vle dv
        ON f.site_key = dv.site_key

    UNION ALL

    -- Date foreign key
    SELECT
        'fact_vle_interaction',
        'Interaction without matching date',
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

    -- Student-course relationship
    SELECT
        'fact_vle_interaction',
        'Student-course mismatch',
        'RELATIONSHIP',
        COUNT(*),
        COUNT_IF(ds.course_key <> f.course_key),
        '0',
        CAST(
            COUNT_IF(ds.course_key <> f.course_key)
            AS STRING
        )
    FROM base f
    JOIN oulad.oulad_gold.dim_student ds
        ON f.student_key = ds.student_key

    UNION ALL

    -- Course-site relationship
    SELECT
        'fact_vle_interaction',
        'Course-site mismatch',
        'RELATIONSHIP',
        COUNT(*),
        COUNT_IF(dv.course_key <> f.course_key),
        '0',
        CAST(
            COUNT_IF(dv.course_key <> f.course_key)
            AS STRING
        )
    FROM base f
    JOIN oulad.oulad_gold.dim_vle dv
        ON f.site_key = dv.site_key

    UNION ALL

    -- sum_click should not be negative.
    SELECT
        'fact_vle_interaction',
        'Invalid sum_click',
        'RANGE',
        COUNT(*),
        COUNT_IF(
            sum_click IS NOT NULL
            AND sum_click < 0
        ),
        '>= 0',
        CAST(
            COUNT_IF(
                sum_click IS NOT NULL
                AND sum_click < 0
            )
            AS STRING
        )
    FROM base

    UNION ALL

    -- Gold lineage
    SELECT
        'fact_vle_interaction',
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

        -- UNIQUE / RANGE
        WHEN check_type IN ('UNIQUE', 'RANGE')
             AND failure_pct <= 1
        THEN 'WARN'

        WHEN check_type IN ('UNIQUE', 'RANGE')
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