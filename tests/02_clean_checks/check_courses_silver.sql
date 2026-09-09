-- COURSES SILVER DATA QUALITY VALIDATION

WITH dq_results AS (

    -- Volume check
    SELECT
        'courses_silver' AS table_name,
        'Row count' AS check_name,
        'VOLUME' AS check_type,
        COUNT(*) AS records_checked,
        CASE
            WHEN COUNT(*) = 22 THEN 0
            ELSE ABS(COUNT(*) - 22)
        END AS failures,
        CASE
            WHEN COUNT(*) = 22 THEN 0.00
            ELSE ROUND(ABS(COUNT(*) - 22) / 22.0 * 100, 2)
        END AS failure_percentage,
        CASE
            WHEN COUNT(*) = 22 THEN 'PASS'
            ELSE 'FAIL'
        END AS status
    FROM oulad.oulad_silver.courses_silver


    UNION ALL


    -- Missing module
    SELECT
        'courses_silver',
        'Missing code_module',
        'NULL',
        COUNT(*),
        SUM(CASE
            WHEN code_module IS NULL OR TRIM(code_module) = '' THEN 1
            ELSE 0
        END),
        ROUND(
            SUM(CASE
                WHEN code_module IS NULL OR TRIM(code_module) = '' THEN 1
                ELSE 0
            END) / COUNT(*) * 100, 2
        ),
        CASE
            WHEN SUM(CASE
                WHEN code_module IS NULL OR TRIM(code_module) = '' THEN 1
                ELSE 0
            END) = 0
            THEN 'PASS'
            ELSE 'FAIL'
        END
    FROM oulad.oulad_silver.courses_silver


    UNION ALL


    -- Missing presentation
    SELECT
        'courses_silver',
        'Missing code_presentation',
        'NULL',
        COUNT(*),
        SUM(CASE
            WHEN code_presentation IS NULL
              OR TRIM(code_presentation) = ''
            THEN 1
            ELSE 0
        END),
        ROUND(
            SUM(CASE
                WHEN code_presentation IS NULL
                  OR TRIM(code_presentation) = ''
                THEN 1
                ELSE 0
            END) / COUNT(*) * 100, 2
        ),
        CASE
            WHEN SUM(CASE
                WHEN code_presentation IS NULL
                  OR TRIM(code_presentation) = ''
                THEN 1
                ELSE 0
            END) = 0
            THEN 'PASS'
            ELSE 'FAIL'
        END
    FROM oulad.oulad_silver.courses_silver


    UNION ALL


    -- Missing duration
    SELECT
        'courses_silver',
        'Missing module presentation length',
        'NULL',
        COUNT(*),
        SUM(CASE
            WHEN module_presentation_length IS NULL THEN 1
            ELSE 0
        END),
        ROUND(
            SUM(CASE
                WHEN module_presentation_length IS NULL THEN 1
                ELSE 0
            END) / COUNT(*) * 100, 2
        ),
        CASE
            WHEN SUM(CASE
                WHEN module_presentation_length IS NULL THEN 1
                ELSE 0
            END) = 0
            THEN 'PASS'
            ELSE 'FAIL'
        END
    FROM oulad.oulad_silver.courses_silver


    UNION ALL


    -- Positive duration
    SELECT
        'courses_silver',
        'Invalid module presentation length',
        'RANGE',
        COUNT(*),
        SUM(CASE
            WHEN module_presentation_length <= 0 THEN 1
            ELSE 0
        END),
        ROUND(
            SUM(CASE
                WHEN module_presentation_length <= 0 THEN 1
                ELSE 0
            END) / COUNT(*) * 100, 2
        ),
        CASE
            WHEN SUM(CASE
                WHEN module_presentation_length <= 0 THEN 1
                ELSE 0
            END) = 0
            THEN 'PASS'
            ELSE 'FAIL'
        END
    FROM oulad.oulad_silver.courses_silver


    UNION ALL


    -- Duplicate business key
    SELECT
        'courses_silver',
        'Duplicate course business key',
        'UNIQUE',
        COUNT(*),
        COUNT(*) - COUNT(DISTINCT
            CONCAT(code_module, '|', code_presentation)
        ),
        ROUND(
            (COUNT(*) - COUNT(DISTINCT
                CONCAT(code_module, '|', code_presentation)
            )) / COUNT(*) * 100,
            2
        ),
        CASE
            WHEN COUNT(*) = COUNT(DISTINCT
                CONCAT(code_module, '|', code_presentation)
            )
            THEN 'PASS'
            ELSE 'FAIL'
        END
    FROM oulad.oulad_silver.courses_silver


    UNION ALL


    -- Sentinel check
    SELECT
        'courses_silver',
        'Unresolved sentinel (?) values',
        'SENTINEL',
        COUNT(*),
        SUM(CASE
            WHEN code_module = '?'
              OR code_presentation = '?'
            THEN 1
            ELSE 0
        END),
        ROUND(
            SUM(CASE
                WHEN code_module = '?'
                  OR code_presentation = '?'
                THEN 1
                ELSE 0
            END) / COUNT(*) * 100,
            2
        ),
        CASE
            WHEN SUM(CASE
                WHEN code_module = '?'
                  OR code_presentation = '?'
                THEN 1
                ELSE 0
            END) = 0
            THEN 'PASS'
            ELSE 'FAIL'
        END
    FROM oulad.oulad_silver.courses_silver


    UNION ALL


    -- Standardization check
    SELECT
        'courses_silver',
        'Unstandardized module/presentation values',
        'STANDARDIZATION',
        COUNT(*),
        SUM(CASE
            WHEN code_module <> UPPER(TRIM(code_module))
              OR code_presentation <> UPPER(TRIM(code_presentation))
            THEN 1
            ELSE 0
        END),
        ROUND(
            SUM(CASE
                WHEN code_module <> UPPER(TRIM(code_module))
                  OR code_presentation <> UPPER(TRIM(code_presentation))
                THEN 1
                ELSE 0
            END) / COUNT(*) * 100,
            2
        ),
        CASE
            WHEN SUM(CASE
                WHEN code_module <> UPPER(TRIM(code_module))
                  OR code_presentation <> UPPER(TRIM(code_presentation))
                THEN 1
                ELSE 0
            END) = 0
            THEN 'PASS'
            ELSE 'FAIL'
        END
    FROM oulad.oulad_silver.courses_silver


    UNION ALL


    -- Bronze lineage
    SELECT
        'courses_silver',
        'Missing Bronze ingestion timestamp',
        'LINEAGE',
        COUNT(*),
        SUM(CASE
            WHEN bronze_ingestion_timestamp IS NULL THEN 1
            ELSE 0
        END),
        ROUND(
            SUM(CASE
                WHEN bronze_ingestion_timestamp IS NULL THEN 1
                ELSE 0
            END) / COUNT(*) * 100,
            2
        ),
        CASE
            WHEN SUM(CASE
                WHEN bronze_ingestion_timestamp IS NULL THEN 1
                ELSE 0
            END) = 0
            THEN 'PASS'
            ELSE 'FAIL'
        END
    FROM oulad.oulad_silver.courses_silver


    UNION ALL


    -- Silver processing lineage
    SELECT
        'courses_silver',
        'Missing Silver processing timestamp',
        'LINEAGE',
        COUNT(*),
        SUM(CASE
            WHEN silver_processed_timestamp IS NULL THEN 1
            ELSE 0
        END),
        ROUND(
            SUM(CASE
                WHEN silver_processed_timestamp IS NULL THEN 1
                ELSE 0
            END) / COUNT(*) * 100,
            2
        ),
        CASE
            WHEN SUM(CASE
                WHEN silver_processed_timestamp IS NULL THEN 1
                ELSE 0
            END) = 0
            THEN 'PASS'
            ELSE 'FAIL'
        END
    FROM oulad.oulad_silver.courses_silver

)

SELECT *
FROM dq_results
ORDER BY check_name;