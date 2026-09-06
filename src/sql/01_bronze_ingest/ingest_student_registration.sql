CREATE TABLE IF NOT EXISTS oulad.oulad_bronze.student_registration_bronze
USING DELTA
AS
SELECT *,
  current_timestamp() AS ingestion_timestamp,
  current_date() AS ingestion_date
FROM read_files('/Volumes/oulad/default/ftw-b12-de-r2/shared/week07/studentRegistration.csv');

