# OULAD Data Validation Framework

## Overview

Data validation is performed across the pipeline to maintain data quality and ensure that downstream analytics are based on reliable data.

## Validation by Layer

| Layer | Main Validation Checks |
|---|---|
| Source | Expected files, missing files, unexpected files, empty files, and source row counts |
| Bronze | Ingestion completeness, expected columns, row counts, required fields, and ingestion metadata |
| Silver | Required fields, data types, accepted values, numeric ranges, sentinel values, and duplicates |
| Gold | Dimension keys, foreign keys, relationships, fact grain, and required fields |
| Analytics | Analytical grain, measures, null handling, and business-rule consistency |

## Source Validation

The source inspection stage establishes a baseline before data is loaded.

Checks include:

- Expected OULAD files are available
- Missing or unexpected files are identified
- Files are not empty
- Source row counts are recorded

## Bronze Validation

Bronze validation focuses on ingestion quality.

The checks confirm that:

- Expected tables were created
- Expected columns are present
- Data was successfully loaded
- Required fields are available
- Ingestion metadata exists
- Source and Bronze row counts can be compared

## Silver Validation

Silver validation focuses on data quality after transformation.

Checks include:

- Required fields are populated
- Data types are appropriate
- Categorical values are valid
- Numeric values fall within expected ranges
- OULAD sentinel values are handled
- Duplicate records are controlled
- Processing metadata is present

## Gold Validation

Gold validation focuses on the dimensional model.

Checks include:

- Dimension keys are valid
- Natural keys are appropriately controlled
- Fact foreign keys reference dimensions
- Fact-table grain is maintained
- Required fact fields are populated
- Gold processing metadata exists

## Analytics Validation

Analytics checks ensure that business outputs are calculated at the intended grain and use the correct measures.

This includes checking:

- Aggregation logic
- Analytical grain
- Null and invalid values
- Business-rule consistency

## Goal

The validation framework is designed to catch issues as early as possible and prevent data-quality problems from propagating into the final analytical results.
