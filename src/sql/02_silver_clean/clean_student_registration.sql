-- Create the silver table for student registration
CREATE TABLE IF NOT EXISTS oulad.oulad_silver.student_registration_silver (
    code_module STRING,
    code_presentation STRING,
    id_student INT,
    date_registration INT,
    date_unregistration INT,
    ingestion_timestamp TIMESTAMP,
    ingestion_date DATE
);

-- Merge the incoming bronze data into the silver target table
MERGE INTO oulad.oulad_silver.student_registration_silver AS target
USING (
    -- Remove exact duplicate rows to prevent ingestion errors
    SELECT DISTINCT
        -- Standardize case to uppercase and remove extra spaces
        UPPER(TRIM(code_module)) AS code_module,
        UPPER(TRIM(code_presentation)) AS code_presentation,
        id_student,
        -- Cast string dates to integers for analysis
        TRY_CAST(date_registration AS INT) AS date_registration,
        TRY_CAST(date_unregistration AS INT) AS date_unregistration,
        -- Add data processing time
        CURRENT_TIMESTAMP() AS ingestion_timestamp,
        CAST(CURRENT_TIMESTAMP() AS DATE) AS ingestion_date
    FROM oulad.oulad_bronze.student_registration_bronze
    -- Filter out rows with missing a student ID
    WHERE id_student IS NOT NULL
) AS source
-- Define the business key to match existing records
ON target.code_module = source.code_module 
   AND target.code_presentation = source.code_presentation 
   AND target.id_student = source.id_student
-- Update existing records with any new information
WHEN MATCHED THEN
    UPDATE SET
        target.date_registration = source.date_registration,
        target.date_unregistration = source.date_unregistration,
        target.ingestion_timestamp = source.ingestion_timestamp,
        target.ingestion_date = source.ingestion_date
-- Insert completely new registration records
WHEN NOT MATCHED THEN
    INSERT (code_module, code_presentation, id_student, date_registration, date_unregistration, ingestion_timestamp, ingestion_date)
    VALUES (source.code_module, source.code_presentation, source.id_student, source.date_registration, source.date_unregistration, source.ingestion_timestamp, source.ingestion_date);