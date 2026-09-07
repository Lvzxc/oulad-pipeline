-- Create the Silver table if it does not already exist
CREATE TABLE IF NOT EXISTS oulad.oulad_silver.student_info_silver (
    -- Student and course identifiers
    code_module STRING,
    code_presentation STRING,
    id_student BIGINT,

    -- Student demographic information
    gender STRING,
    region STRING,
    highest_education STRING,
    imd_band STRING,
    age_band STRING,

    -- Student course history and study information
    num_of_prev_attempts INT,
    studied_credits INT,

    -- Student status information
    disability STRING,
    final_result STRING,

    -- Result of the data quality checks
    quality_status STRING,

    -- Original ingestion timestamp from Bronze
    -- Used for data lineage and identifying the latest record
    bronze_ingestion_timestamp TIMESTAMP,

    -- Timestamp and date when the record was processed into Silver
    silver_processed_timestamp TIMESTAMP,
    silver_processed_date DATE
);


-- Clean, validate, filter, and deduplicate Bronze records for Silver
CREATE OR REPLACE TEMP VIEW student_info_silver_ready AS

WITH cleaned_bronze AS (
    SELECT
        -- Remove leading and trailing spaces from course identifiers
        TRIM(code_module) AS code_module,
        TRIM(code_presentation) AS code_presentation,

        -- Convert student ID to BIGINT
        -- Invalid values are converted to NULL instead of causing the query to fail
        TRY_CAST(id_student AS BIGINT) AS id_student,

        -- Standardize categorical fields by removing unnecessary spaces
        TRIM(gender) AS gender,
        TRIM(region) AS region,
        TRIM(highest_education) AS highest_education,
        TRIM(imd_band) AS imd_band,
        TRIM(age_band) AS age_band,

        -- Convert numeric fields to INT
        -- Invalid values become NULL and can be identified during DQ checks
        TRY_CAST(num_of_prev_attempts AS INT) AS num_of_prev_attempts,
        TRY_CAST(studied_credits AS INT) AS studied_credits,

        -- Standardize remaining categorical fields
        TRIM(disability) AS disability,
        TRIM(final_result) AS final_result,

        -- Preserve the original Bronze ingestion timestamp
        -- This supports data lineage and record version selection
        ingestion_timestamp AS bronze_ingestion_timestamp

    FROM oulad.oulad_bronze.student_info_bronze
),

quality_checked AS (
    SELECT
        *,

        -- Assign a quality status based on the defined DQ rules
        CASE

            -- FAIL:
            -- The business key must be complete for the record
            -- Business key = code_module + code_presentation + id_student
            -- Records failing this check are excluded from Silver
            WHEN id_student IS NULL
              OR code_module IS NULL
              OR code_module = ''
              OR code_presentation IS NULL
              OR code_presentation = ''
            THEN 'FAIL'

            -- WARN:
            -- Negative values are unexpected but the record can still be retained
            -- The record is kept in Silver and flagged for review
            WHEN num_of_prev_attempts < 0
              OR studied_credits < 0
            THEN 'WARN'

            -- PASS:
            -- No defined data quality issue was found
            ELSE 'PASS'

        END AS quality_status

    FROM cleaned_bronze
),

usable_records AS (
    SELECT *
    FROM quality_checked

    -- PASS and WARN records are still usable for Silver
    -- FAIL records are excluded because they do not meet the minimum requirements
    WHERE quality_status IN ('PASS', 'WARN')
),

ranked_records AS (
    SELECT
        *,

        -- Rank records within each business key
        -- The newest usable Bronze record receives row_num = 1
        ROW_NUMBER() OVER (
            PARTITION BY
                code_module,
                code_presentation,
                id_student
            ORDER BY bronze_ingestion_timestamp DESC
        ) AS row_num

    FROM usable_records
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
    quality_status,
    bronze_ingestion_timestamp

FROM ranked_records

-- Keep only the latest usable record for each business key
-- This prevents duplicate student-course records from entering Silver
WHERE row_num = 1;


-- Merge the prepared records into the Silver table
-- MERGE allows the pipeline to update existing records or insert new ones
MERGE INTO oulad.oulad_silver.student_info_silver AS target

USING student_info_silver_ready AS source

-- Match records using the business key
-- id_student alone is not sufficient because a student can have
-- multiple module and presentation combinations
ON target.code_module = source.code_module
AND target.code_presentation = source.code_presentation
AND target.id_student = source.id_student


-- Update the existing Silver record when the business key already exists
WHEN MATCHED THEN
    UPDATE SET
        target.gender = source.gender,
        target.region = source.region,
        target.highest_education = source.highest_education,
        target.imd_band = source.imd_band,
        target.age_band = source.age_band,
        target.num_of_prev_attempts = source.num_of_prev_attempts,
        target.studied_credits = source.studied_credits,
        target.disability = source.disability,
        target.final_result = source.final_result,
        target.quality_status = source.quality_status,

        -- Update the lineage timestamp when the source record changes
        target.bronze_ingestion_timestamp = source.bronze_ingestion_timestamp,

        -- Record when the Silver record was processed
        target.silver_processed_timestamp = current_timestamp(),
        target.silver_processed_date = current_date()


-- Insert the record when the business key does not exist in Silver
WHEN NOT MATCHED THEN
    INSERT (
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
        quality_status,
        bronze_ingestion_timestamp,
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
        source.quality_status,
        source.bronze_ingestion_timestamp,

        -- Record when the new record was processed into Silver
        current_timestamp(),
        current_date()
    );
    