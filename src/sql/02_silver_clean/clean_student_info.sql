-- Create the Silver table if it does not already exist
CREATE TABLE IF NOT EXISTS oulad.oulad_silver.student_info_silver (
    code_module STRING,
    code_presentation STRING,
    id_student BIGINT,
    gender STRING,
    region STRING,
    highest_education STRING,
    imd_band STRING,
    age_band STRING,
    num_of_prev_attempts INT,
    studied_credits INT,
    disability STRING,
    final_result STRING,

    -- Bronze lineage
    bronze_ingestion_timestamp TIMESTAMP,
    bronze_ingestion_date DATE,

    -- Silver processing metadata
    silver_processed_timestamp TIMESTAMP,
    silver_processed_date DATE
);


-- Clean, filter, and deduplicate Bronze data before merging into Silver
MERGE INTO oulad.oulad_silver.student_info_silver AS target

USING (
    WITH cleaned_bronze AS (
        SELECT
            TRIM(code_module) AS code_module,
            TRIM(code_presentation) AS code_presentation,

            -- Convert student ID to numeric
            -- Invalid values become NULL
            TRY_CAST(id_student AS BIGINT) AS id_student,

            -- Remove unnecessary spaces from categorical fields
            TRIM(gender) AS gender,
            TRIM(region) AS region,
            TRIM(highest_education) AS highest_education,
            TRIM(imd_band) AS imd_band,
            TRIM(age_band) AS age_band,

            -- Convert numeric fields to INT
            -- Invalid values become NULL for validation
            TRY_CAST(num_of_prev_attempts AS INT) AS num_of_prev_attempts,
            TRY_CAST(studied_credits AS INT) AS studied_credits,

            TRIM(disability) AS disability,
            TRIM(final_result) AS final_result,

            -- Preserve Bronze ingestion information for data lineage
            ingestion_timestamp AS bronze_ingestion_timestamp,
            CAST(ingestion_timestamp AS DATE) AS bronze_ingestion_date

        FROM oulad.oulad_bronze.student_info_bronze

        -- Exclude records with an incomplete business key
        -- Business key = code_module + code_presentation + id_student
        WHERE code_module IS NOT NULL
          AND code_presentation IS NOT NULL
          AND TRY_CAST(id_student AS BIGINT) IS NOT NULL
    ),

    ranked_bronze AS (
        SELECT
            *,

            -- Keep the latest record for each business key
            ROW_NUMBER() OVER (
                PARTITION BY
                    code_module,
                    code_presentation,
                    id_student
                ORDER BY bronze_ingestion_timestamp DESC
            ) AS row_num

        FROM cleaned_bronze
    )

    SELECT
        code_module,
        code_presentation,
        id_student,
        gender,
        region,
        highest_education,
        imd_band,
        age_band,
        num_of_prev_attempts,
        studied_credits,
        disability,
        final_result,
        bronze_ingestion_timestamp,
        bronze_ingestion_date,

        -- Record when the Silver transformation was processed
        current_timestamp() AS silver_processed_timestamp,
        current_date() AS silver_processed_date

    FROM ranked_bronze

    -- Keep only one record per business key
    WHERE row_num = 1

) AS source


-- Match records using the student-module-presentation business key
ON target.code_module = source.code_module
AND target.code_presentation = source.code_presentation
AND target.id_student = source.id_student


-- Update existing records with the latest cleaned values
WHEN MATCHED THEN UPDATE SET
    target.gender = source.gender,
    target.region = source.region,
    target.highest_education = source.highest_education,
    target.imd_band = source.imd_band,
    target.age_band = source.age_band,
    target.num_of_prev_attempts = source.num_of_prev_attempts,
    target.studied_credits = source.studied_credits,
    target.disability = source.disability,
    target.final_result = source.final_result,
    target.bronze_ingestion_timestamp = source.bronze_ingestion_timestamp,
    target.bronze_ingestion_date = source.bronze_ingestion_date,
    target.silver_processed_timestamp = source.silver_processed_timestamp,
    target.silver_processed_date = source.silver_processed_date


-- Insert new records that do not yet exist in Silver
WHEN NOT MATCHED THEN INSERT (
    code_module,
    code_presentation,
    id_student,
    gender,
    region,
    highest_education,
    imd_band,
    age_band,
    num_of_prev_attempts,
    studied_credits,
    disability,
    final_result,
    bronze_ingestion_timestamp,
    bronze_ingestion_date,
    silver_processed_timestamp,
    silver_processed_date
)

VALUES (
    source.code_module,
    source.code_presentation,
    source.id_student,
    source.gender,
    source.region,
    source.highest_education,
    source.imd_band,
    source.age_band,
    source.num_of_prev_attempts,
    source.studied_credits,
    source.disability,
    source.final_result,
    source.bronze_ingestion_timestamp,
    source.bronze_ingestion_date,
    source.silver_processed_timestamp,
    source.silver_processed_date
);