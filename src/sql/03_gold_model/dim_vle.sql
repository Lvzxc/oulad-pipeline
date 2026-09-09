CREATE TABLE IF NOT EXISTS oulad.oulad_gold.dim_vle (
    site_key BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_site BIGINT NOT NULL,
    course_key BIGINT NOT NULL REFERENCES oulad.oulad_gold.dim_course(course_key),
    activity_type STRING,
    week_from BIGINT,
    week_to BIGINT,
    silver_processed_timestamp TIMESTAMP,
    silver_processed_date DATE,
    gold_processed_timestamp TIMESTAMP,
    gold_processed_date DATE,
    UNIQUE (id_site, course_key)
);

MERGE INTO oulad.oulad_gold.dim_vle target
USING (
    SELECT
        v.id_site,
        c.course_key,
        v.activity_type,
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
) source
ON target.id_site = source.id_site
   AND target.course_key = source.course_key
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
    source.activity_type,
    source.week_from,
    source.week_to,
    source.silver_processed_timestamp,
    source.silver_processed_date,
    source.gold_processed_timestamp,
    source.gold_processed_date
);
