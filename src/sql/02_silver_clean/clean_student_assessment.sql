-- Create the clean table for student assessment
CREATE TABLE IF NOT EXISTS oulad.oulad_silver.student_assessment_silver (
    id_assessment INT,
    id_student INT,
    date_submitted INT, -- Can have negative values
    is_banked INT, -- Can only have 0 or 1
    score DOUBLE, -- Assessment score converted from STRING to DOUBLE for calculation purposes
    ingestion_timestamp TIMESTAMP,
    ingestion_date DATE
);

-- Merge cleaned data from bronze table
MERGE INTO oulad.oulad_silver.student_assessment_silver AS target 

USING (
    -- OUTER LAYER: filters on the CASTED columns , and only keeps rn = 1 rows to guarantee one row per grain key
    SELECT
        id_assessment,
        id_student,
        date_submitted,
        is_banked,
        score,
        ingestion_timestamp,
        ingestion_date
    FROM (
        -- INNER LAYER: same casts you already had, plus a ROW_NUMBER() to rank duplicate (id_assessment, id_student) rows by recency
        SELECT
            TRY_CAST(id_assessment AS INT) AS id_assessment,
            TRY_CAST(id_student AS INT) AS id_student,
            TRY_CAST(date_submitted AS INT) AS date_submitted,
            TRY_CAST(is_banked AS INT) AS is_banked,
            -- Clean and convert score, trims unnecessary spaces, converts ? into NULL and converts to DOUBLE
            TRY_CAST(NULLIF(TRIM(score), '?') AS DOUBLE) AS score,
            ingestion_timestamp,
            CAST(ingestion_timestamp AS DATE) AS ingestion_date,
            ROW_NUMBER() OVER (
                PARTITION BY TRY_CAST(id_assessment AS INT), TRY_CAST(id_student AS INT)
                ORDER BY ingestion_timestamp DESC
            ) AS rn
        FROM oulad.oulad_bronze.student_assessment_bronze
    ) ranked
    WHERE rn = 1
      AND id_assessment IS NOT NULL   -- now checks the CASTED value, not raw bronze
      AND id_student IS NOT NULL      -- now checks the CASTED value, not raw bronze
) AS source

ON target.id_assessment = source.id_assessment -- Match condition
AND target.id_student = source.id_student -- Match condition

-- When it student assessment record already exists, update the record with incoming values
WHEN MATCHED THEN 
    UPDATE SET
        target.date_submitted = source.date_submitted,
        target.is_banked = source.is_banked,
        target.score = source.score,
        target.ingestion_timestamp = source.ingestion_timestamp,
        target.ingestion_date = source.ingestion_date

-- When it student assessment record does not exist, insert the record
WHEN NOT MATCHED THEN
    INSERT (
        id_assessment,
        id_student,
        date_submitted,
        is_banked,
        score,
        ingestion_timestamp,
        ingestion_date
    )
    VALUES (
        source.id_assessment,
        source.id_student,
        source.date_submitted,
        source.is_banked,
        source.score,
        source.ingestion_timestamp,
        source.ingestion_date
    );