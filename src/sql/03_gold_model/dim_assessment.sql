-- Create the Gold dimension table for assessments
CREATE TABLE IF NOT EXISTS oulad.oulad_gold.dim_assessment (
    -- Composite primary key
    id_assessment BIGINT,
    code_module STRING,
    code_presentation STRING,

    -- Assessment attributes
    assessment_type STRING,
    assessment_date BIGINT,   -- relative-day offset; NULL for some Exam rows (due date unknown at source)
    weight DOUBLE,

    -- Result of the data quality checks
    quality_status STRING,

    -- Original Silver processing timestamp
    -- Used for data lineage and identifying the latest record
    silver_processed_timestamp TIMESTAMP,

    -- Timestamp and date when the record was processed into Gold
    gold_processed_timestamp TIMESTAMP,
    gold_processed_date DATE,

    PRIMARY KEY (id_assessment, code_module, code_presentation)
);


-- Clean, validate, and prepare Silver records for Gold
CREATE OR REPLACE TEMP VIEW dim_assessment_ready AS

SELECT
    id_assessment,
    code_module,
    code_presentation,
    assessment_type,
    date AS assessment_date,
    weight,
    silver_processed_timestamp,

    -- Assign a quality status based on the defined DQ rules
    CASE

        -- FAIL:
        -- The full composite key must be complete
        -- Key = id_assessment + code_module + code_presentation
        -- Records failing this check are excluded from Gold
        WHEN id_assessment IS NULL
          OR code_module IS NULL
          OR code_presentation IS NULL
        THEN 'FAIL'

        -- WARN:
        -- A missing due date is expected for some Exam rows (OULAD
        -- leaves this unset), and a missing or negative weight is
        -- unexpected but not disqualifying — both are retained and
        -- flagged for review
        WHEN assessment_date IS NULL
          OR weight IS NULL
          OR weight < 0
        THEN 'WARN'

        -- PASS:
        -- No defined data quality issue was found
        ELSE 'PASS'

    END AS quality_status

FROM oulad.oulad_silver.assessment_silver;


-- Merge the prepared records into the Gold dimension table
MERGE INTO oulad.oulad_gold.dim_assessment AS target

USING dim_assessment_ready AS source

-- Match on the full composite key
ON target.id_assessment = source.id_assessment
AND target.code_module = source.code_module
AND target.code_presentation = source.code_presentation

WHEN MATCHED THEN
    UPDATE SET
        target.assessment_type = source.assessment_type,
        target.assessment_date = source.assessment_date,
        target.weight = source.weight,
        target.quality_status = source.quality_status,
        target.silver_processed_timestamp = source.silver_processed_timestamp,
        target.gold_processed_timestamp = current_timestamp(),
        target.gold_processed_date = current_date()

WHEN NOT MATCHED THEN
    INSERT (
        id_assessment,
        code_module,
        code_presentation,
        assessment_type,
        assessment_date,
        weight,
        quality_status,
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
        source.quality_status,
        source.silver_processed_timestamp,
        current_timestamp(),
        current_date()
    );
