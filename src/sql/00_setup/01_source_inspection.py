# Databricks notebook source
from datetime import datetime
from pyspark.sql import functions as F

# OULAD SOURCE INSPECTION

# Purpose:
#   1. Check that all expected OULAD CSV files exist
#   2. Count rows directly from the source CSV files
#   3. Check basic source information
#   4. Save source row counts as an audit baseline


# 1. SOURCE LOCATION

base_path = "/Volumes/oulad/default/ftw-b12-de-r2/shared/week07/"


# 2. EXPECTED OULAD FILES

expected_files = [
    "assessments.csv",
    "courses.csv",
    "studentAssessment.csv",
    "studentInfo.csv",
    "studentRegistration.csv",
    "studentVle.csv",
    "vle.csv"
]

# 3. FIND CSV FILES IN THE SOURCE LOCATION

files = dbutils.fs.ls(base_path)

csv_files = sorted(
    [
        file.name
        for file in files
        if file.name.lower().endswith(".csv")
    ]
)

print("CSV files found in source:")
for file_name in csv_files:
    print(f" - {file_name}")


# 4. CHECK FOR MISSING FILES

missing_files = [
    file_name
    for file_name in expected_files
    if file_name not in csv_files
]

if missing_files:
    raise ValueError(
        "Source inspection failed. Missing OULAD files:\n"
        + "\n".join(f" - {file}" for file in missing_files)
    )

print("\nAll expected OULAD source files are present.")


# 5. CHECK FOR UNEXPECTED CSV FILES

unexpected_files = [
    file_name
    for file_name in csv_files
    if file_name not in expected_files
]

if unexpected_files:
    print("\nWARNING: Unexpected CSV files found:")
    for file_name in unexpected_files:
        print(f" - {file_name}")

else:
    print("No unexpected CSV files found.")


# 6. SOURCE ROW-COUNT INSPECTION

from datetime import datetime

inspection_time = datetime.now()

queries = []

for file_name in expected_files:

    file_path = f"{base_path}{file_name}"

    source_name = file_name.replace(".csv", "")

    queries.append(
        f"""
        SELECT
            '{source_name}' AS source_file,
            COUNT(*) AS row_count
        FROM read_files(
            '{file_path}',
            format => 'csv',
            header => true,
            inferSchema => true
        )
        """
    )


final_query = "\nUNION ALL\n".join(queries)

source_counts_df = spark.sql(final_query)

source_counts_df = (
    source_counts_df
    .withColumn(
        "inspection_time",
        F.current_timestamp()
    )
    .orderBy("source_file")
)

# 7. DISPLAY SOURCE COUNTS

display(source_counts_df)

# 8. CHECK THAT FILES ARE NOT EMPTY

empty_files = (
    source_counts_df
    .filter(F.col("row_count") == 0)
    .collect()
)

if empty_files:

    empty_file_names = [
        row["source_file"]
        for row in empty_files
    ]

    raise ValueError(
        "Source inspection failed. Empty source files:\n"
        + "\n".join(
            f" - {file}"
            for file in empty_file_names
        )
    )

print("All source files contain records.")


# 9. CREATE SOURCE AUDIT TABLE

spark.sql("""
CREATE TABLE IF NOT EXISTS
    oulad.oulad_quality.source_row_count_audit
(
    source_file STRING,
    row_count BIGINT,
    inspection_time TIMESTAMP
)
USING DELTA
""")

# 10. SAVE SOURCE COUNTS

source_counts_df.createOrReplaceTempView(
    "current_source_counts"
)


spark.sql("""
MERGE INTO
    oulad.oulad_quality.source_row_count_audit AS target

USING
    current_source_counts AS source

ON
    target.source_file = source.source_file

WHEN MATCHED THEN

    UPDATE SET
        target.row_count = source.row_count,
        target.inspection_time = source.inspection_time

WHEN NOT MATCHED THEN

    INSERT
    (
        source_file,
        row_count,
        inspection_time
    )

    VALUES
    (
        source.source_file,
        source.row_count,
        source.inspection_time
    )
""")


# 11. DISPLAY FINAL AUDIT BASELINE

display(
    spark.sql("""
        SELECT
            source_file,
            row_count,
            inspection_time
        FROM oulad.oulad_quality.source_row_count_audit
        ORDER BY source_file
    """)
)
