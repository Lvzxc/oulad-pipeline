# OULAD Pipeline Architecture

## Overview

The OULAD pipeline follows a **Medallion Architecture** to progressively transform raw learning analytics data into validated, analysis-ready data.

```text
OULAD CSV Files
      |
      v
Source Inspection
      |
      v
   Bronze
      |
      v
   Silver
      |
      v
    Gold
      |
      v
  Analytics
```

## Architecture Layers

| Layer | Purpose |
|---|---|
| Source Inspection | Validates incoming files and records source-level information |
| Bronze | Stores raw OULAD data in Delta tables |
| Silver | Cleans, standardizes, validates, and deduplicates data |
| Gold | Builds the analytical star schema |
| Analytics | Answers business questions using Gold data |

## Data Flow

### Source Inspection

Before ingestion, the pipeline checks the expected OULAD files, identifies missing or unexpected files, detects empty files, and records source row counts.

### Bronze

Raw CSV files are loaded into Delta tables with ingestion metadata. The Bronze layer remains close to the original source structure.

### Silver

Bronze data is prepared for analysis through data-type standardization, missing-value handling, business-rule validation, and duplicate control.

### Gold

Clean Silver data is transformed into fact and dimension tables. Surrogate keys are used to establish consistent relationships between tables.

### Analytics

The Gold layer supports analysis of student engagement, assessment performance, withdrawal patterns, course activity, and module engagement.

## Validation

Validation is performed at each major stage to identify data-quality issues before they affect downstream layers.
