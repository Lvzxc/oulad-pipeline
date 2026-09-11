SELECT 
    c.code_module,
    ROUND(SUM(v.sum_click) / COUNT(DISTINCT v.student_key), 2) AS avg_clicks_per_student
FROM 
    oulad.oulad_gold.fact_vle_interaction v
JOIN 
    oulad.oulad_gold.dim_course c 
    ON v.course_key = c.course_key
GROUP BY 
    c.code_module
ORDER BY 
    avg_clicks_per_student DESC
LIMIT 5;
