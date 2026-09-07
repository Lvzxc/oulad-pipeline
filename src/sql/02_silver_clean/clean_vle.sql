-- Create the silver table for vle 
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

-- Merge the incoming bronze data into the silver target table
MERGE INTO oulad.oulad_silver.vle_silver AS target
USING (
    -- Remove exact duplicate rows to prevent ingestion errors
    SELECT DISTINCT
        id_site,
        -- Standardize case to uppercase/lowercase and remove extra spaces
        UPPER(TRIM(code_module)) AS code_module,
        UPPER(TRIM(code_presentation)) AS code_presentation,
        LOWER(TRIM(activity_type)) AS activity_type,
        -- Convert literal '?' strings to NULL, then cast to INT
        TRY_CAST(NULLIF(TRIM(week_from), '?') AS INT) AS week_from,
        TRY_CAST(NULLIF(TRIM(week_to), '?') AS INT) AS week_to,
        -- Add data processing time
        CURRENT_TIMESTAMP() AS ingestion_timestamp,
        CAST(CURRENT_TIMESTAMP() AS DATE) AS ingestion_date
    FROM oulad.oulad_bronze.vle_bronze
    -- Filter out rows missing the primary site ID
    WHERE id_site IS NOT NULL
) AS source
-- Define the business key to match existing records (id_site is unique)
ON target.id_site = source.id_site
-- Update existing records with any new information
WHEN MATCHED THEN
    UPDATE SET
        target.code_module = source.code_module,
        target.code_presentation = source.code_presentation,
        target.activity_type = source.activity_type,
        target.week_from = source.week_from,
        target.week_to = source.week_to,
        target.ingestion_timestamp = source.ingestion_timestamp,
        target.ingestion_date = source.ingestion_date
-- Insert completely new VLE records
WHEN NOT MATCHED THEN
    INSERT (id_site, code_module, code_presentation, activity_type, week_from, week_to, ingestion_timestamp, ingestion_date)
    VALUES (source.id_site, source.code_module, source.code_presentation, source.activity_type, source.week_from, source.week_to, source.ingestion_timestamp, source.ingestion_date);
