# OULAD Design Decisions

This document summarizes the main design choices made in the OULAD pipeline.

## 1. Medallion Architecture

The pipeline uses Source Inspection, Bronze, Silver, Gold, and Analytics layers.

This separates ingestion, transformation, modeling, and analysis responsibilities.

## 2. Delta Lake

Delta tables are used for the pipeline layers to provide reliable table storage and support incremental processing and safe reruns.

## 3. Bronze Preserves Source Structure

The Bronze layer stays close to the original OULAD data.

Cleaning and business rules are applied in Silver rather than modifying the raw ingestion layer.

## 4. Silver for Data Preparation

Silver is responsible for:

- Data-type standardization
- Categorical-value standardization
- Missing-value handling
- OULAD sentinel-value handling
- Business-rule validation
- Deduplication

## 5. Surrogate Keys in Gold

Surrogate keys are used for fact-to-dimension relationships.

This provides consistent dimensional relationships while source identifiers can still be retained for traceability.

## 6. Relative Date Modeling

OULAD provides course-relative days rather than conventional calendar dates.

A shared `dim_date` therefore uses relative days and weeks so activity can be compared based on course progress.

## 7. Clearly Defined Fact Grain

Each fact table has a documented grain before modeling.

This reduces the risk of duplicate records and incorrect aggregations.

## 8. Layered Validation

Validation is performed across the pipeline rather than only at the end.

This makes it easier to identify whether an issue originated from the source, ingestion, transformation, modeling, or analytics stage.

## 9. Incremental Processing

Delta `MERGE` operations are used where applicable so that rerunning the pipeline can update matching records and insert new records without blindly appending duplicates.
