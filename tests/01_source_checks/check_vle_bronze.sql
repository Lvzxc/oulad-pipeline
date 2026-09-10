-- VLE BRONZE DATA QUALITY VALIDATION

WITH base AS (
    SELECT *
    FROM oulad.oulad_bronze.vle_bronze
),

course_keys AS (
    SELECT DISTINCT
        TRIM(UPPER(code_module)) AS code_module,
        TRIM(UPPER(code_presentation)) AS code_presentation
    FROM oulad.oulad_bronze.courses_bronze
),

dq_results AS (

    -- Volume check
    SELECT
        'vle_bronze' AS table_name,
        'Row count' AS check_name,
        'VOLUME' AS dq_category,
        COUNT(*) AS total_rows,
        CASE
            WHEN COUNT(*) = 0 THEN 1
            ELSE 0
        END AS failed_rows,
        CASE
            WHEN COUNT(*) = 0 THEN 100.00
            ELSE 0.00
        END AS failure_pct,
        'Table should contain records' AS expected_value
    FROM base

    UNION ALL

    -- NULL checks
    SELECT
        'vle_bronze',
        'Missing code_module',
        'NULL',
        COUNT(*),
        COUNT_IF(code_module IS NULL),
        ROUND(COUNT_IF(code_module IS NULL) * 100.0 / COUNT(*), 2),
        '0% missing; mandatory key'
    FROM base

    UNION ALL

    SELECT
        'vle_bronze',
        'Missing code_presentation',
        'NULL',
        COUNT(*),
        COUNT_IF(code_presentation IS NULL),
        ROUND(COUNT_IF(code_presentation IS NULL) * 100.0 / COUNT(*), 2),
        '0% missing; mandatory key'
    FROM base

    UNION ALL

    SELECT
        'vle_bronze',
        'Missing id_site',
        'NULL',
        COUNT(*),
        COUNT_IF(id_site IS NULL),
        ROUND(COUNT_IF(id_site IS NULL) * 100.0 / COUNT(*), 2),
        '0% missing; mandatory key'
    FROM base

    UNION ALL

    SELECT
        'vle_bronze',
        'Missing activity_type',
        'NULL',
        COUNT(*),
        COUNT_IF(activity_type IS NULL),
        ROUND(COUNT_IF(activity_type IS NULL) * 100.0 / COUNT(*), 2),
        '0% missing; mandatory field'
    FROM base

    UNION ALL

    SELECT
        'vle_bronze',
        'Missing week_from',
        'NULL',
        COUNT(*),
        COUNT_IF(week_from IS NULL),
        ROUND(COUNT_IF(week_from IS NULL) * 100.0 / COUNT(*), 2),
        'NULL may be retained for non-timebound material'
    FROM base

    UNION ALL

    SELECT
        'vle_bronze',
        'Missing week_to',
        'NULL',
        COUNT(*),
        COUNT_IF(week_to IS NULL),
        ROUND(COUNT_IF(week_to IS NULL) * 100.0 / COUNT(*), 2),
        'NULL may be retained for non-timebound material'
    FROM base

    UNION ALL

    -- Uniqueness checks
    SELECT
        'vle_bronze',
        'Duplicate VLE business key',
        'UNIQUE',
        COUNT(*),
        COUNT(*) - COUNT(DISTINCT CONCAT(
            TRIM(UPPER(code_module)), '|',
            TRIM(UPPER(code_presentation)), '|',
            CAST(TRY_CAST(id_site AS BIGINT) AS STRING)
        )),
        ROUND(
            (
                COUNT(*) - COUNT(DISTINCT CONCAT(
                    TRIM(UPPER(code_module)), '|',
                    TRIM(UPPER(code_presentation)), '|',
                    CAST(TRY_CAST(id_site AS BIGINT) AS STRING)
                ))
            ) * 100.0 / COUNT(*),
            2
        ),
        '0% duplicate module + presentation + id_site'
    FROM base

    UNION ALL

    SELECT
        'vle_bronze',
        'Exact duplicate records',
        'UNIQUE',
        COUNT(*),
        COUNT(*) - COUNT(DISTINCT
            code_module,
            code_presentation,
            id_site,
            activity_type,
            week_from,
            week_to
        ),
        ROUND(
            (
                COUNT(*) - COUNT(DISTINCT
                    code_module,
                    code_presentation,
                    id_site,
                    activity_type,
                    week_from,
                    week_to
                )
            ) * 100.0 / COUNT(*),
            2
        ),
        '0% exact duplicate records'
    FROM base

    UNION ALL

    -- Type and format checks
    SELECT
        'vle_bronze',
        'Invalid id_site format',
        'TYPE / FORMAT',
        COUNT(*),
        COUNT_IF(
            id_site IS NOT NULL
            AND TRY_CAST(id_site AS BIGINT) IS NULL
        ),
        ROUND(
            COUNT_IF(
                id_site IS NOT NULL
                AND TRY_CAST(id_site AS BIGINT) IS NULL
            ) * 100.0 / COUNT(*),
            2
        ),
        'id_site must be numeric'
    FROM base

    UNION ALL

    SELECT
        'vle_bronze',
        'Invalid week_from format',
        'TYPE / FORMAT',
        COUNT(*),
        COUNT_IF(
            week_from IS NOT NULL
            AND TRIM(CAST(week_from AS STRING)) <> '?'
            AND TRY_CAST(week_from AS INT) IS NULL
        ),
        ROUND(
            COUNT_IF(
                week_from IS NOT NULL
                AND TRIM(CAST(week_from AS STRING)) <> '?'
                AND TRY_CAST(week_from AS INT) IS NULL
            ) * 100.0 / COUNT(*),
            2
        ),
        'week_from must be numeric or ?'
    FROM base

    UNION ALL

    SELECT
        'vle_bronze',
        'Invalid week_to format',
        'TYPE / FORMAT',
        COUNT(*),
        COUNT_IF(
            week_to IS NOT NULL
            AND TRIM(CAST(week_to AS STRING)) <> '?'
            AND TRY_CAST(week_to AS INT) IS NULL
        ),
        ROUND(
            COUNT_IF(
                week_to IS NOT NULL
                AND TRIM(CAST(week_to AS STRING)) <> '?'
                AND TRY_CAST(week_to AS INT) IS NULL
            ) * 100.0 / COUNT(*),
            2
        ),
        'week_to must be numeric or ?'
    FROM base

    UNION ALL

    -- Range checks
    SELECT
        'vle_bronze',
        'Negative week_from',
        'RANGE',
        COUNT(*),
        COUNT_IF(
            TRY_CAST(NULLIF(TRIM(CAST(week_from AS STRING)), '?') AS INT) < 0
        ),
        ROUND(
            COUNT_IF(
                TRY_CAST(NULLIF(TRIM(CAST(week_from AS STRING)), '?') AS INT) < 0
            ) * 100.0 / COUNT(*),
            2
        ),
        'week_from >= 0'
    FROM base

    UNION ALL

    SELECT
        'vle_bronze',
        'Negative week_to',
        'RANGE',
        COUNT(*),
        COUNT_IF(
            TRY_CAST(NULLIF(TRIM(CAST(week_to AS STRING)), '?') AS INT) < 0
        ),
        ROUND(
            COUNT_IF(
                TRY_CAST(NULLIF(TRIM(CAST(week_to AS STRING)), '?') AS INT) < 0
            ) * 100.0 / COUNT(*),
            2
        ),
        'week_to >= 0'
    FROM base

    UNION ALL

    SELECT
        'vle_bronze',
        'week_to earlier than week_from',
        'RANGE',
        COUNT(*),
        COUNT_IF(
            TRY_CAST(NULLIF(TRIM(CAST(week_from AS STRING)), '?') AS INT) IS NOT NULL
            AND TRY_CAST(NULLIF(TRIM(CAST(week_to AS STRING)), '?') AS INT) IS NOT NULL
            AND TRY_CAST(week_to AS INT) < TRY_CAST(week_from AS INT)
        ),
        ROUND(
            COUNT_IF(
                TRY_CAST(NULLIF(TRIM(CAST(week_from AS STRING)), '?') AS INT) IS NOT NULL
                AND TRY_CAST(NULLIF(TRIM(CAST(week_to AS STRING)), '?') AS INT) IS NOT NULL
                AND TRY_CAST(week_to AS INT) < TRY_CAST(week_from AS INT)
            ) * 100.0 / COUNT(*),
            2
        ),
        'week_to should be >= week_from'
    FROM base

    UNION ALL

    -- Source sentinel checks
    SELECT
        'vle_bronze',
        'Source sentinel (?) in week_from',
        'SENTINEL',
        COUNT(*),
        COUNT_IF(TRIM(CAST(week_from AS STRING)) = '?'),
        ROUND(
            COUNT_IF(TRIM(CAST(week_from AS STRING)) = '?')
            * 100.0 / COUNT(*),
            2
        ),
        'Source may use ? for unavailable week_from'
    FROM base

    UNION ALL

    SELECT
        'vle_bronze',
        'Source sentinel (?) in week_to',
        'SENTINEL',
        COUNT(*),
        COUNT_IF(TRIM(CAST(week_to AS STRING)) = '?'),
        ROUND(
            COUNT_IF(TRIM(CAST(week_to AS STRING)) = '?')
            * 100.0 / COUNT(*),
            2
        ),
        'Source may use ? for unavailable week_to'
    FROM base

    UNION ALL

    -- Referential integrity
    SELECT
        'vle_bronze',
        'VLE resource without matching course presentation',
        'FOREIGN KEY',
        COUNT(*),
        COUNT_IF(
            c.code_module IS NULL
            OR c.code_presentation IS NULL
        ),
        ROUND(
            COUNT_IF(
                c.code_module IS NULL
                OR c.code_presentation IS NULL
            ) * 100.0 / COUNT(*),
            2
        ),
        'Every code_module + code_presentation should exist in courses_bronze'
    FROM base b
    LEFT JOIN course_keys c
        ON TRIM(UPPER(b.code_module)) = c.code_module
        AND TRIM(UPPER(b.code_presentation)) = c.code_presentation
)

SELECT
    table_name,
    check_name,
    dq_category,
    total_rows,
    failed_rows,
    failure_pct,
    expected_value,

    CASE
        WHEN dq_category = 'VOLUME'
             AND failed_rows = 0 THEN 'PASS'

        WHEN dq_category = 'VOLUME'
             AND failed_rows > 0 THEN 'FAIL'

        WHEN dq_category = 'NULL'
             AND failed_rows = 0 THEN 'PASS'

        WHEN dq_category = 'NULL'
             AND failed_rows > 0 THEN 'WARN'

        WHEN dq_category = 'UNIQUE'
             AND failure_pct = 0 THEN 'PASS'

        WHEN dq_category = 'UNIQUE'
             AND failure_pct <= 1 THEN 'WARN'

        WHEN dq_category = 'UNIQUE'
             AND failure_pct > 1 THEN 'FAIL'

        WHEN dq_category = 'TYPE / FORMAT'
             AND failed_rows = 0 THEN 'PASS'

        WHEN dq_category = 'TYPE / FORMAT'
             AND failed_rows > 0 THEN 'FAIL'

        WHEN dq_category = 'RANGE'
             AND failed_rows = 0 THEN 'PASS'

        WHEN dq_category = 'RANGE'
             AND failure_pct <= 1 THEN 'WARN'

        WHEN dq_category = 'RANGE'
             AND failure_pct > 1 THEN 'FAIL'

        WHEN dq_category = 'SENTINEL'
             AND failed_rows = 0 THEN 'PASS'

        WHEN dq_category = 'SENTINEL'
             AND failed_rows > 0 THEN 'WARN'

        WHEN dq_category = 'FOREIGN KEY'
             AND failed_rows = 0 THEN 'PASS'

        WHEN dq_category = 'FOREIGN KEY'
             AND failure_pct <= 0.1 THEN 'WARN'

        WHEN dq_category = 'FOREIGN KEY'
             AND failure_pct > 0.1 THEN 'FAIL'

        ELSE 'REVIEW'
    END AS status

FROM dq_results

ORDER BY
    CASE dq_category
        WHEN 'VOLUME' THEN 1
        WHEN 'NULL' THEN 2
        WHEN 'UNIQUE' THEN 3
        WHEN 'TYPE / FORMAT' THEN 4
        WHEN 'RANGE' THEN 5
        WHEN 'SENTINEL' THEN 6
        WHEN 'FOREIGN KEY' THEN 7
        ELSE 8
    END,
    check_name;