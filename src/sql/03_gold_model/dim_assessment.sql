-- Create the Gold dimension table for assessments
CREATE TABLE IF NOT EXISTS oulad.oulad_gold.dim_assessment (
    -- Surrogate primary key
    assessment_key BIGINT GENERATED ALWAYS AS IDENTITY,

    -- Natural/business key columns (kept as columns, not the primary key)
    id_assessment BIGINT,
    code_module STRING,
    code_presentation STRING,

    -- Assessment attributes
    assessment_type STRING,
    assessment_date BIGINT,   -- relative-day offset; NULL for some Exam rows (due date unknown at source)
    weight DOUBLE,

    -- Original Silver processing timestamp
    -- Used for data lineage and identifying the latest record
    silver_processed_timestamp TIMESTAMP,

    -- Timestamp and date when the record was processed into Gold
    gold_processed_timestamp TIMESTAMP,
    gold_processed_date DATE,

    PRIMARY KEY (assessment_key)
);


-- Prepare cleaned Silver records for Gold
CREATE OR REPLACE TEMP VIEW dim_assessment_ready AS

SELECT
    id_assessment,
    code_module,
    code_presentation,
    assessment_type,
    date AS assessment_date,
    weight,
    silver_processed_timestamp

FROM oulad.oulad_silver.assessment_silver;


-- Merge the prepared records into the Gold dimension table
MERGE INTO oulad.oulad_gold.dim_assessment AS target

USING dim_assessment_ready AS source

-- Match on the natural business key
ON target.id_assessment = source.id_assessment
AND target.code_module = source.code_module
AND target.code_presentation = source.code_presentation

WHEN MATCHED THEN
    UPDATE SET
        target.assessment_type = source.assessment_type,
        target.assessment_date = source.assessment_date,
        target.weight = source.weight,
        target.silver_processed_timestamp = source.silver_processed_timestamp,
        target.gold_processed_timestamp = current_timestamp(),
        target.gold_processed_date = current_date()

-- assessment_key is intentionally left out of the INSERT list —
-- IDENTITY auto-generates it for every new row
WHEN NOT MATCHED THEN
    INSERT (
        id_assessment,
        code_module,
        code_presentation,
        assessment_type,
        assessment_date,
        weight,
        silver_processed_timestamp,
        gold_processed_timestamp,
        gold_processed_date
    )
    VALUES (
        source.id_assessment,
        source.code_module,
        source.code_presentation,
        source.assessment_type,
        source.assessment_date,
        source.weight,
        source.silver_processed_timestamp,
        current_timestamp(),
        current_date()
    );