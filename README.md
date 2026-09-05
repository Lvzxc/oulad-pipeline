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

## Gold data model

The Gold layer uses a star schema centered on

--Insert pipeline architecture here

### Fact table
Grain:
Columns Included:

The fact table uses ---- as its business key

### Dimension tables

### Relationships

## Analytics
The analytics layer contains:

The project supports below business questions:
## Repository structure

## Run the pipeline
Run the layers in this order:

## Incremental and rerun behavior

## Quality checks
