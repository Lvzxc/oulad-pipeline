CREATE TABLE IF NOT EXISTS oulad.oulad_gold.fact_vle_interaction (
    student_key BIGINT NOT NULL,
    course_key BIGINT NOT NULL,
    site_key BIGINT NOT NULL,
    date_key BIGINT NOT NULL,
    sum_click INT,
    gold_processed_timestamp TIMESTAMP,
    gold_processed_date DATE
);

MERGE INTO oulad.oulad_gold.fact_vle_interaction AS tgt
USING (
    SELECT
        ds.student_key,
        dv.course_key,                         
        dv.site_key,                            
        dd.date_key,
        sv.sum_click,
        CURRENT_TIMESTAMP AS gold_processed_timestamp,
        CURRENT_DATE AS gold_processed_date
    FROM oulad.oulad_silver.student_vle_silver sv
    JOIN oulad.oulad_gold.dim_student ds
        ON sv.id_student = ds.id_student
        AND sv.code_module = ds.code_module              
        AND sv.code_presentation = ds.code_presentation  
    JOIN oulad.oulad_gold.dim_vle dv
        ON sv.id_site = dv.id_site
        AND sv.code_module = dv.code_module            
        AND sv.code_presentation = dv.code_presentation  
    JOIN oulad.oulad_gold.dim_date dd
        ON sv.date = dd.date_key
) AS src
ON tgt.student_key = src.student_key
   AND tgt.course_key = src.course_key
   AND tgt.site_key = src.site_key
   AND tgt.date_key = src.date_key
WHEN MATCHED THEN
    UPDATE SET
        tgt.sum_click = src.sum_click,
        tgt.gold_processed_timestamp = src.gold_processed_timestamp,
        tgt.gold_processed_date = src.gold_processed_date
WHEN NOT MATCHED THEN
    INSERT (
        student_key,
        course_key,
        site_key,
        date_key,
        sum_click,
        gold_processed_timestamp,
        gold_processed_date
    )
    VALUES (
        src.student_key,
        src.course_key,
        src.site_key,
        src.date_key,
        src.sum_click,
        src.gold_processed_timestamp,
        src.gold_processed_date
    );
