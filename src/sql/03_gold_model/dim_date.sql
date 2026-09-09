-- Create the Gold dimension table for relative dates
CREATE TABLE IF NOT EXISTS oulad.oulad_gold.dim_date (

    -- Primary key for the date dimension.
    date_key BIGINT,

    -- Original OULAD relative-day value.
    -- Example: -5 = 5 days before the module presentation starts
    relative_day BIGINT,

    -- Relative week derived from the relative day.
    relative_week BIGINT,

    -- Timestamp when the record was processed into Gold.
    gold_processed_timestamp TIMESTAMP,

    -- Date when the record was processed into Gold.
    gold_processed_date DATE,

    PRIMARY KEY (date_key)
);


-- Identify the minimum and maximum relative dates from all Silver tables containing date-based events.
-- These values determine the complete relative-date range required for dim_date.
CREATE OR REPLACE TEMP VIEW dim_date_range AS
WITH date_ranges AS (
    -- Assessment submission dates.
    SELECT
        MIN(date_submitted) AS min_date,
        MAX(date_submitted) AS max_date
    FROM oulad.oulad_silver.student_assessment_silver

    UNION ALL

    -- Student registration dates.
    SELECT
        MIN(date_registration) AS min_date,
        MAX(date_registration) AS max_date
    FROM oulad.oulad_silver.student_registration_silver

    UNION ALL

    -- Student unregistration dates.
    SELECT
        MIN(date_unregistration) AS min_date,
        MAX(date_unregistration) AS max_date
    FROM oulad.oulad_silver.student_registration_silver

    UNION ALL

    -- Student VLE interaction dates.
    SELECT
        MIN(date) AS min_date,
        MAX(date) AS max_date
    FROM oulad.oulad_silver.student_vle_silver
),

overall_range AS (

    -- Combine the ranges from all date-based Silver tables to determine the earliest and latest relative day present in the source data.
    SELECT
        MIN(min_date) AS min_date,
        MAX(max_date) AS max_date
    FROM date_ranges
)

SELECT
    min_date,
    max_date

FROM overall_range;

-- Generate one record for every relative day in the OULAD date range.
CREATE OR REPLACE TEMP VIEW dim_date_ready AS
SELECT
    -- Use the relative day itself as the date key.
    relative_day AS date_key,
    -- Preserve the original OULAD relative-day value.
    relative_day,
    -- Convert relative days into course-relative weeks.
    --  Example: Day -7 to -1  -> Week -1
    --           Day  0 to  6  -> Week  0
    CAST(FLOOR(relative_day / 7) AS BIGINT) AS relative_week

    FROM dim_date_range

-- Generate every integer relative day between the minimum and maximum dates.
LATERAL VIEW EXPLODE(
    SEQUENCE(min_date, max_date)
) AS relative_day;
    
-- Merge the prepared relative-date records into the Gold dimension.
MERGE INTO oulad.oulad_gold.dim_date AS target
USING dim_date_ready AS source

-- Match records using the relative date key.
ON target.date_key = source.date_key

-- If the relative day already exists, update its attributes and refresh the Gold processing metadata.
WHEN MATCHED THEN
    UPDATE SET
        target.relative_day = source.relative_day,
        target.relative_week = source.relative_week,
        target.gold_processed_timestamp = current_timestamp(),
        target.gold_processed_date = current_date()

-- If the relative day does not yet exist, insert it.
WHEN NOT MATCHED THEN
    INSERT (
        date_key,
        relative_day,
        relative_week,
        gold_processed_timestamp,
        gold_processed_date
    )
    VALUES (
        source.date_key,
        source.relative_day,
        source.relative_week,
        current_timestamp(),
        current_date()
    );