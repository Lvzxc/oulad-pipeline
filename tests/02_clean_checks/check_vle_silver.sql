-- VLE SILVER DATA QUALITY VALIDATION

WITH checks AS (

    -- Volume / deduplication check
    SELECT
        'vle_silver' AS table_name,
        'Bronze-to-Silver row reduction' AS check_name,
        'VOLUME' AS check_type,
        COUNT(*) AS records_checked,
        CASE
            WHEN COUNT(*) <
                 (SELECT COUNT(*)
                  FROM oulad.oulad_bronze.vle_bronze)
            THEN 0
            ELSE 1
        END AS failures
    FROM oulad.oulad_silver.vle_silver

    UNION ALL

    -- NULL checks
    SELECT
        'vle_silver',
        'Missing id_site',
        'NULL',
        COUNT(*),
        SUM(CASE WHEN id_site IS NULL THEN 1 ELSE 0 END)
    FROM oulad.oulad_silver.vle_silver

    UNION ALL

    SELECT
        'vle_silver',
        'Missing code_module',
        'NULL',
        COUNT(*),
        SUM(CASE WHEN code_module IS NULL THEN 1 ELSE 0 END)
    FROM oulad.oulad_silver.vle_silver

    UNION ALL

    SELECT
        'vle_silver',
        'Missing code_presentation',
        'NULL',
        COUNT(*),
        SUM(CASE WHEN code_presentation IS NULL THEN 1 ELSE 0 END)
    FROM oulad.oulad_silver.vle_silver

    UNION ALL

    SELECT
        'vle_silver',
        'Missing activity_type',
        'NULL',
        COUNT(*),
        SUM(CASE WHEN activity_type IS NULL THEN 1 ELSE 0 END)
    FROM oulad.oulad_silver.vle_silver

    UNION ALL

    -- Uniqueness check
    SELECT
        'vle_silver',
        'Duplicate VLE site business key',
        'UNIQUE',
        COUNT(*),
        COUNT(*) - COUNT(DISTINCT id_site)
    FROM oulad.oulad_silver.vle_silver

    UNION ALL

    -- Sentinel cleanup
    SELECT
        'vle_silver',
        'Unresolved sentinel (?) values',
        'SENTINEL',
        COUNT(*),
        SUM(
            CASE
                WHEN code_module = '?'
                  OR code_presentation = '?'
                  OR activity_type = '?'
                THEN 1
                ELSE 0
            END
        )
    FROM oulad.oulad_silver.vle_silver

    UNION ALL

    -- Standardization
    SELECT
        'vle_silver',
        'Unstandardized module/presentation values',
        'STANDARDIZATION',
        COUNT(*),
        SUM(
            CASE
                WHEN code_module <> UPPER(TRIM(code_module))
                  OR code_presentation <> UPPER(TRIM(code_presentation))
                  OR activity_type <> LOWER(TRIM(activity_type))
                THEN 1
                ELSE 0
            END
        )
    FROM oulad.oulad_silver.vle_silver

    UNION ALL

    -- Course foreign key
    SELECT
        'vle_silver',
        'VLE site without matching course',
        'FOREIGN KEY',
        COUNT(*),
        COUNT(*)
    FROM oulad.oulad_silver.vle_silver v
    LEFT JOIN oulad.oulad_silver.courses_silver c
        ON v.code_module = c.code_module
        AND v.code_presentation = c.code_presentation
    WHERE c.code_module IS NULL

    UNION ALL

    -- Lineage
    SELECT
        'vle_silver',
        'Missing ingestion timestamp',
        'LINEAGE',
        COUNT(*),
        SUM(
            CASE
                WHEN ingestion_timestamp IS NULL THEN 1
                ELSE 0
            END
        )
    FROM oulad.oulad_silver.vle_silver

    UNION ALL

    SELECT
        'vle_silver',
        'Missing ingestion date',
        'LINEAGE',
        COUNT(*),
        SUM(
            CASE
                WHEN ingestion_date IS NULL THEN 1
                ELSE 0
            END
        )
    FROM oulad.oulad_silver.vle_silver
)

SELECT
    table_name,
    check_name,
    check_type,
    records_checked,
    failures,

    ROUND(
        failures * 100.0 /
        NULLIF(records_checked, 0),
        2
    ) AS failure_percentage,

    CASE
        WHEN failures = 0 THEN 'PASS'
        WHEN failures * 100.0 /
             NULLIF(records_checked, 0) <= 1
            THEN 'WARN'
        ELSE 'FAIL'
    END AS status

FROM checks

ORDER BY
    CASE
        WHEN status = 'FAIL' THEN 1
        WHEN status = 'WARN' THEN 2
        ELSE 3
    END,
    check_type,
    check_name;