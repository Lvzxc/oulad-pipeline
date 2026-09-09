-- CREATE GOLD DIMENSION TABLE: STUDENT

-- Grain:
-- One row per student PER course enrollment.

-- Sources:
--   1. student_info_silver
--      -> student characteristics and final result
--   2. student_registration_silver
--      -> registration and unregistration dates

-- Keys:
--   student_key = Gold surrogate key generated using IDENTITY
--
-- Natural/business key:
--   id_student + course_key

-- STEP 1: CREATE THE GOLD DIMENSION TABLE
CREATE TABLE IF NOT EXISTS oulad.oulad_gold.dim_student (
    student_key BIGINT GENERATED ALWAYS AS IDENTITY (START WITH 1 INCREMENT BY 1), -- PK, system-generated
    id_student BIGINT,   -- Student identifier from the source data
    course_key BIGINT,   -- FK to dim_course.course_key
    gender STRING,       -- Student demographic attributes
    region STRING,
    age_band STRING,
    highest_education STRING, -- Student educational and socioeconomic background
    imd_band STRING,
    num_of_prev_attempts BIGINT,     -- Student academic history and study load
    studied_credits BIGINT,
    disability STRING,     -- Student characteristic
    final_result STRING, -- Final outcome for the student's course enrollment.
    date_registration BIGINT,
    date_unregistration BIGINT,

    -- Silver lineage metadata
    silver_processed_timestamp TIMESTAMP,
    silver_processed_date DATE,

    -- Gold processing metadata
    gold_processed_timestamp TIMESTAMP,
    gold_processed_date DATE,

    PRIMARY KEY (student_key)
);


-- STEP 2: PREPARE THE SILVER DATA FOR GOLD
CREATE OR REPLACE TEMP VIEW dim_student_ready AS
WITH ranked_students AS ( -- STEP 2A: DEDUPLICATE STUDENT INFORMATION

    SELECT
        si.id_student,
        si.code_module,
        si.code_presentation,
        si.gender,
        si.region,
        si.age_band,
        si.highest_education,
        si.imd_band,
        si.num_of_prev_attempts,
        si.studied_credits,
        si.disability,
        si.final_result,
        si.silver_processed_timestamp,
        si.silver_processed_date,

        ROW_NUMBER() OVER (
            PARTITION BY
                si.id_student,
                si.code_module,
                si.code_presentation

            ORDER BY
                si.silver_processed_timestamp DESC NULLS LAST,
                -- Deterministic tiebreaker.
                -- id_student cannot be used because it is already
                -- part of the PARTITION BY.
                -- The hash ensures the same tied record is selected
                -- consistently across runs.
                xxhash64(
                    si.gender,
                    si.region,
                    si.age_band,
                    si.highest_education,
                    si.imd_band,
                    si.num_of_prev_attempts,
                    si.studied_credits,
                    si.disability,
                    si.final_result
                ) DESC
        ) AS row_num

    FROM oulad.oulad_silver.student_info_silver AS si
),

-- STEP 2B: DEDUPLICATE REGISTRATION INFORMATION
ranked_registration AS (

    SELECT
        sr.id_student,
        sr.code_module,
        sr.code_presentation,

        sr.date_registration,
        sr.date_unregistration,

        ROW_NUMBER() OVER (
            PARTITION BY
                sr.id_student,
                sr.code_module,
                sr.code_presentation

            ORDER BY
                sr.ingestion_timestamp DESC NULLS LAST,

                -- Deterministic tiebreaker.
                -- id_student cannot distinguish records within the same student/course partition
                xxhash64(
                    sr.date_registration,
                    sr.date_unregistration
                ) DESC
        ) AS row_num

    FROM oulad.oulad_silver.student_registration_silver AS sr
)


-- STEP 2C: BUILD THE FINAL GOLD-READY RECORD
SELECT
    -- Preserve the original student identifier
    rs.id_student,
 
    -- Pull the established course key from dim_course
    dc.course_key,

    -- Student demographic attributes
    rs.gender,
    rs.region,
    rs.age_band,
 
    -- Student educational and socioeconomic background
    rs.highest_education,
    rs.imd_band,
 
    -- Student academic history and study load
    rs.num_of_prev_attempts,
    rs.studied_credits,
 
    -- Student characteristic
    rs.disability,
 
    -- Final outcome for this student/course enrollment
    rs.final_result,
 
    -- Registration information.
    rr.date_registration,
    rr.date_unregistration,
 
    -- Preserve the Silver processing timestamp for lineage
    rs.silver_processed_timestamp,
    rs.silver_processed_date
 
FROM ranked_students AS rs

-- Pull the existing course_key from the Gold course dimension.
INNER JOIN oulad.oulad_gold.dim_course AS dc
    ON rs.code_module = dc.code_module
    AND rs.code_presentation = dc.code_presentation

-- Keep the student record even when no registration record exists
LEFT JOIN ranked_registration AS rr
    ON rs.id_student = rr.id_student
    AND rs.code_module = rr.code_module
    AND rs.code_presentation = rr.code_presentation

    -- Only use the latest registration record
    AND rr.row_num = 1

-- Keep only the selected student record for each student + module + presentation combination
WHERE rs.row_num = 1;


-- STEP 3: MERGE THE PREPARED DATA INTO GOLD
MERGE INTO oulad.oulad_gold.dim_student AS target

USING dim_student_ready AS source

-- Match using the natural enrollment key.
ON target.id_student = source.id_student
AND target.course_key = source.course_key

-- If the student/course enrollment already exists, update its attributes and refresh Gold metadata
WHEN MATCHED THEN
    UPDATE SET
        target.gender = source.gender,
        target.region = source.region,
        target.age_band = source.age_band,
        target.highest_education = source.highest_education,
        target.imd_band = source.imd_band,
        target.num_of_prev_attempts = source.num_of_prev_attempts,
        target.studied_credits = source.studied_credits,
        target.disability = source.disability,
        target.final_result = source.final_result,
        target.date_registration = source.date_registration,
        target.date_unregistration = source.date_unregistration,

        -- Preserve the latest Silver lineage timestamp
        target.silver_processed_timestamp = source.silver_processed_timestamp,
        target.silver_processed_date = source.silver_processed_date,

        -- Refresh Gold processing metadata
        target.gold_processed_timestamp = current_timestamp(),
        target.gold_processed_date = current_date()


-- If the student/course enrollment does not exist, insert a new record
WHEN NOT MATCHED THEN
    INSERT (
        id_student,
        course_key,
        gender,
        region,
        age_band,
        highest_education,
        imd_band,
        num_of_prev_attempts,
        studied_credits,
        disability,
        final_result,
        date_registration,
        date_unregistration,
        silver_processed_timestamp,
        silver_processed_date,
        gold_processed_timestamp,
        gold_processed_date
    )
 
    VALUES (
        source.id_student,
        source.course_key,
        source.gender,
        source.region,
        source.age_band,
        source.highest_education,
        source.imd_band,
        source.num_of_prev_attempts,
        source.studied_credits,
        source.disability,
        source.final_result,
        source.date_registration,
        source.date_unregistration,
        source.silver_processed_timestamp,
        source.silver_processed_date,
        current_timestamp(),
        current_date()
    );