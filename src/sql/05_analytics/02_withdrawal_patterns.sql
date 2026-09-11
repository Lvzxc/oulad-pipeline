-- Calculate average weekly clicks for students who withdrew and retained
SELECT 
    -- Group outcomes into a binary status for easier side-by-side comparison
    CASE 
        WHEN ds.final_result = 'Withdrawn' THEN 'Withdrawn'
        ELSE 'Retained'
    END AS retention_status,
    
    dd.relative_week,
    
    -- Calculate the true average by dividing total clicks by unique active students.
    ROUND(SUM(fvi.sum_click) / COUNT(DISTINCT fvi.student_key), 2) AS avg_weekly_clicks_per_student

FROM oulad.oulad_gold.fact_vle_interaction fvi
INNER JOIN oulad.oulad_gold.dim_student ds
    ON fvi.student_key = ds.student_key
INNER JOIN oulad.oulad_gold.dim_date dd
    ON fvi.date_key = dd.date_key
-- Limit the timeline from 4 weeks prior to start, up to the typical 40-week course end
WHERE dd.relative_week BETWEEN -4 AND 40
GROUP BY 
    CASE 
        WHEN ds.final_result = 'Withdrawn' THEN 'Withdrawn'
        ELSE 'Retained'
    END,
    dd.relative_week
ORDER BY 
    dd.relative_week ASC,
    retention_status;