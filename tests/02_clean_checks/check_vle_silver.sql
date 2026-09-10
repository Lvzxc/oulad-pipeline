-- VLE SILVER DATA QUALITY VALIDATION

WITH base AS (
    SELECT *
    FROM oulad.oulad_silver.vle_silver
),

-- Silver is expected to contain fewer rows than Bronze after removing
-- records that are not needed for the Silver representation.
bronze_expectations AS (
    SELECT
        COUNT(*) AS bronze_count
    FROM oulad.oulad_bronze.vle_bronze
),

dq_results AS (

    -- Volume / row reduction check
    SELECT
        'vle_silver' AS table_name,
        'Bronze-to-Silver row reduction' AS check_name,
        'VOLUME' AS check_type,
        COUNT(*) AS records_checked,
        CASE
            WHEN COUNT(*) < e.bronze_count
            THEN 0
            ELSE ABS(COUNT(*) - e.bronze_count)
        END AS failures,
        CONCAT('< ', CAST(e.bronze_count AS STRING)) AS expected_value
    FROM base
    CROSS JOIN bronze_expectations e
    GROUP BY e.bronze_count

    UNION ALL

    -- NULL checks
    SELECT
        'vle_silver',
        'Missing id_site',
        'NULL',
        COUNT(*),
        COUNT_IF(id_site IS NULL),
        '0'
    FROM base

    UNION ALL

    SELECT
        'vle_silver',
        'Missing code_module',
        'NULL',
        COUNT(*),
        COUNT_IF(code_module IS NULL),
        '0'
    FROM base

    UNION ALL

    SELECT
        'vle_silver',
        'Missing code_presentation',
        'NULL',
        COUNT(*),
        COUNT_IF(code_presentation IS NULL),
        '0'
    FROM base

    UNION ALL

    SELECT
        'vle_silver',
        'Missing activity_type',
        'NULL',
        COUNT(*),
        COUNT_IF(activity_type IS NULL),
        '0'
    FROM base

    UNION ALL

    -- Uniqueness check
    SELECT
        'vle_silver',
        'Duplicate VLE site business key',
        'UNIQUE',
        COUNT(*),
        COUNT(*) - COUNT(DISTINCT id_site),
        '0'
    FROM base

    UNION ALL

    -- Sentinel cleanup
    SELECT
        'vle_silver',
        'Unresolved sentinel (?) values',
        'SENTINEL',
        COUNT(*),
        COUNT_IF(
            code_module = '?'
            OR code_presentation = '?'
            OR activity_type = '?'
        ),
        '0'
    FROM base

    UNION ALL

    -- Standardization
    SELECT
        'vle_silver',
        'Unstandardized module/presentation values',
        'STANDARDIZATION',
        COUNT(*),
        COUNT_IF(
            code_module <> UPPER(TRIM(code_module))
            OR code_presentation <> UPPER(TRIM(code_presentation))
            OR activity_type <> LOWER(TRIM(activity_type))
        ),
        '0'
    FROM base

    UNION ALL

    -- Course foreign key
    SELECT
        'vle_silver',
        'VLE site without matching course',
        'FOREIGN KEY',
        COUNT(*),
        COUNT_IF(c.code_module IS NULL),
        '0'
    FROM base v
    LEFT JOIN (
        SELECT DISTINCT
            code_module,
            code_presentation
        FROM oulad.oulad_silver.courses_silver
    ) c
        ON v.code_module = c.code_module
        AND v.code_presentation = c.code_presentation

    UNION ALL

    -- Lineage
    SELECT
        'vle_silver',
        'Missing ingestion timestamp',
        'LINEAGE',
        COUNT(*),
        COUNT_IF(ingestion_timestamp IS NULL),
        '0'
    FROM base

    UNION ALL

    SELECT
        'vle_silver',
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

        -- Expected row reduction means Silver can legitimately
        -- contain fewer records than Bronze.
        WHEN check_name = 'Bronze-to-Silver row reduction'
             AND records_checked < CAST(
                 REPLACE(expected_value, '< ', '') AS BIGINT
             )
        THEN 'PASS'

        -- No actual failures means the check passes.
        WHEN failures = 0
        THEN 'PASS'

        -- Mandatory key fields: any NULL is a FAIL.
        WHEN check_name IN (
            'Missing id_site',
            'Missing code_module',
            'Missing code_presentation'
        )
        THEN 'FAIL'

        -- UNIQUE / RANGE: 1% warning threshold.
        WHEN check_type IN (
            'UNIQUE',
            'RANGE'
        )
        AND failure_pct <= 1
        THEN 'WARN'

        WHEN check_type IN (
            'UNIQUE',
            'RANGE'
        )
        THEN 'FAIL'

        -- Non-key NULL: 1% warning threshold.
        WHEN check_type = 'NULL'
             AND failure_pct <= 1
        THEN 'WARN'

        WHEN check_type = 'NULL'
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

        -- Other checks: 1% warning threshold.
        WHEN check_type IN (
            'SENTINEL',
            'STANDARDIZATION',
            'LINEAGE'
        )
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