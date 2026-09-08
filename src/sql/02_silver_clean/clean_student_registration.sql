-- Create the clean table for student registration
CREATE TABLE IF NOT EXISTS oulad.oulad_silver.student_registration_silver (
    code_module STRING,
    code_presentation STRING,
    id_student INT,
    date_registration INT,
    date_unregistration INT,
    ingestion_timestamp TIMESTAMP,
    ingestion_date DATE
);

-- Merge cleaned data from bronze table
MERGE INTO oulad.oulad_silver.student_registration_silver AS target 

USING (
    -- Filters on the casted columns, and only keeps rn = 1 rows to guarantee one row per grain key
    SELECT
        code_module,
        code_presentation,
        id_student,
        date_registration,
        date_unregistration,
        ingestion_timestamp,
        ingestion_date
    FROM (
        -- Casts, cleans strings, handles '?', and adds ROW_NUMBER() to rank duplicate rows by recency
        SELECT
            -- Cast standardized text to STRING
            CAST(UPPER(TRIM(code_module)) AS STRING) AS code_module,
            CAST(UPPER(TRIM(code_presentation)) AS STRING) AS code_presentation,
            
            -- Safely cast to integer 
            TRY_CAST(id_student AS INT) AS id_student,
            
            -- Convert '?' to NULL to prevent pipeline crashes when casting dates to integers
            CAST(NULLIF(TRIM(date_registration), '?') AS INT) AS date_registration,
            CAST(NULLIF(TRIM(date_unregistration), '?') AS INT) AS date_unregistration,
            
            ingestion_timestamp,
            CAST(ingestion_timestamp AS DATE) AS ingestion_date,
            
            -- Group by the exact student-module-presentation combination and rank the newest record first
            ROW_NUMBER() OVER (
                PARTITION BY CAST(UPPER(TRIM(code_module)) AS STRING), CAST(UPPER(TRIM(code_presentation)) AS STRING), TRY_CAST(id_student AS INT)
                ORDER BY ingestion_timestamp DESC
            ) AS rn
        FROM oulad.oulad_bronze.student_registration_bronze
    ) ranked
    
    -- Keep only the most recent row to prevent exact duplicates
    WHERE rn = 1
      -- Drop rows if the student ID or module code is missing
      AND id_student IS NOT NULL      
      AND code_module IS NOT NULL
) AS source

-- Match condition for updating or inserting records
ON target.id_student = source.id_student                 -- Standard equal because we know it is never NULL
   AND target.code_module = source.code_module           -- Standard equal because we know it is never NULL
   AND target.code_presentation <=> source.code_presentation -- NULL-safe 

-- When a student registration record already exists, update the record with incoming values
WHEN MATCHED THEN 
    UPDATE SET
        target.date_registration = source.date_registration,
        target.date_unregistration = source.date_unregistration,
        target.ingestion_timestamp = source.ingestion_timestamp,
        target.ingestion_date = source.ingestion_date

-- When a student registration record does not exist, insert the record
WHEN NOT MATCHED THEN
    INSERT (
        code_module,
        code_presentation,
        id_student,
        date_registration,
        date_unregistration,
        ingestion_timestamp,
        ingestion_date
    )
    VALUES (
        source.code_module,
        source.code_presentation,
        source.id_student,
        source.date_registration,
        source.date_unregistration,
        source.ingestion_timestamp,
        source.ingestion_date
    );