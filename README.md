# OULAD Data Warehouse and Analytics Pipeline

An end-to-end data engineering project using the **Open University Learning Analytics Dataset (OULAD)** to transform raw learning data into a structured analytical data warehouse and generate insights into student engagement, assessment performance, withdrawal, and course activity.

Built using **Databricks, Delta Lake, Unity Catalog, SQL, and Python**.

---

## Project Overview

The pipeline follows a **Medallion Architecture** to progressively transform and prepare the OULAD data for analytics.

```text
OULAD CSV Files
      │
      ▼
Source Inspection
      │
      ▼
   Bronze
      │
      ▼
   Silver
      │
      ▼
    Gold
      │
      ▼
  Analytics
```

The project focuses on:

* Reliable ingestion of OULAD source data
* Data cleaning and standardization
* Data-quality validation
* Dimensional data modeling
* Student engagement and performance analysis
* Business-oriented analytics

---

## Key Findings

| Business Area                | Key Finding                                                                                                                                                      |
| ---------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Engagement & Performance** | Assessment submission rate does not show a clear linear relationship with average assessment score. Scores remain around **70.5–72.8** across engagement groups. |
| **Withdrawal Patterns**      | Withdrawn students score approximately **10–11 points lower** and submit fewer assessments (**~2.8 vs. ~7.3**).                                                  |
| **Course Activity**          | Active students decrease from approximately **28K to 14K** as the course progresses, while activity increases around assessment periods.                         |
| **Module Engagement**        | **FFF** has the highest average VLE engagement at **1,800+ clicks per student**, while **CCC** has the lowest at approximately **650**.                          |

### Main Takeaways

* Higher assessment participation does **not automatically mean higher scores**.
* Lower assessment participation is strongly associated with **student withdrawal**.
* Student activity changes throughout the course, particularly around **assessment periods**.
* Engagement varies significantly across **course modules**.
* Multiple engagement indicators should be considered rather than relying on a single metric.

---

# Project Architecture

The pipeline uses a **Medallion Architecture** with validation applied across the different layers.

```text
                    OULAD SOURCE FILES
                           │
                           ▼
                   SOURCE INSPECTION
                           │
                           ▼
                    ┌─────────────┐
                    │   BRONZE    │
                    │ Raw Data    │
                    └──────┬──────┘
                           │
                           ▼
                    ┌─────────────┐
                    │   SILVER    │
                    │ Clean Data  │
                    └──────┬──────┘
                           │
                           ▼
                    ┌─────────────┐
                    │    GOLD     │
                    │ Star Schema │
                    └──────┬──────┘
                           │
                           ▼
                     ANALYTICS
```

---

# Pipeline Layers

| Layer | Purpose | Key Activities |
|---|---|---|
| **Source Inspection** | Validates incoming OULAD files before ingestion | Checks expected/unexpected files, detects missing or empty files, records source row counts, and establishes a data-quality baseline |
| **Bronze** | Stores the raw source data in Delta tables | Preserves source structure, adds ingestion metadata, and provides the foundation for downstream processing |
| **Silver** | Creates clean and standardized datasets | Standardizes data types and categories, handles missing/sentinel values, applies business rules, and removes duplicates or invalid records |
| **Gold** | Creates the analytical data warehouse | Builds fact and dimension tables, uses surrogate keys, defines fact grain, and retains source identifiers for traceability |
| **Analytics** | Uses Gold data to answer business questions | Analyzes student engagement and performance, withdrawal patterns, course activity, and module-level engagement |
---

# Gold Data Model

The Gold layer consists of **two fact tables** and **five dimensions**.

## Fact Tables

| Fact Table             | Grain                                                 | Main Measures        |
| ---------------------- | ----------------------------------------------------- | -------------------- |
| `fact_assessment`      | One row per student-course-assessment-submission date | `score`, `is_banked` |
| `fact_vle_interaction` | One row per student-course-site-relative date         | `sum_click`          |

## Dimension Tables

| Dimension        | Grain                           | Purpose                                    |
| ---------------- | ------------------------------- | ------------------------------------------ |
| `dim_student`    | One row per student-course      | Student and course presentation attributes |
| `dim_course`     | One row per course presentation | Course and module information              |
| `dim_assessment` | One row per assessment          | Assessment type, date, and weight          |
| `dim_vle`        | One row per VLE site per course | VLE resource and activity information      |
| `dim_date`       | One row per relative day        | Course-relative date and week information  |

---

# Star Schema

```text
                         dim_student
                              │
                              ▼
                       fact_assessment
                       /      │       \
                      ▼       ▼        ▼
               dim_course  dim_assessment  dim_date


                         dim_student
                              │
                              ▼
                    fact_vle_interaction
                     /       │        \
                    ▼        ▼         ▼
              dim_course   dim_vle   dim_date
```

The star schema separates **measurable events** in the fact tables from **descriptive attributes** in the dimension tables, making the data easier to query and analyze.

---

# Relative Date Design

OULAD uses **relative days** rather than conventional calendar dates.

Examples:

```text
-30 → 30 days before the course reference point
  0 → Course reference point
+10 → 10 days after the reference point
```

The pipeline uses a shared `dim_date` based on these relative days.

This allows student assessment and VLE activity to be compared based on **course progress**, even when different course presentations have different schedules.

---

# Data Validation

Data quality checks are applied throughout the pipeline to identify issues early and protect the reliability of the analytical layer.

| Layer         | Validation Focus                                                  |
| ------------- | ----------------------------------------------------------------- |
| **Source**    | Files, missing/empty files, and source row counts                 |
| **Bronze**    | Ingestion completeness, columns, row counts, and metadata         |
| **Silver**    | Required fields, data types, valid values, ranges, and duplicates |
| **Gold**      | Keys, relationships, referential integrity, and fact grain        |
| **Analytics** | Measures, analytical grain, and business-rule consistency         |

This layered approach helps ensure that problems are identified before they affect downstream analytics.

---

# How to Run

### Prerequisites

* Databricks workspace
* Unity Catalog access
* Databricks SQL Warehouse
* OULAD dataset
* OULAD CSV files available in the configured Databricks Volume

### Run Order

### 1. Clone the Repository
git clone https://github.com/Lvzxc/oulad-pipeline.git
cd oulad-pipeline
### 2. Connect the Repository to Databricks

**In Databricks:**

- Open Workspace.
- Select Git folders.
- Create a new Git folder.
- Enter the GitHub repository URL.
- Select the appropriate branch.
- Create the Git folder.

### 3. Prepare the OULAD Source Files

Place the following files in the configured Databricks Volume:

assessments.csv
courses.csv
studentAssessment.csv
studentInfo.csv
studentRegistration.csv
studentVle.csv
vle.csv

**Execute the pipeline in the following order:**

```text
1. Setup
2. Source Inspection
3. Bronze Ingestion
4. Bronze Validation
5. Silver Transformation
6. Silver Validation
7. Gold Modeling
8. Gold Validation
9. Analytics
10. Analytics Validation
```

The corresponding scripts are organized under:

```text
src/sql/
tests/
```

---

# Documentation

Additional project documentation is available in the `docs/` directory.

| Document | Description |
|---|---|
| [`architecture.md`](docs/architecture.md) | Pipeline architecture and data flow |
| [`data-model.md`](docs/data-model.md) | Gold-layer star schema and table design |
| [`decisions.md`](docs/decisions.md) | Key technical and data-modeling decisions |
| [`bronze_data_quality_results.md`](docs/data_quality/bronze_data_quality_results.md) | Bronze-layer data-quality validation results |
| [`silver_data_quality_results.md`](docs/data_quality/silver_data_quality_results.md) | Silver-layer data-quality validation results |
| [`gold_data_quality_results.md`](docs/data_quality/gold_data_quality_results.md) | Gold-layer data-quality validation results |

---

# Project Outcome

The project demonstrates an end-to-end approach to building a **validated analytical data warehouse** from raw learning analytics data.

It combines structured data engineering practices with business-focused analytics to better understand **student engagement, academic performance, withdrawal patterns, and course activity**.
