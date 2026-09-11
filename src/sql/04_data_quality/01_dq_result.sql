DROP TABLE IF EXISTS oulad.oulad_quality.dq_results;

CREATE TABLE oulad.oulad_quality.dq_results (
    run_id STRING,
    run_timestamp TIMESTAMP,
    layer STRING,
    table_name STRING,
    column_name STRING,
    dq_dimension STRING,
    rule_name STRING,
    severity STRING,
    expected_value STRING,
    actual_value STRING,
    total_records BIGINT,
    passed_records BIGINT,
    failed_records BIGINT,
    failure_pct DOUBLE,
    dq_score DOUBLE,
    status STRING
);