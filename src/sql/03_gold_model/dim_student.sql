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
    student_key BIGINT GENERATED ALWAYS AS IDENTITY (START WITH 1 INCREMENT BY 1), -- PK
    id_student BIGINT,
    course_key BIGINT,
    code_module STRING,          
    code_presentation STRING,   
    gender STRING,
    region STRING,
    age_band STRING,
    highest_education STRING,
    imd_band STRING,
    num_of_prev_attempts BIGINT,
    studied_credits BIGINT,
    disability STRING,
    final_result STRING,
    date_registration BIGINT,
    date_unregistration BIGINT,
    silver_processed_timestamp TIMESTAMP,
    silver_processed_date DATE,
    gold_processed_timestamp TIMESTAMP,
    gold_processed_date DATE,
    PRIMARY KEY (student_key)
);

-- STEP 2A: DEDUPLICATE STUDENT INFORMATION
CREATE OR REPLACE TEMP VIEW ranked_students AS
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
        PARTITION BY si.id_student, si.code_module, si.code_presentation
        ORDER BY si.silver_processed_timestamp DESC NULLS LAST,
                 xxhash64(
                     si.gender, si.region, si.age_band,
                     si.highest_education, si.imd_band,
                     si.num_of_prev_attempts, si.studied_credits,
                     si.disability, si.final_result
                 ) DESC
    ) AS row_num
FROM oulad.oulad_silver.student_info_silver si;

-- STEP 2B: DEDUPLICATE REGISTRATION INFORMATION
CREATE OR REPLACE TEMP VIEW ranked_registration AS
SELECT
    sr.id_student,
    sr.code_module,
    sr.code_presentation,
    sr.date_registration,
    sr.date_unregistration,
    ROW_NUMBER() OVER (
        PARTITION BY sr.id_student, sr.code_module, sr.code_presentation
        ORDER BY sr.ingestion_timestamp DESC NULLS LAST,
                 xxhash64(sr.date_registration, sr.date_unregistration) DESC
    ) AS row_num
FROM oulad.oulad_silver.student_registration_silver sr;

-- STEP 2C: BUILD THE FINAL GOLD-READY RECORD
CREATE OR REPLACE TEMP VIEW dim_student_ready AS
SELECT
    rs.id_student,
    dc.course_key,
    rs.code_module,
    rs.code_presentation,
    rs.gender,
    rs.region,
    rs.age_band,
    rs.highest_education,
    rs.imd_band,
    rs.num_of_prev_attempts,
    rs.studied_credits,
    rs.disability,
    rs.final_result,
    rr.date_registration,
    rr.date_unregistration,
    rs.silver_processed_timestamp,
    rs.silver_processed_date
FROM ranked_students rs
INNER JOIN oulad.oulad_gold.dim_course dc
    ON rs.code_module = dc.code_module
    AND rs.code_presentation = dc.code_presentation
LEFT JOIN ranked_registration rr
    ON rs.id_student = rr.id_student
    AND rs.code_module = rr.code_module
    AND rs.code_presentation = rr.code_presentation
    AND rr.row_num = 1
WHERE rs.row_num = 1;

-- STEP 3: MERGE INTO GOLD
MERGE INTO oulad.oulad_gold.dim_student AS target
USING dim_student_ready AS source
ON target.id_student = source.id_student
AND target.course_key = source.course_key
AND target.code_module = source.code_module
AND target.code_presentation = source.code_presentation
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
        target.silver_processed_timestamp = source.silver_processed_timestamp,
        target.silver_processed_date = source.silver_processed_date,
        target.gold_processed_timestamp = current_timestamp(),
        target.gold_processed_date = current_date()
WHEN NOT MATCHED THEN
    INSERT (
        id_student, course_key, code_module, code_presentation,
        gender, region, age_band, highest_education, imd_band,
        num_of_prev_attempts, studied_credits, disability, final_result,
        date_registration, date_unregistration,
        silver_processed_timestamp, silver_processed_date,
        gold_processed_timestamp, gold_processed_date
    )
    VALUES (
        source.id_student, source.course_key, source.code_module, source.code_presentation,
        source.gender, source.region, source.age_band, source.highest_education, source.imd_band,
        source.num_of_prev_attempts, source.studied_credits, source.disability, source.final_result,
        source.date_registration, source.date_unregistration,
        source.silver_processed_timestamp, source.silver_processed_date,
        current_timestamp(), current_date()
    );

