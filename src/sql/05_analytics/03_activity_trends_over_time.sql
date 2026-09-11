-- BUSINESS QUESTION:
-- How does student activity change throughout a course?
-- Activity = VLE clicks (sum_click)
-- Course progress = percentage through the course, based on relative_day
-- Grain = one row per student per course per week, keeping full week-level
-- detail per course-presentation

WITH course_length AS (
    SELECT
        course_key,
        code_module,
        code_presentation,
        module_presentation_length
    FROM oulad.oulad_gold.dim_course
),

student_weekly_activity AS (
    SELECT
        f.student_key,
        f.course_key,
        dd.relative_day,
        dd.relative_week,
        f.sum_click
    FROM oulad.oulad_gold.fact_vle_interaction f
    JOIN oulad.oulad_gold.dim_date dd
        ON f.date_key = dd.date_key
),

activity_in_course AS (
    SELECT
        swa.student_key,
        cl.code_module,
        cl.code_presentation,
        swa.relative_week,
        swa.sum_click,
        -- pct_through_course anchored to the week's own relative_day,
        -- so it's a genuine, exact conversion, not an approximation
        ROUND(swa.relative_day * 1.0 / cl.module_presentation_length, 3) AS pct_through_course

    FROM student_weekly_activity swa
    JOIN course_length cl
        ON swa.course_key = cl.course_key

    WHERE swa.relative_day BETWEEN 0 AND cl.module_presentation_length
)

SELECT
    code_module,
    code_presentation,
    relative_week,
    ROUND(AVG(pct_through_course), 3) AS avg_pct_through_course,  -- avg across days within this week
    COUNT(DISTINCT student_key) AS active_students,
    SUM(sum_click) AS total_clicks,
    ROUND(SUM(sum_click) * 1.0 / COUNT(DISTINCT student_key), 1) AS avg_clicks_per_active_student

FROM activity_in_course

GROUP BY code_module, code_presentation, relative_week
ORDER BY code_module, code_presentation, relative_week;