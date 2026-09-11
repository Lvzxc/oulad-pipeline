-- BUSINESS QUESTION:
-- How does student engagement relate to performance?
--
-- Engagement = assessment submission rate
-- Performance = average assessment score
-- Grain = one row per student per course


WITH student_assessment_summary AS (

    SELECT
        fa.student_key,
        fa.course_key,

        -- Total assessments associated with the student and course
        COUNT(*) AS total_assessments,

        -- Number of assessments submitted
        SUM(
            CASE
                WHEN dd.relative_day <> -1
                THEN 1
                ELSE 0
            END
        ) AS assessments_submitted,

        -- Average score from submitted assessments
        AVG(fa.score) AS avg_score

    FROM oulad.oulad_gold.fact_assessment fa

    JOIN oulad.oulad_gold.dim_date dd
        ON fa.date_key = dd.date_key

    GROUP BY
        fa.student_key,
        fa.course_key
),


student_summary AS (

    SELECT
        student_key,
        course_key,

        total_assessments,
        assessments_submitted,

        -- Engagement
        ROUND(
            CAST(assessments_submitted AS DOUBLE)
            / NULLIF(total_assessments, 0),
            3
        ) AS submission_rate,

        -- Performance
        ROUND(avg_score, 2) AS avg_score

    FROM student_assessment_summary
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
        END AS engagement_bucket,

        CASE
            WHEN submission_rate < 0.20 THEN 1
            WHEN submission_rate < 0.40 THEN 2
            WHEN submission_rate < 0.60 THEN 3
            WHEN submission_rate < 0.80 THEN 4
            ELSE 5
        END AS bucket_order

    FROM student_summary
)


SELECT
    engagement_bucket,

    COUNT(*) AS num_students,

    ROUND(
        AVG(submission_rate) * 100,
        1
    ) AS avg_submission_rate_pct,

    ROUND(
        AVG(avg_score),
        1
    ) AS avg_score

FROM bucketed

WHERE avg_score IS NOT NULL

GROUP BY
    engagement_bucket,
    bucket_order

ORDER BY
    bucket_order;