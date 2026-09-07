-- Create the Gold dimension table for courses
CREATE TABLE IF NOT EXISTS oulad.oulad_gold.dim_course (
    -- Course identifiers (composite key)
    code_module STRING,
    code_presentation STRING,

    -- Course attribute
    module_presentation_length BIGINT,

    -- Result of the data quality checks
    quality_status STRING,

    -- Original Silver timestamp
    -- Used for data lineage and identifying the latest record
    silver_ingestion_timestamp TIMESTAMP,

    -- Timestamp and date when the record was processed into Gold
    gold_processed_timestamp TIMESTAMP,
    gold_processed_date DATE,

    PRIMARY KEY (code_module, code_presentation)
);


-- Clean, validate, and prepare Silver records for Gold
CREATE OR REPLACE TEMP VIEW dim_course_ready AS

WITH cleaned_silver AS (
    SELECT
        code_module,
        code_presentation,
        module_presentation_length,

        -- Preserve the Silver timestamp for lineage
        ingestion_timestamp AS silver_ingestion_timestamp

    FROM oulad.oulad_silver.courses_silver
),

quality_checked AS (
    SELECT
        *,

        -- Assign a quality status based on the defined DQ rules
        CASE

            -- FAIL:
            -- The course key must be complete for the record
            -- Course key = code_module + code_presentation
            -- Records failing this check are excluded from Gold
            WHEN code_module IS NULL
              OR code_module = ''
              OR code_presentation IS NULL
              OR code_presentation = ''
            THEN 'FAIL'

            -- WARN:
            -- A missing or non-positive duration is unexpected but the record
            -- can still be retained; it is kept in Gold and flagged for review
            WHEN module_presentation_length IS NULL
              OR module_presentation_length <= 0
            THEN 'WARN'

            -- PASS:
            -- No defined data quality issue was found
            ELSE 'PASS'

        END AS quality_status

    FROM cleaned_silver
),

usable_records AS (
    SELECT *
    FROM quality_checked

    -- PASS and WARN records are still usable for Gold
    -- FAIL records are excluded because they do not meet the minimum requirements
    WHERE quality_status IN ('PASS', 'WARN')
)

SELECT
    code_module,
    code_presentation,
    module_presentation_length,
    quality_status,
    silver_ingestion_timestamp

FROM usable_records;


-- Merge the prepared records into the Gold dimension table
MERGE INTO oulad.oulad_gold.dim_course AS target

USING dim_course_ready AS source

-- Match on the composite business key
ON target.code_module = source.code_module
AND target.code_presentation = source.code_presentation

WHEN MATCHED THEN
    UPDATE SET
        target.module_presentation_length = source.module_presentation_length,
        target.quality_status = source.quality_status,
        target.silver_ingestion_timestamp = source.silver_ingestion_timestamp,
        target.gold_processed_timestamp = current_timestamp(),
        target.gold_processed_date = current_date()

WHEN NOT MATCHED THEN
    INSERT (
        code_module,
        code_presentation,
        module_presentation_length,
        quality_status,
        silver_ingestion_timestamp,
        gold_processed_timestamp,
        gold_processed_date
    )
    VALUES (
        source.code_module,
        source.code_presentation,
        source.module_presentation_length,
        source.quality_status,
        source.silver_ingestion_timestamp,
        current_timestamp(),
        current_date()
    );
