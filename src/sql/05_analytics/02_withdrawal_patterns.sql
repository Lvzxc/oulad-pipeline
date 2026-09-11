-- Calculate average assessment scores and submission counts by age band and retention status
SELECT 
    ds.age_band,
    
    -- Group outcomes into a binary status for easier side-by-side comparison
    CASE 
        WHEN ds.final_result = 'Withdrawn' THEN 'Withdrawn'
        ELSE 'Retained'
    END AS retention_status,
    
    -- Calculate the average score across all submitted assessments
    ROUND(AVG(fa.score), 2) AS avg_score,
    
    -- Calculate the average number of assessments submitted per active student
    ROUND(COUNT(fa.assessment_key) * 1.0 / COUNT(DISTINCT ds.student_key), 2) AS avg_submission_count

FROM oulad.oulad_gold.fact_assessment fa
INNER JOIN oulad.oulad_gold.dim_student ds
    ON fa.student_key = ds.student_key
GROUP BY 
    ds.age_band,
    CASE 
        WHEN ds.final_result = 'Withdrawn' THEN 'Withdrawn'
        ELSE 'Retained'
    END
ORDER BY 
    ds.age_band ASC,
    retention_status