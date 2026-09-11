CREATE OR REPLACE VIEW oulad.oulad_quality.dq_latest_results AS
WITH ranked AS (
    SELECT
        *,
        ROW_NUMBER() OVER (
            PARTITION BY layer, table_name
            ORDER BY run_timestamp DESC
        ) AS rn
    FROM oulad.oulad_quality.dq_results
)

SELECT
    run_id,
    run_timestamp,
    layer,
    table_name,
    column_name,
    dq_dimension,
    rule_name,
    severity,
    expected_value,
    actual_value,
    total_records,
    passed_records,
    failed_records,
    failure_pct,
    dq_score,
    status
FROM ranked
WHERE rn = 1;