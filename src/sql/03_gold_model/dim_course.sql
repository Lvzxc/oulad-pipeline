-- Create the Gold dimension table for courses
CREATE TABLE IF NOT EXISTS oulad.oulad_gold.dim_course (
    -- Surrogate primary key
    course_key BIGINT GENERATED ALWAYS AS IDENTITY,

    -- Course identifiers (kept as columns, not the primary key)
    code_module STRING,
    code_presentation STRING,

    -- Course attribute
    module_presentation_length BIGINT,

    -- Original Silver processing timestamp
    -- Used for data lineage and identifying the latest record
    silver_processed_timestamp TIMESTAMP,

    -- Timestamp and date when the record was processed into Gold
    gold_processed_timestamp TIMESTAMP,
    gold_processed_date DATE,

    PRIMARY KEY (course_key)
);


-- Prepare cleaned Silver records for Gold
CREATE OR REPLACE TEMP VIEW dim_course_ready AS

SELECT
    code_module,
    code_presentation,
    module_presentation_length,
    silver_processed_timestamp

FROM oulad.oulad_silver.courses_silver;


-- Merge the prepared records into the Gold dimension table
MERGE INTO oulad.oulad_gold.dim_course AS target

USING dim_course_ready AS source

-- Match on the natural business key
ON target.code_module = source.code_module
AND target.code_presentation = source.code_presentation

WHEN MATCHED THEN
    UPDATE SET
        target.module_presentation_length = source.module_presentation_length,
        target.silver_processed_timestamp = source.silver_processed_timestamp,
        target.gold_processed_timestamp = current_timestamp(),
        target.gold_processed_date = current_date()

-- course_key is intentionally left out of the INSERT list —
-- IDENTITY auto-generates it for every new row
WHEN NOT MATCHED THEN
    INSERT (
        code_module,
        code_presentation,
        module_presentation_length,
        silver_processed_timestamp,
        gold_processed_timestamp,
        gold_processed_date
    )
    VALUES (
        source.code_module,
        source.code_presentation,
        source.module_presentation_length,
        source.silver_processed_timestamp,
        current_timestamp(),
        current_date()
    );