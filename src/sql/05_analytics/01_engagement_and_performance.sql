-- BUSINESS QUESTION:
-- How does student engagement relate to performance?
-- Engagement = assessment submission rate
-- Performance = average assessment score
-- Grain = one row per student per course

WITH course_assessment_counts AS (
    SELECT
        course_key,
        COUNT(*) AS total_assessments  -- Total assessments for the course
    FROM oulad.oulad_gold.dim_assessment
    GROUP BY course_key
),

student_engagement AS (
    SELECT
        fa.student_key,
        fa.course_key,
        SUM(CASE
            WHEN fa.date_submitted_key >= 0 THEN 1
            ELSE 0
        END) AS assessments_submitted,  -- Number of submitted assessments
        AVG(CASE
            WHEN fa.date_submitted_key >= 0
            THEN fa.score
        END) AS avg_score  -- Average score from submitted assessments
    FROM oulad.oulad_gold.fact_assessment fa
    GROUP BY fa.student_key, fa.course_key
),

student_summary AS (
    SELECT
        se.student_key,
        se.course_key,
        se.assessments_submitted,
        cac.total_assessments,
        ROUND(
            se.assessments_submitted * 1.0 / cac.total_assessments, 3
        ) AS submission_rate,  -- % of assessments submitted
        se.avg_score

    FROM student_engagement se
    JOIN course_assessment_counts cac
        ON se.course_key = cac.course_key
),

bucketed AS (
    SELECT
        *,
        CASE
            WHEN submission_rate < 0.20 THEN '0-20%'
            WHEN submission_rate < 0.40 THEN '20-40%'
            WHEN submission_rate < 0.60 THEN '40-60%'
            WHEN submission_rate < 0.80 THEN '60-80%'
            ELSE '80-100%'
        END AS engagement_bucket,  -- Groups students by engagement
        CASE
            WHEN submission_rate < 0.20 THEN 1
            WHEN submission_rate < 0.40 THEN 2
            WHEN submission_rate < 0.60 THEN 3
            WHEN submission_rate < 0.80 THEN 4
            ELSE 5
        END AS bucket_order  -- Keeps buckets in order
    FROM student_summary

)

SELECT
    engagement_bucket,
    COUNT(*) AS num_students,  -- Number of students in each bucket
    ROUND(AVG(submission_rate) * 100, 1) AS avg_submission_rate_pct,  -- Avg engagement
    ROUND(AVG(avg_score), 1) AS avg_score  -- Avg performance
FROM bucketed

GROUP BY engagement_bucket, bucket_order

ORDER BY bucket_order;