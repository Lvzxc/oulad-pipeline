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

## Tools used

- Databricks SQL
- Delta Lake
- Unity Catalog
- Databricks SQL Warehouse
- GitHub and GitHub Actions
- SQL notebooks

## Data pipeline

The pipeline follows this order:

```text
Source Files → Bronze → Tests → Silver → Tests → Gold → Tests → Analytics → Tests
```

| Layer | Purpose |
|---|---|
| **Source** | Original Instacart CSV files stored in a Databricks Volume. Source data is not committed to GitHub. |
| **Bronze** | Ingests source records into raw Delta tables with ingestion metadata. |
| **Silver** | Cleans, casts, standardizes, validates, deduplicates, and combines related datasets. |
| **Gold** | Builds the fact table and dimension tables used for analysis. |
| **Analytics** | Contains reusable business views and notebook queries for reporting questions. |
| **Tests** | Validates source data, cleaned data, Gold relationships, business results, and the release quality gate. |

Each layer has one responsibility. Preview queries and validation logic are kept separate from the production transformation files.
## 🔄 Pipeline Layers

### Bronze
- Raw ingestion of OULAD CSVs.
- Examples:
  - `student_vle_bronze`: student clicks per site per date.
  - `vle_bronze`: site metadata (activity type, weeks available).

### Silver
- Cleaned and standardized data.
- Key transformations:
  - Remove sentinel values (`?`).
  - Enforce data types and ranges.
  - Add lineage: `silver_processed_timestamp`, `silver_processed_date`.
- Example: `assessment_silver` with validated weights (0–100), accepted types (`TMA`, `CMA`, `Exam`).

### Gold
- Star schema for analytics.
- Dimensions and facts with surrogate keys, natural keys, attributes, and lineage.
- 
## Gold data model

The Gold layer uses a star schema centered on
<img width="811" height="571" alt="image" src="https://github.com/user-attachments/assets/923a548e-2204-48dd-bc1e-31f64545dc76" />


--Insert pipeline architecture here

### Fact table
1. fact_assessment
Grain: One row per student–course–assessment–date.
Meaning: Each record represents a student’s submission of a specific assessment in a course on a given date.
Columns Included: student_key, course_key, assessment_key, date_key, score, is_banked

2. fact_vle_interaction
Grain: One row per student–course–site–date.
Meaning: Each record represents the total clicks a student made on a specific VLE site (learning activity) in a course on a given date.
Columns Included: student_key, course_key, site_key, date_key, sum_click

### Dimension tables
| Dimension        | Grain | Key Fields | Attributes | Lineage |
|------------------|-------|------------|------------|---------|
| **dim_student**  | 1 row per student | `student_key` | demographics, registration | Silver + Gold |
| **dim_course**   | 1 row per course presentation | `course_key` | module, presentation | Silver + Gold |
| **dim_assessment** | 1 row per assessment | `assessment_key` | type, date, weight | Silver + Gold |
| **dim_vle**      | 1 row per site per course | `site_key` | activity type, week_from, week_to | Silver + Gold |
| **dim_date**     | 1 row per calendar day | `date_key` | year, month, quarter, day | Gold |

### Relationships

## Analytics
The analytics layer contains:

The project supports below business questions:
## Repository structure

## Run the pipeline
Run the layers in this order:

## Incremental and rerun behavior

## 🛡️ Data Quality Checks
- **Completeness**: Required fields not null.  
- **Uniqueness**: Natural keys unique (e.g., `id_assessment`).  
- **Validity**: Accepted values (`assessment_type` in {TMA, CMA, Exam}).  
- **Range**: `weight` between 0–100.  
- **Referential integrity**: Foreign keys link to valid dimensions.  
- **Lineage**: All Silver and Gold tables include timestamps and dates.  
- **Volume checks**: Parameterized against Bronze counts (not hardcoded).  
---

## 📝 Design Choices
- **Surrogate keys** (`*_key`) for joins in facts.  
- **Natural keys** retained for traceability.  
- **Lineage consistency**: Both Silver and Gold timestamps/dates included in all dimensions/facts.  
- **Incremental merges**: Update existing rows, insert new ones.  
- **Grain clarity**: Dimensions are descriptive; facts capture events.  
