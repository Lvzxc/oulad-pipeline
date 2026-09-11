CREATE TABLE IF NOT EXISTS oulad.oulad_gold.dim_vle (
    site_key BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_site BIGINT NOT NULL,
    course_key BIGINT NOT NULL REFERENCES oulad.oulad_gold.dim_course(course_key),
    code_module STRING,        
    code_presentation STRING,   
    activity_type STRING,
    week_from BIGINT,
    week_to BIGINT,
    silver_processed_timestamp TIMESTAMP,
    silver_processed_date DATE,
    gold_processed_timestamp TIMESTAMP,
    gold_processed_date DATE,
    UNIQUE (id_site, course_key)
);

MERGE INTO oulad.oulad_gold.dim_vle AS target
USING (
    SELECT
        v.id_site,
        c.course_key,
        v.code_module,            
        v.code_presentation,      
        CAST(LOWER(TRIM(v.activity_type)) AS STRING) AS activity_type,
        v.week_from,
        v.week_to,
        CURRENT_TIMESTAMP AS silver_processed_timestamp,
        CURRENT_DATE AS silver_processed_date,
        CURRENT_TIMESTAMP AS gold_processed_timestamp,
        CURRENT_DATE AS gold_processed_date
    FROM oulad.oulad_silver.vle_silver v
    INNER JOIN oulad.oulad_gold.dim_course c
        ON v.code_module = c.code_module
        AND v.code_presentation = c.code_presentation
) AS source
ON target.id_site = source.id_site
   AND target.course_key = source.course_key
   AND target.code_module = source.code_module         
   AND target.code_presentation = source.code_presentation 
WHEN MATCHED THEN UPDATE SET
    target.activity_type = source.activity_type,
    target.week_from = source.week_from,
    target.week_to = source.week_to,
    target.silver_processed_timestamp = source.silver_processed_timestamp,
    target.silver_processed_date = source.silver_processed_date,
    target.gold_processed_timestamp = source.gold_processed_timestamp,
    target.gold_processed_date = source.gold_processed_date
WHEN NOT MATCHED THEN INSERT (
    id_site,
    course_key,
    code_module,
    code_presentation,
    activity_type,
    week_from,
    week_to,
    silver_processed_timestamp,
    silver_processed_date,
    gold_processed_timestamp,
    gold_processed_date
) VALUES (
    source.id_site,
    source.course_key,
    source.code_module,
    source.code_presentation,
    source.activity_type,
    source.week_from,
    source.week_to,
    source.silver_processed_timestamp,
    source.silver_processed_date,
    source.gold_processed_timestamp,
    source.gold_processed_date
);
