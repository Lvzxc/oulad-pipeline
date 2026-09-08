-- Create the Silver table if it does not already exist
CREATE TABLE IF NOT EXISTS oulad.oulad_silver.assessment_silver (
    id_assessment BIGINT,
    code_module STRING,
    code_presentation STRING,
    assessment_type STRING,
    date INT,
    weight DOUBLE,

    -- Bronze lineage
    bronze_ingestion_timestamp TIMESTAMP,
    bronze_ingestion_date DATE,

    -- Silver processing metadata
    silver_processed_timestamp TIMESTAMP,
    silver_processed_date DATE
);


-- Clean, filter, and deduplicate Bronze data before merging into Silver
MERGE INTO oulad.oulad_silver.assessment_silver AS target

USING (
    WITH cleaned_bronze AS (
        SELECT
            -- Convert assessment ID to numeric
            -- Invalid values become NULL
            TRY_CAST(id_assessment AS BIGINT) AS id_assessment,

            -- Remove unnecessary spaces from categorical fields
            TRIM(code_module) AS code_module,
            TRIM(code_presentation) AS code_presentation,
            TRIM(assessment_type) AS assessment_type,

            -- Convert '?' to NULL before converting date to INT
            TRY_CAST(NULLIF(TRIM(date), '?') AS INT) AS date,

            -- Convert weight to numeric
            TRY_CAST(weight AS DOUBLE) AS weight,

            -- Preserve Bronze ingestion information for data lineage
            ingestion_timestamp AS bronze_ingestion_timestamp,
            CAST(ingestion_timestamp AS DATE) AS bronze_ingestion_date

        FROM oulad.oulad_bronze.assessment_bronze

        -- Exclude records with an incomplete business key
        -- Business key = id_assessment
        WHERE TRY_CAST(id_assessment AS BIGINT) IS NOT NULL
    ),

    ranked_bronze AS (
        SELECT
            *,

            -- Keep the latest record for each business key
            ROW_NUMBER() OVER (
                PARTITION BY id_assessment
                ORDER BY bronze_ingestion_timestamp DESC
            ) AS row_num

        FROM cleaned_bronze
    )

    SELECT
        id_assessment,
        code_module,
        code_presentation,
        assessment_type,
        date,
        weight,
        bronze_ingestion_timestamp,
        bronze_ingestion_date,

        -- Record when the Silver transformation was processed
        current_timestamp() AS silver_processed_timestamp,
        current_date() AS silver_processed_date

    FROM ranked_bronze

    -- Keep only one record per business key
    WHERE row_num = 1

) AS source


-- Match records using the assessment business key
ON target.id_assessment = source.id_assessment


-- Update existing records with the latest cleaned values
WHEN MATCHED THEN UPDATE SET
    target.code_module = source.code_module,
    target.code_presentation = source.code_presentation,
    target.assessment_type = source.assessment_type,
    target.date = source.date,
    target.weight = source.weight,
    target.bronze_ingestion_timestamp = source.bronze_ingestion_timestamp,
    target.bronze_ingestion_date = source.bronze_ingestion_date,
    target.silver_processed_timestamp = source.silver_processed_timestamp,
    target.silver_processed_date = source.silver_processed_date


-- Insert new records that do not yet exist in Silver
WHEN NOT MATCHED THEN INSERT (
    id_assessment,
    code_module,
    code_presentation,
    assessment_type,
    date,
    weight,
    bronze_ingestion_timestamp,
    bronze_ingestion_date,
    silver_processed_timestamp,
    silver_processed_date
)

VALUES (
    source.id_assessment,
    source.code_module,
    source.code_presentation,
    source.assessment_type,
    source.date,
    source.weight,
    source.bronze_ingestion_timestamp,
    source.bronze_ingestion_date,
    source.silver_processed_timestamp,
    source.silver_processed_date
);