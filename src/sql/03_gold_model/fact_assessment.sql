CREATE TABLE IF NOT EXISTS oulad.oulad_gold.fact_assessment (
    student_key BIGINT NOT NULL,
    course_key BIGINT NOT NULL,
    assessment_key BIGINT NOT NULL,
    date_key BIGINT NOT NULL,   
    score INT,
    is_banked INT,
    gold_processed_timestamp TIMESTAMP,
    gold_processed_date DATE
);

MERGE INTO oulad.oulad_gold.fact_assessment AS tgt
USING (
    SELECT
        ds.student_key,
        da.course_key,
        da.assessment_key,
        dd.date_key,                         
        sa.score,
        sa.is_banked,
        CURRENT_TIMESTAMP AS gold_processed_timestamp,
        CURRENT_DATE AS gold_processed_date
    FROM oulad.oulad_silver.student_assessment_silver sa
    JOIN oulad.oulad_gold.dim_assessment da
        ON sa.id_assessment = da.id_assessment
    JOIN oulad.oulad_gold.dim_student ds
        ON sa.id_student = ds.id_student
        AND da.code_module = ds.code_module
        AND da.code_presentation = ds.code_presentation
    JOIN oulad.oulad_gold.dim_date dd
        ON sa.date_submitted = dd.relative_day
) AS src
ON tgt.student_key = src.student_key
   AND tgt.course_key = src.course_key
   AND tgt.assessment_key = src.assessment_key
   AND tgt.date_key = src.date_key
WHEN MATCHED THEN
    UPDATE SET
        tgt.score = src.score,
        tgt.is_banked = src.is_banked,
        tgt.gold_processed_timestamp = src.gold_processed_timestamp,
        tgt.gold_processed_date = src.gold_processed_date
WHEN NOT MATCHED THEN
    INSERT (
        student_key,
        course_key,
        assessment_key,
        date_key,
        score,
        is_banked,
        gold_processed_timestamp,
        gold_processed_date
    )
    VALUES (
        src.student_key,
        src.course_key,
        src.assessment_key,
        src.date_key,
        src.score,
        src.is_banked,
        src.gold_processed_timestamp,
        src.gold_processed_date
    );
