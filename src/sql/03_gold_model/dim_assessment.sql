-- Create the Gold dimension table for assessments
CREATE TABLE IF NOT EXISTS oulad.oulad_gold.dim_assessment (
    assessment_key BIGINT GENERATED ALWAYS AS IDENTITY,
    id_assessment BIGINT,
    course_key BIGINT NOT NULL,
    code_module STRING,                 
    code_presentation STRING,        
    assessment_type STRING,
    assessment_date INT,
    weight INT,
    silver_processed_timestamp TIMESTAMP,
    silver_processed_date DATE,
    gold_processed_timestamp TIMESTAMP,  
    gold_processed_date DATE,            
    PRIMARY KEY (assessment_key)
);

-- Prepare cleaned Silver records for Gold
CREATE OR REPLACE TEMP VIEW dim_assessment_ready AS
SELECT
    a.id_assessment,
    dc.course_key,                        
    a.code_module,                        
    a.code_presentation,                 
    a.assessment_type,
    CAST(a.date AS INT) AS assessment_date,
    CAST(a.weight AS INT) AS weight,
    a.silver_processed_timestamp,
    a.silver_processed_date
FROM oulad.oulad_silver.assessment_silver a
JOIN oulad.oulad_gold.dim_course dc
    ON a.code_module = dc.code_module
    AND a.code_presentation = dc.code_presentation;

-- Merge into Gold
MERGE INTO oulad.oulad_gold.dim_assessment AS target
USING dim_assessment_ready AS source
ON target.id_assessment = source.id_assessment
AND target.course_key = source.course_key
AND target.code_module = source.code_module             
AND target.code_presentation = source.code_presentation  
WHEN MATCHED THEN
    UPDATE SET
        target.course_key = source.course_key,       
        target.code_module = source.code_module,            -- ✅ update
        target.code_presentation = source.code_presentation,-- ✅ update
        target.assessment_type = source.assessment_type,
        target.assessment_date = source.assessment_date,
        target.weight = source.weight,
        target.silver_processed_timestamp = source.silver_processed_timestamp,
        target.silver_processed_date = source.silver_processed_date,
        target.gold_processed_timestamp = current_timestamp(),
        target.gold_processed_date = current_date()
WHEN NOT MATCHED THEN
    INSERT (
        id_assessment,
        course_key,
        code_module,                                
        code_presentation,
        assessment_type,
        assessment_date,
        weight,
        silver_processed_timestamp,
        silver_processed_date,
        gold_processed_timestamp,
        gold_processed_date
    )
    VALUES (
        source.id_assessment,
        source.course_key,
        source.code_module,
        source.code_presentation,
        source.assessment_type,
        source.assessment_date,
        source.weight,
        source.silver_processed_timestamp,
        source.silver_processed_date,
        current_timestamp(),
        current_date()
    );
