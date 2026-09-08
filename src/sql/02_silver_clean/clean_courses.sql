--- Create the clean table for courses
CREATE TABLE IF NOT EXISTS oulad.oulad_silver.courses_silver (
    code_module STRING,
    code_presentation STRING,
    module_presentation_length INT,

    -- Bronze lineage
    bronze_ingestion_timestamp TIMESTAMP,
    bronze_ingestion_date DATE,

    -- Silver processing metadata
    silver_processed_timestamp TIMESTAMP,
    silver_processed_date DATE
);


-- Clean, filter, and deduplicate Bronze data before merging into Silver
MERGE INTO oulad.oulad_silver.courses_silver AS target

USING (
    WITH cleaned_bronze AS (
        SELECT
            UPPER(TRIM(code_module)) AS code_module,
            UPPER(TRIM(code_presentation)) AS code_presentation,

            -- Convert duration to numeric
            -- Invalid values become NULL
            TRY_CAST(module_presentation_length AS INT) AS module_presentation_length,

            -- Preserve Bronze ingestion information for data lineage
            ingestion_timestamp AS bronze_ingestion_timestamp,
            CAST(ingestion_timestamp AS DATE) AS bronze_ingestion_date

        FROM oulad.oulad_bronze.courses_bronze

        -- Exclude records with an incomplete business key
        -- Business key = code_module + code_presentation
        -- Also exclude a missing or non-positive duration, since it
        -- cannot support downstream relative-day calculations
        WHERE code_module IS NOT NULL
          AND code_presentation IS NOT NULL
          AND TRY_CAST(module_presentation_length AS INT) IS NOT NULL
          AND TRY_CAST(module_presentation_length AS INT) > 0
    ),

    ranked_bronze AS (
        SELECT
            *,

            -- Keep the latest record for each business key
            ROW_NUMBER() OVER (
                PARTITION BY
                    code_module,
                    code_presentation
                ORDER BY bronze_ingestion_timestamp DESC
            ) AS row_num

        FROM cleaned_bronze
    )

    SELECT
        code_module,
        code_presentation,
        module_presentation_length,
        bronze_ingestion_timestamp,
        bronze_ingestion_date,

        -- Record when the Silver transformation was processed
        current_timestamp() AS silver_processed_timestamp,
        current_date() AS silver_processed_date

    FROM ranked_bronze

    -- Keep only one record per business key
    WHERE row_num = 1

) AS source


-- Match records using the course-presentation business key
ON target.code_module = source.code_module
AND target.code_presentation = source.code_presentation


-- Update existing records with the latest cleaned values
WHEN MATCHED THEN UPDATE SET
    target.module_presentation_length = source.module_presentation_length,
    target.bronze_ingestion_timestamp = source.bronze_ingestion_timestamp,
    target.bronze_ingestion_date = source.bronze_ingestion_date,
    target.silver_processed_timestamp = source.silver_processed_timestamp,
    target.silver_processed_date = source.silver_processed_date


-- Insert new records that do not yet exist in Silver
WHEN NOT MATCHED THEN INSERT (
    code_module,
    code_presentation,
    module_presentation_length,
    bronze_ingestion_timestamp,
    bronze_ingestion_date,
    silver_processed_timestamp,
    silver_processed_date
)

VALUES (
    source.code_module,
    source.code_presentation,
    source.module_presentation_length,
    source.bronze_ingestion_timestamp,
    source.bronze_ingestion_date,
    source.silver_processed_timestamp,
    source.silver_processed_date
);
