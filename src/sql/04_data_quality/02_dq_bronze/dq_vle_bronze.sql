-- VLE BRONZE DATA QUALITY VALIDATION

WITH base AS (
    SELECT *
    FROM oulad.oulad_bronze.vle_bronze
),

run_info AS (
    SELECT
        uuid() AS run_id,
        current_timestamp() AS run_timestamp
),

course_keys AS (
    SELECT DISTINCT
        TRIM(UPPER(code_module)) AS code_module,
        TRIM(UPPER(code_presentation)) AS code_presentation
    FROM oulad.oulad_bronze.courses_bronze
),

table_count AS (
    SELECT COUNT(*) AS total_records
    FROM base
),

checks AS (

    -- Volume
    SELECT
        'VOLUME' AS dq_dimension,
        'Row count' AS rule_name,
        'INFO' AS severity,
        'EXPECTED ROW COUNT > 0' AS expected_value,
        CAST(COUNT(*) AS STRING) AS actual_value,
        COUNT(*) AS total_records,
        COUNT(*) AS passed_records,
        0 AS failed_records
    FROM base

    UNION ALL

    -- Required fields
    SELECT
        'NULL',
        'Missing code_module',
        'FAIL',
        '0% missing; mandatory key',
        CAST(COUNT_IF(code_module IS NULL) AS STRING),
        COUNT(*),
        COUNT(*) - COUNT_IF(code_module IS NULL),
        COUNT_IF(code_module IS NULL)
    FROM base

    UNION ALL

    SELECT
        'NULL',
        'Missing code_presentation',
        'FAIL',
        '0% missing; mandatory key',
        CAST(COUNT_IF(code_presentation IS NULL) AS STRING),
        COUNT(*),
        COUNT(*) - COUNT_IF(code_presentation IS NULL),
        COUNT_IF(code_presentation IS NULL)
    FROM base

    UNION ALL

    SELECT
        'NULL',
        'Missing id_site',
        'FAIL',
        '0% missing; mandatory key',
        CAST(COUNT_IF(id_site IS NULL) AS STRING),
        COUNT(*),
        COUNT(*) - COUNT_IF(id_site IS NULL),
        COUNT_IF(id_site IS NULL)
    FROM base

    UNION ALL

    SELECT
        'NULL',
        'Missing activity_type',
        'FAIL',
        '0% missing; mandatory field',
        CAST(COUNT_IF(activity_type IS NULL) AS STRING),
        COUNT(*),
        COUNT(*) - COUNT_IF(activity_type IS NULL),
        COUNT_IF(activity_type IS NULL)
    FROM base

    UNION ALL

    SELECT
        'NULL',
        'Missing week_from',
        'WARN',
        'NULL may be retained for non-timebound material',
        CAST(COUNT_IF(week_from IS NULL) AS STRING),
        COUNT(*),
        COUNT(*) - COUNT_IF(week_from IS NULL),
        COUNT_IF(week_from IS NULL)
    FROM base

    UNION ALL

    SELECT
        'NULL',
        'Missing week_to',
        'WARN',
        'NULL may be retained for non-timebound material',
        CAST(COUNT_IF(week_to IS NULL) AS STRING),
        COUNT(*),
        COUNT(*) - COUNT_IF(week_to IS NULL),
        COUNT_IF(week_to IS NULL)
    FROM base

    UNION ALL

    -- Uniqueness
    SELECT
        'UNIQUE',
        'Duplicate VLE business key',
        'FAIL',
        '0% duplicate module + presentation + id_site',
        CAST(
            COUNT(*) - COUNT(DISTINCT CONCAT(
                TRIM(UPPER(code_module)), '|',
                TRIM(UPPER(code_presentation)), '|',
                CAST(TRY_CAST(id_site AS BIGINT) AS STRING)
            ))
            AS STRING
        ),
        COUNT(*),
        COUNT(*) - (
            COUNT(*) - COUNT(DISTINCT CONCAT(
                TRIM(UPPER(code_module)), '|',
                TRIM(UPPER(code_presentation)), '|',
                CAST(TRY_CAST(id_site AS BIGINT) AS STRING)
            ))
        ),
        COUNT(*) - COUNT(DISTINCT CONCAT(
            TRIM(UPPER(code_module)), '|',
            TRIM(UPPER(code_presentation)), '|',
            CAST(TRY_CAST(id_site AS BIGINT) AS STRING)
        ))
    FROM base

    UNION ALL

    SELECT
        'UNIQUE',
        'Exact duplicate records',
        'FAIL',
        '0% exact duplicate records',
        CAST(
            COUNT(*) - COUNT(DISTINCT
                code_module,
                code_presentation,
                id_site,
                activity_type,
                week_from,
                week_to
            )
            AS STRING
        ),
        COUNT(*),
        COUNT(*) - (
            COUNT(*) - COUNT(DISTINCT
                code_module,
                code_presentation,
                id_site,
                activity_type,
                week_from,
                week_to
            )
        ),
        COUNT(*) - COUNT(DISTINCT
            code_module,
            code_presentation,
            id_site,
            activity_type,
            week_from,
            week_to
        )
    FROM base

    UNION ALL

    -- Format
    SELECT
        'FORMAT',
        'Invalid id_site format',
        'FAIL',
        'id_site must be numeric',
        CAST(COUNT_IF(
            id_site IS NOT NULL
            AND TRY_CAST(id_site AS BIGINT) IS NULL
        ) AS STRING),
        COUNT(*),
        COUNT(*) - COUNT_IF(
            id_site IS NOT NULL
            AND TRY_CAST(id_site AS BIGINT) IS NULL
        ),
        COUNT_IF(
            id_site IS NOT NULL
            AND TRY_CAST(id_site AS BIGINT) IS NULL
        )
    FROM base

    UNION ALL

    SELECT
        'FORMAT',
        'Invalid week_from format',
        'FAIL',
        'week_from must be numeric or ?',
        CAST(COUNT_IF(
            week_from IS NOT NULL
            AND TRIM(CAST(week_from AS STRING)) <> '?'
            AND TRY_CAST(week_from AS INT) IS NULL
        ) AS STRING),
        COUNT(*),
        COUNT(*) - COUNT_IF(
            week_from IS NOT NULL
            AND TRIM(CAST(week_from AS STRING)) <> '?'
            AND TRY_CAST(week_from AS INT) IS NULL
        ),
        COUNT_IF(
            week_from IS NOT NULL
            AND TRIM(CAST(week_from AS STRING)) <> '?'
            AND TRY_CAST(week_from AS INT) IS NULL
        )
    FROM base

    UNION ALL

    SELECT
        'FORMAT',
        'Invalid week_to format',
        'FAIL',
        'week_to must be numeric or ?',
        CAST(COUNT_IF(
            week_to IS NOT NULL
            AND TRIM(CAST(week_to AS STRING)) <> '?'
            AND TRY_CAST(week_to AS INT) IS NULL
        ) AS STRING),
        COUNT(*),
        COUNT(*) - COUNT_IF(
            week_to IS NOT NULL
            AND TRIM(CAST(week_to AS STRING)) <> '?'
            AND TRY_CAST(week_to AS INT) IS NULL
        ),
        COUNT_IF(
            week_to IS NOT NULL
            AND TRIM(CAST(week_to AS STRING)) <> '?'
            AND TRY_CAST(week_to AS INT) IS NULL
        )
    FROM base

    UNION ALL

    -- Range
    SELECT
        'RANGE',
        'Negative week_from',
        'FAIL',
        'week_from >= 0',
        CAST(COUNT_IF(
            TRY_CAST(NULLIF(TRIM(CAST(week_from AS STRING)), '?') AS INT) < 0
        ) AS STRING),
        COUNT(*),
        COUNT(*) - COUNT_IF(
            TRY_CAST(NULLIF(TRIM(CAST(week_from AS STRING)), '?') AS INT) < 0
        ),
        COUNT_IF(
            TRY_CAST(NULLIF(TRIM(CAST(week_from AS STRING)), '?') AS INT) < 0
        )
    FROM base

    UNION ALL

    SELECT
        'RANGE',
        'Negative week_to',
        'FAIL',
        'week_to >= 0',
        CAST(COUNT_IF(
            TRY_CAST(NULLIF(TRIM(CAST(week_to AS STRING)), '?') AS INT) < 0
        ) AS STRING),
        COUNT(*),
        COUNT(*) - COUNT_IF(
            TRY_CAST(NULLIF(TRIM(CAST(week_to AS STRING)), '?') AS INT) < 0
        ),
        COUNT_IF(
            TRY_CAST(NULLIF(TRIM(CAST(week_to AS STRING)), '?') AS INT) < 0
        )
    FROM base

    UNION ALL

    SELECT
        'RANGE',
        'week_to earlier than week_from',
        'FAIL',
        'week_to should be >= week_from',
        CAST(COUNT_IF(
            TRY_CAST(NULLIF(TRIM(CAST(week_from AS STRING)), '?') AS INT) IS NOT NULL
            AND TRY_CAST(NULLIF(TRIM(CAST(week_to AS STRING)), '?') AS INT) IS NOT NULL
            AND TRY_CAST(week_to AS INT) < TRY_CAST(week_from AS INT)
        ) AS STRING),
        COUNT(*),
        COUNT(*) - COUNT_IF(
            TRY_CAST(NULLIF(TRIM(CAST(week_from AS STRING)), '?') AS INT) IS NOT NULL
            AND TRY_CAST(NULLIF(TRIM(CAST(week_to AS STRING)), '?') AS INT) IS NOT NULL
            AND TRY_CAST(week_to AS INT) < TRY_CAST(week_from AS INT)
        ),
        COUNT_IF(
            TRY_CAST(NULLIF(TRIM(CAST(week_from AS STRING)), '?') AS INT) IS NOT NULL
            AND TRY_CAST(NULLIF(TRIM(CAST(week_to AS STRING)), '?') AS INT) IS NOT NULL
            AND TRY_CAST(week_to AS INT) < TRY_CAST(week_from AS INT)
        )
    FROM base

    UNION ALL

    -- Source sentinel
    SELECT
        'SOURCE SENTINEL',
        'Source sentinel (?) in week_from',
        'WARN',
        'Source may use ? for unavailable week_from',
        CAST(COUNT_IF(TRIM(CAST(week_from AS STRING)) = '?') AS STRING),
        COUNT(*),
        COUNT(*) - COUNT_IF(TRIM(CAST(week_from AS STRING)) = '?'),
        COUNT_IF(TRIM(CAST(week_from AS STRING)) = '?')
    FROM base

    UNION ALL

    SELECT
        'SOURCE SENTINEL',
        'Source sentinel (?) in week_to',
        'WARN',
        'Source may use ? for unavailable week_to',
        CAST(COUNT_IF(TRIM(CAST(week_to AS STRING)) = '?') AS STRING),
        COUNT(*),
        COUNT(*) - COUNT_IF(TRIM(CAST(week_to AS STRING)) = '?'),
        COUNT_IF(TRIM(CAST(week_to AS STRING)) = '?')
    FROM base

    UNION ALL

    -- Referential integrity
    SELECT
        'REFERENTIAL INTEGRITY',
        'VLE resource without matching course presentation',
        'FAIL',
        'Every code_module + code_presentation should exist in courses_bronze',
        CAST(COUNT_IF(
            c.code_module IS NULL
            OR c.code_presentation IS NULL
        ) AS STRING),
        COUNT(*),
        COUNT(*) - COUNT_IF(
            c.code_module IS NULL
            OR c.code_presentation IS NULL
        ),
        COUNT_IF(
            c.code_module IS NULL
            OR c.code_presentation IS NULL
        )
    FROM base b
    LEFT JOIN course_keys c
        ON TRIM(UPPER(b.code_module)) = c.code_module
        AND TRIM(UPPER(b.code_presentation)) = c.code_presentation
),

final_results AS (
    SELECT
        r.run_id,
        r.run_timestamp,
        'BRONZE' AS layer,
        'vle_bronze' AS table_name,

        CASE
            WHEN c.dq_dimension = 'SOURCE SENTINEL'
                THEN CASE
                    WHEN c.rule_name LIKE '%week_from%' THEN 'week_from'
                    WHEN c.rule_name LIKE '%week_to%' THEN 'week_to'
                    ELSE NULL
                END
            WHEN c.rule_name LIKE '%code_module%' THEN 'code_module'
            WHEN c.rule_name LIKE '%code_presentation%' THEN 'code_presentation'
            WHEN c.rule_name LIKE '%id_site%' THEN 'id_site'
            WHEN c.rule_name LIKE '%activity_type%' THEN 'activity_type'
            WHEN c.rule_name LIKE '%week_from%' THEN 'week_from'
            WHEN c.rule_name LIKE '%week_to%' THEN 'week_to'
            ELSE NULL
        END AS column_name,

        c.dq_dimension,
        c.rule_name,
        c.severity,
        c.expected_value,
        c.actual_value,
        c.total_records,
        c.passed_records,
        c.failed_records,

        ROUND(
            c.failed_records * 100.0 / NULLIF(c.total_records, 0),
            2
        ) AS failure_pct,

        CASE
            WHEN c.severity IN ('INFO', 'WARN') THEN NULL
            WHEN c.failed_records = 0 THEN 100.00
            ELSE ROUND(
                c.passed_records * 100.0 / NULLIF(c.total_records, 0),
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
    CROSS JOIN run_info r
)

INSERT INTO oulad.oulad_quality.dq_results
SELECT *
FROM final_results;