-- Create the clean student vle table
CREATE TABLE IF NOT EXISTS oulad.oulad_silver.student_vle_silver (
    code_module STRING,
    code_presentation STRING,
    id_student INT,
    id_site INT,
    date INT, 
    sum_click INT,
    ingestion_timestamp TIMESTAMP,
    ingestion_date DATE 
);

MERGE INTO oulad.oulad_silver.student_vle_silver AS target
USING (
    SELECT
        code_module,
        code_presentation,
        id_student,
        id_site,
        date,
        sum_click,
        ingestion_timestamp,
        ingestion_date
    FROM (
        SELECT
            TRIM(code_module) AS code_module,
            TRIM(code_presentation) AS code_presentation,
            TRY_CAST(id_student AS INT) AS id_student,
            TRY_CAST(id_site AS INT) AS id_site,
            -- Convert '?' to NULL before casting
            TRY_CAST(NULLIF(TRIM(date), '?') AS INT) AS date,
            TRY_CAST(sum_click AS INT) AS sum_click,
            ingestion_timestamp,         
            ingestion_date,              
            ROW_NUMBER() OVER (
                PARTITION BY TRY_CAST(id_student AS INT),
                             TRY_CAST(id_site AS INT),
                             TRY_CAST(NULLIF(TRIM(date), '?') AS INT)
                ORDER BY ingestion_timestamp DESC
            ) AS rn
        FROM oulad.oulad_bronze.student_vle_bronze
    ) ranked
    WHERE rn = 1
      AND id_student IS NOT NULL
      AND id_site IS NOT NULL
      AND date IS NOT NULL
) AS source
ON target.id_student = source.id_student
   AND target.id_site = source.id_site
   AND target.date = source.date

-- Update existing records
WHEN MATCHED THEN
    UPDATE SET
        target.code_module = source.code_module,
        target.code_presentation = source.code_presentation,
        target.sum_click = source.sum_click,
        target.ingestion_timestamp = source.ingestion_timestamp,
        target.ingestion_date = source.ingestion_date

-- Insert new records
WHEN NOT MATCHED THEN
    INSERT (
        code_module,
        code_presentation,
        id_student,
        id_site,
        date,
        sum_click,
        ingestion_timestamp,
        ingestion_date
    )
    VALUES (
        source.code_module,
        source.code_presentation,
        source.id_student,
        source.id_site,
        source.date,
        source.sum_click,
        source.ingestion_timestamp,
        source.ingestion_date
    );
