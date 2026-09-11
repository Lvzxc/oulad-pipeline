# OULAD Data Warehouse and Pipeline

This project uses Databricks SQL, Delta Lake, Unity Catalog, and GitHub Actions to build an end-to-end data pipeline from the Open University Learning Analytics Dataset (OULAD). The design follows the Medallion Architecture and organizes the workflow into Bronze, Silver, Gold, Analytics, and Tests layers.

## Project objective
This project transforms source CSV files into a dimensional data warehouse that supports student, course, assessment, and activity analysis.

It demonstrates:

- End-to-end data engineering in Databricks
- Medallion Architecture
- Delta table creation and incremental `MERGE` operations
- Data cleaning, standardization, and integration
- A Gold-layer star schema for reporting
- Business-oriented analytical queries

## Tools used

- Databricks SQL
- Delta Lake
- Unity Catalog
- Databricks SQL Warehouse
- GitHub
- OULAD dataset

## Data pipeline

The pipeline follows this order:

```text
OULAD Source CSV Files
          │
          ▼
   Source Inspection
          │
          ▼
        Bronze
          │
          ▼
    Bronze Tests
          │
          ▼
        Silver
          │
          ▼
    Silver Tests
          │
          ▼
         Gold
          │
          ▼
     Gold Tests
          │
          ▼
      Analytics
          │
          ▼
    Analytics Tests
```

| Layer                 | Purpose                                                                                                                                                 |
| --------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Source**            | Original OULAD CSV files stored in a Databricks Volume.                                                                                                 |
| **Source Inspection** | Checks that expected source files are available, inspects source row counts, detects empty or unexpected files, and records source counts for auditing. |
| **Bronze**            | Ingests the source CSV records into raw Delta tables while preserving the source data and adding ingestion metadata.                                    |
| **Bronze Tests**      | Checks the completeness and structural quality of the Bronze data.                                                                                      |
| **Silver**            | Cleans, standardizes, casts, validates, and deduplicates the Bronze data.                                                                               |
| **Silver Tests**      | Validates cleaned data, accepted values, ranges, required fields, and other Silver-layer rules.                                                         |
| **Gold**              | Builds the dimensional data warehouse using fact and dimension tables.                                                                                  |
| **Gold Tests**        | Validates Gold-layer relationships, uniqueness, referential integrity, and fact-table grain.                                                            |
| **Analytics**         | Contains business-oriented queries and views used to answer analytical questions.                        
                                                                                               


Each layer has one responsibility. Preview queries and validation logic are kept separate from the production transformation files.

## PIPELINE LAYERS

## Source Data

The project uses the Open University Learning Analytics Dataset (OULAD).

The original CSV files are stored outside the Git repository in a Databricks Volume.

The pipeline uses the following OULAD source datasets:
```text
assessments.csv
courses.csv
studentAssessment.csv
studentInfo.csv
studentRegistration.csv
studentVle.csv
vle.csv
```
The source data is not committed to GitHub.

## Source Inspection

Source inspection is performed before Bronze ingestion.
The purpose of this step is to establish what was received from the source before the data is transformed or loaded into Bronze.

The source inspection performs the following checks:

**File Availability** 

- Checks that the expected OULAD CSV files exist in the configured source location.

**Missing Files** 

- The inspection fails when an expected source file is missing.

**Unexpected Files**

- Additional CSV files that are not part of the expected OULAD source set are reported.

**Source Row Counts**

- Each source CSV file is read directly and its number of records is recorded.

**Empty Files**

- Source files containing zero records are treated as a source-quality failure.

**Source Audit**

- Source row counts are stored in a Delta audit table.

This provides a source baseline that can be used by downstream data-quality checks instead of relying on hardcoded row counts.

## Bronze Layer

The Bronze layer contains the raw OULAD data ingested into Delta tables.

The purpose of Bronze is to preserve the source data in a queryable Delta format while adding ingestion metadata.

Examples include:
```text
assessment_bronze
courses_bronze
student_assessment_bronze
student_info_bronze
student_registration_bronze
student_vle_bronze
vle_bronze
```
Bronze is intentionally kept close to the original source structure.

Typical ingestion metadata includes:
```text
ingestion_timestamp
ingestion_date
```

Cleaning and business transformations are handled in the Silver layer.

## Silver Layer

The Silver layer cleans, standardizes, validates, and prepares the raw Bronze OULAD data for the Gold dimensional model.

The main responsibilities of the Silver layer are:

- Standardizing data types
- Cleaning and standardizing text fields
- Handling OULAD sentinel values such as `?`
- Validating required fields
- Applying business rules and value checks
- Deduplicating records
- Preserving data lineage
- Preparing consistent datasets for Gold-layer joins

## Silver Transformations

| Silver Dataset | Main Transformations |
|---|---|
| `student_registration_silver` | Standardizes course codes, handles registration and unregistration values, removes records with missing required keys, and deduplicates by student and course. |
| `courses_silver` | Standardizes course codes, removes exact duplicates, validates course presentation length, and removes records with invalid course keys. |
| `vle_silver` | Standardizes course codes and activity types, validates site IDs, handles missing week values, and removes duplicates. |
| `student_vle_silver` | Standardizes data types and categorical fields, handles missing dates, and deduplicates records using the business key. |
| `student_info_silver` | Standardizes categorical fields, handles missing `imd_band`, validates required student and course fields, and keeps the latest record per student and course. |
| `assessment_silver` | Standardizes assessment fields, converts `?` dates to `NULL`, validates assessment IDs, deduplicates records, and retains assessments with missing dates where appropriate. |

## Data Cleaning and Validation

### Data Types

Source fields are explicitly cast to appropriate data types such as:

- `STRING` for categorical and course-related fields
- `BIGINT` for identifiers
- `INT` for numeric fields and relative-day values
- `DOUBLE` for assessment weights

### Standardization

Text fields are trimmed and standardized to prevent inconsistencies during downstream joins.

Examples include:

- Uppercase `code_module`
- Uppercase `code_presentation`
- Lowercase `activity_type`

### Null and Sentinel Values

OULAD uses `?` as a sentinel value for missing information.

Where appropriate, these values are converted to `NULL`.

Required business-key fields are removed when missing, while valid missing values are retained when they represent meaningful source information.

For example, a missing `date_unregistration` is retained because it can represent a student who did not unregister.

Assessment records with missing assessment dates are also retained because a missing date does not necessarily invalidate the assessment.

### Deduplication

`ROW_NUMBER()` is used to control duplicate records and retain the latest available record based on ingestion timestamp where appropriate.

For datasets such as courses, exact duplicates are removed using `SELECT DISTINCT`.

### Business Rules

Silver validation includes rules such as:

- Required identifiers must be present.
- Assessment types must contain accepted values such as `TMA`, `CMA`, or `Exam`.
- Assessment weights must fall within the expected range.
- Course presentation length must be greater than zero.
- VLE site identifiers must be present.

## OULAD Relative Dates

OULAD uses relative-day values rather than actual calendar dates.

For example:

```text
-30 = 30 days before the course reference point
0   = course reference point
10  = 10 days after the reference point
```

Gold Layer
-The Gold layer contains the analytical data warehouse. The warehouse uses a star schema consisting of fact and dimension tables.
- The Gold layer uses surrogate keys for relationships between fact and dimension tables while retaining natural keys where needed for source traceability.

## Gold data model

The Gold layer uses a star schema centered on
<img width="1345" height="1041" alt="Oulad Star Schema" src="https://github.com/user-attachments/assets/2500ff7b-064e-46d2-b6e6-5dc4d4d25107" />

## Fact Tables
1. `fact_assessment`
Grain: One row per student-course-assessment-submission date.
Each record represents a student's assessment record for a specific assessment in a course presentation.

Columns
```text
student_key
course_key
assessment_key
date_key
score
is_banked
gold_processed_timestamp
gold_processed_date
Date Relationship
```
The `date_key` is linked to `dim_date`.

The assessment fact obtains its date from:

student_assessment_silver.date_submitted

which is matched to:

`dim_date.relative_day`

The resulting surrogate key is stored as:

`fact_assessment.date_key`

The relationship is:
```text
student_assessment_silver
          │
          │ date_submitted
          ▼
dim_date.relative_day
          │
          │ date_key
          ▼
fact_assessment
```
Therefore, fact_assessment.date_key represents the assessment submission date.

The score field is used to measure assessment performance.

2.`fact_vle_interaction`

Grain: One row per student-course-site-date.
Each record represents the total number of clicks made by a student on a specific VLE site for a course on a particular relative day.

Columns
```text
student_key
course_key
site_key
date_key
sum_click
gold_processed_timestamp
gold_processed_date
```
The sum_click measure can be used to analyze student interaction with course materials and activities.

## Dimension Tables
| Dimension | Grain | Main Key | Purpose |
|---|---|---|---|
| `dim_student` | One row per student | `student_key` | Student-related attributes and course presentation information |
| `dim_course` | One row per course presentation | `course_key` | Course/module and presentation information |
| `dim_assessment` | One row per assessment | `assessment_key` | Assessment type, date, weight, and course information |
| `dim_vle` | One row per VLE site per course | `site_key` | VLE activity and site information |
| `dim_date` | One row per OULAD relative day | `date_key` | Relative-day and relative-week information |


**Relative Date Dimension**
Unlike a traditional calendar dimension, OULAD uses relative days to describe events in relation to a course presentation.

The Gold `dim_date `contains:

```text
date_key
relative_day
relative_week
silver_processed_timestamp
silver_processed_date
gold_processed_timestamp
gold_processed_date
```

For example:
```text
relative_day = -5
```

represents five days before the reference point used by the OULAD data.

The `relative_week` is derived from the relative day.

The dimension is generated using the range of relative dates found across date-based Silver datasets, including:

- Assessment submission dates
- Student registration dates
- Student unregistration dates
- VLE interaction dates

This allows the Gold fact tables to share a common relative-date dimension.

## Gold Relationships

The main relationships in the star schema are:
```text
                   dim_student
                       │
                       │ student_key
                       ▼
                fact_assessment
                       │
          ┌────────────┼────────────┐
          │            │            │
          ▼            ▼            ▼
     dim_course   dim_assessment  dim_date

and:

                   dim_student
                       │
                       │ student_key
                       ▼
              fact_vle_interaction
                       │
          ┌────────────┼────────────┐
          │            │            │
          ▼            ▼            ▼
     dim_course      dim_vle     dim_date
```

Fact tables contain event records and measures, while dimension tables provide descriptive information for analysis.


# Business Analytics Queries

## How does student engagement relate to performance?

### Method

* **Engagement Measurement:**  
  Assessment submission rate is calculated as:  `Assessment submission rate = Number of submitted assessments`


* **Submission Tracking:**  
The assessment submission date is obtained through the relationship:  
- `fact_assessment.date_key`  
  ↓  
- `dim_date.date_key`  
  ↓  
- `dim_date.relative_day`  

- A relative day of **-1** = assessment not submitted  
- Other relative-day values = recorded submission date  

* **Performance Measurement:**  
- Average assessment score  

* **Analytical Grain:**  
- One row per student per course  
- Student-course records grouped into submission-rate engagement buckets:  
  - 0–20%  
  - 20–40%  
  - 40–60%  
  - 60–80%  
  - 80–100%  

* **Comparison Metrics:**  
- Number of students  
- Average assessment submission rate  
- Average assessment score  

### Findings

* Students with **higher assessment engagement** tend to show **higher average performance scores**.  
* The analysis identifies a **relationship/association**, but does **not establish causation**.  

---

## What patterns appear among students who withdraw?

### Method
- **Chart Grouping:** Students categorized by age band; outcomes simplified into "Withdrawn" vs. "Retained."
- **Computed Metrics:** For each group, calculated:
  - Average Assessment Score
  - Average Submission Count (assessments submitted ÷ unique students)

### Findings
- **Consistent Performance Gap:** Withdrawn students score ~10–11 points lower across all age groups.
- **Severe Engagement Drop:** Withdrawn students average ~2.8 submissions vs. ~7.3 for retained students.
- **Age Does Not Alter Trend:** Older students score higher overall, but withdrawal impact is consistent.
- **Early Warning Sign:** Low submission volume is the strongest predictor of dropout risk.

---

## How does student activity change throughout a course?

### Method
- **Activity:** VLE clicks (`sum_click`) from `fact_vle_interaction`.
- **Course Progress:** Percentage completion (0–100%), binned into 10 deciles.
- **Normalization:** Binning by % progress ensures all courses contribute equally.
- **Visuals:**  
  - Bar chart → Avg clicks per active student by decile  
  - Line chart → Total active students by decile

### Findings
- **Active Students Decline:** ~28K (0–10%) → ~14K (90–100%), ~50% drop.
- **Engagement Peaks:**  
  - Start (0–10%, ~185 clicks) → orientation browsing  
  - Mid-course (50–60%) & late-course (80–90%) → assessment deadlines  
- **Sharp Collapse:** Final decile (90–100%, ~58 clicks) shows lowest engagement.

---

## Bonus: Which course modules have the highest overall student engagement?

### Method
- **Chart Grouping:** VLE interactions grouped by course (`code_module`).
- **Computed Metrics:** Avg clicks per student = total clicks ÷ distinct students.
- **Sorting:** Top 5 modules ranked by engagement.

### Findings
- **Top Performer:** Module **FFF** → >1,800 avg clicks per student.
- **Drop-off:** Module **AAA** → ~1,300 clicks (500 fewer than FFF).
- **Runner-ups:**  
  - EEE → ~1,050 clicks  
  - DDD → ~800 clicks  
  - CCC → ~650 clicks  
- **High Variance:** FFF generates nearly 3× the engagement of CCC.



## Data Quality Checks
Data quality checks are applied throughout the pipeline.

## Source Checks
- Expected source files exist
- Missing source files are detected
- Unexpected source files are reported
- Source files are not empty
- Source row counts are recorded

**Bronze Checks**
- Source data is successfully ingested
- Source and Bronze row counts can be compared
- Expected columns are present
- Required fields are validated
- Ingestion metadata is present

**Silver Checks**
- Required fields are not null
- Data types are valid
- Sentinel values are handled
- Accepted categorical values are enforced
- Numeric values are within expected ranges
- Duplicate records are controlled
- Silver lineage metadata is present

**Gold Checks**
- Dimension natural keys are unique where required
- Surrogate keys are valid
- Fact-table grain is maintained
- Foreign keys reference valid dimensions
- Required fact fields are populated
- Gold processing metadata is present

**Analytics Checks**
- Business query results follow the intended grain
- Aggregations use the appropriate fact measures
- Null or invalid values do not distort analytical results
- Business rules are validated before results are used for reporting 

## Repository Structure
The repository is organized by pipeline responsibility.
```text
oulad-pipeline/
│
├── src/
│   └── sql/
│       │
│       ├── 00_setup/
│       │   ├── 00_init_schemas.sql
│       │   └── 01_source_inspection.py
│       │
│       ├── 01_bronze_ingest/
│       │
│       ├── 02_silver_transform/
│       │
│       ├── 03_gold_model/
│       │
│       └── 04_analytics/
│
├── tests/
│   ├── bronze/
│   ├── silver/
│   ├── gold/
│   └── analytics/
│
│
└── README.md
```

This makes individual parts of the pipeline easier to develop, test, and troubleshoot.

## Running the Pipeline

Run the pipeline in dependency order.

**1. Initialize Schemas**

Run the setup scripts to create the required Unity Catalog schemas and tables.

**2. Run Source Inspection**

Check that the expected OULAD source files are available and record their source row counts.

**3. Run Bronze Ingestion**

Load the OULAD CSV files into Bronze Delta tables.

**4. Run Bronze Tests**

Validate the ingested Bronze data.

**5. Run Silver Transformations**

Clean, standardize, validate, and deduplicate the Bronze data.

**6. Run Silver Tests**

Validate the transformed Silver data.

**7. Run Gold Transformations**

Build or update the Gold dimensions and fact tables.

**8. Run Gold Tests**

Validate the Gold star schema, relationships, and fact-table grain.
**
9. Run Analytics**

Execute the business-question queries and analytical views.

**10. Run Analytics Tests**

Validate the final analytical outputs.

Incremental and Rerun Behavior

The pipeline uses Delta Lake and MERGE operations to support reruns.

The general pattern is:

```text
Existing record
      │
      ▼
   MATCHED
      │
      ▼
    UPDATE

and:

New record
      │
      ▼
 NOT MATCHED
      │
      ▼
    INSERT
```
This allows pipeline layers to be rerun without blindly appending duplicate records.
The Gold tables use natural-key combinations and surrogate keys to maintain the intended grain of the dimensional model.
Processing metadata is refreshed during Gold processing.

## Data Lineage
The pipeline maintains processing metadata across transformation layers.

**Silver tables contain:**
```text
silver_processed_timestamp
silver_processed_date
```
**Gold tables contain:**
```text
gold_processed_timestamp
gold_processed_date
```
**This provides visibility into when records were processed by each layer.**

```text
The overall lineage is:

OULAD CSV
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

## Design Choices
**Medallion Architecture**

The pipeline separates responsibilities into Source, Bronze, Silver, Gold, Analytics, and Tests.
This makes the pipeline easier to understand, test, maintain, and troubleshoot.

**Source Inspection Before Bronze**

Source inspection is separated from Bronze ingestion so the pipeline can establish a baseline of the source data before transformations occur.

The source inspection records source row counts in an audit table that can be used by downstream quality checks.

**Surrogate Keys**

Gold dimensions use surrogate keys such as:

```text
student_key
course_key
assessment_key
site_key
date_key
```

These keys are used by fact tables for dimensional relationships.

**Natural Keys**

Natural OULAD identifiers are retained where needed for traceability and matching source records.

**Clear Fact-Table Grain**

Each fact table has a defined grain.

`fact_assessment`
→ student + course + assessment + submission date
`fact_vle_interaction`
→ student + course + VLE site + relative date


**Shared Relative-Date Dimension **
A single relative-date dimension is shared by the Gold fact tables.

This provides consistent handling of OULAD relative-day values across assessment and VLE activity data.

## Incremental MERGE Operations

Delta MERGE operations are used to update existing records and insert new records while supporting pipeline reruns.

**Layered Testing**

Tests are separated according to the layer being validated:

```text
Source    → Source checks
Bronze    → Ingestion checks
Silver    → Cleaning and validation checks
Gold      → Dimensional-model checks
Analytics → Business-result checks
```
This prevents one large test suite from having to handle every type of data-quality problem.

## Project Outcome
The completed pipeline transforms OULAD source data into a structured analytical warehouse that supports:

- Student analysis
- Course analysis
- Assessment performance analysis
- Assessment submission analysis
- VLE interaction analysis
- Student engagement analysis
- Dimensional reporting
- Data-quality validation
