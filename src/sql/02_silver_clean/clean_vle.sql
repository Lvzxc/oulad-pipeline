-- Create the clean table for vle
CREATE TABLE IF NOT EXISTS oulad.oulad_silver.vle_silver (
    id_site INT,
    code_module STRING,
    code_presentation STRING,
    activity_type STRING,
    week_from INT,
    week_to INT,
    ingestion_timestamp TIMESTAMP,
    ingestion_date DATE
);

-- Merge cleaned data from bronze table
MERGE INTO oulad.oulad_silver.vle_silver AS target 

USING (
    -- Filters on the casted columns, and only keeps rn = 1 rows to guarantee one row per grain key
    SELECT
        id_site,
        code_module,
        code_presentation,
        activity_type,
        week_from,
        week_to,
        ingestion_timestamp,
        ingestion_date
    FROM (
        -- Casts, cleans strings, handles '?', and adds ROW_NUMBER() to rank duplicate rows by recency
        SELECT
            -- Safely casts id_site to integer
            TRY_CAST(id_site AS INT) AS id_site,
            
            -- Explicitly cast standardized text columns to STRING
            CAST(UPPER(TRIM(code_module)) AS STRING) AS code_module,
            CAST(UPPER(TRIM(code_presentation)) AS STRING) AS code_presentation,
            CAST(LOWER(TRIM(activity_type)) AS STRING) AS activity_type,
            
            -- Convert '?' to NULL to prevent pipeline crashes when casting dates to integers
            CAST(NULLIF(TRIM(week_from), '?') AS INT) AS week_from,
            CAST(NULLIF(TRIM(week_to), '?') AS INT) AS week_to,
            
            ingestion_timestamp,
            CAST(ingestion_timestamp AS DATE) AS ingestion_date,
            
            -- Group by the exact site ID and rank the newest record first
            ROW_NUMBER() OVER (
                PARTITION BY TRY_CAST(id_site AS INT)
                ORDER BY ingestion_timestamp DESC
            ) AS rn
        FROM oulad.oulad_bronze.vle_bronze
    ) ranked
    
    -- Keep only the most recent row to prevent exact duplicates
    WHERE rn = 1
      -- Drop rows if the site ID is missing
      AND id_site IS NOT NULL      
) AS source

-- Match condition for updating or inserting records
ON target.id_site = source.id_site                 -- Standard equal because we know it is never NULL

-- When a VLE record already exists, update the record with incoming values
WHEN MATCHED THEN 
    UPDATE SET
        target.code_module = source.code_module,
        target.code_presentation = source.code_presentation,
        target.activity_type = source.activity_type,
        target.week_from = source.week_from,
        target.week_to = source.week_to,
        target.ingestion_timestamp = source.ingestion_timestamp,
        target.ingestion_date = source.ingestion_date

-- When a VLE record does not exist, insert the record
WHEN NOT MATCHED THEN
    INSERT (
        id_site,
        code_module,
        code_presentation,
        activity_type,
        week_from,
        week_to,
        ingestion_timestamp,
        ingestion_date
    )
    VALUES (
        source.id_site,
        source.code_module,
        source.code_presentation,
        source.activity_type,
        source.week_from,
        source.week_to,
        source.ingestion_timestamp,
        source.ingestion_date
    );