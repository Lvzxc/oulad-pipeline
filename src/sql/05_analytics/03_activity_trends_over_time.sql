-- BUSINESS QUESTION:
-- How does student activity change throughout a course, REGARDLESS
-- of course duration?
-- Activity = VLE clicks (sum_click)
-- Course progress = percentage through the course (0-100%), binned
-- into deciles so every course-presentation contributes to every bin.

WITH course_length AS (
    SELECT
        course_key,
        code_module,
        code_presentation,
        module_presentation_length
    FROM oulad.oulad_gold.dim_course
),

student_daily_activity AS (
    SELECT
        f.student_key,
        f.course_key,
        dd.relative_day,
        f.sum_click
    FROM oulad.oulad_gold.fact_vle_interaction f
    JOIN oulad.oulad_gold.dim_date dd
        ON f.date_key = dd.date_key
),

activity_with_progress AS (
    SELECT
        sda.student_key,
        cl.code_module,
        cl.code_presentation,
        sda.sum_click,

        -- Percentage through the course, 0.0 to 1.0
        sda.relative_day * 1.0 / cl.module_presentation_length AS pct_through_course

    FROM student_daily_activity sda
    JOIN course_length cl
        ON sda.course_key = cl.course_key

    WHERE sda.relative_day BETWEEN 0 AND cl.module_presentation_length
),

decile_binned AS (
    SELECT
        *,
        -- Deciles: 0-10%, 10-20%, ... 90-100%. Every course contributes
        -- to every decile, since percentage is length-independent.
        LEAST(FLOOR(pct_through_course * 10), 9) AS decile
    FROM activity_with_progress
)

SELECT
    decile,
    CONCAT(decile * 10, '-', (decile + 1) * 10, '%') AS course_progress_bucket,
    COUNT(DISTINCT code_module || '-' || code_presentation) AS courses_with_data,  -- should be constant across every row now
    COUNT(DISTINCT student_key) AS active_students,
    SUM(sum_click) AS total_clicks,
    ROUND(SUM(sum_click) * 1.0 / COUNT(DISTINCT student_key), 1) AS avg_clicks_per_active_student

FROM decile_binned

GROUP BY decile
ORDER BY decile;