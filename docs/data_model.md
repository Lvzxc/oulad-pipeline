# OULAD Data Model

## Overview

The Gold layer uses a **star schema** designed for analytical queries.

It contains:

- 2 fact tables
- 5 dimension tables
- Surrogate keys for dimensional relationships
- Clearly defined fact-table grain

## Fact Tables

| Table | Grain | Main Measures |
|---|---|---|
| `fact_assessment` | One row per student-course-assessment-submission date | `score`, `is_banked` |
| `fact_vle_interaction` | One row per student-course-site-relative date | `sum_click` |

## Dimension Tables

| Table | Grain | Purpose |
|---|---|---|
| `dim_student` | One row per student-course | Student and course presentation attributes |
| `dim_course` | One row per course presentation | Course and module information |
| `dim_assessment` | One row per assessment | Assessment type, date, and weight |
| `dim_vle` | One row per VLE site per course | VLE resource and activity information |
| `dim_date` | One row per relative day | Course-relative date and week information |

## Star Schema
<img width="1345" height="1041" alt="Oulad Star Schema" src="https://github.com/user-attachments/assets/15277853-065e-44f2-9f68-1765a327c453" />


## Key Design

Fact tables use surrogate dimension keys such as:

```text
student_key
course_key
assessment_key
site_key
date_key
```

OULAD natural/source identifiers are retained where useful for traceability.

## Fact Grain

Defining the grain before building the fact tables helps prevent duplicate records and incorrect aggregations.

### Assessment

One record represents a student's assessment submission for a specific course and assessment date.

### VLE Interaction

One record represents a student's interaction with a VLE site for a specific course and relative date.

## Purpose

The model separates measurable events from descriptive attributes, allowing analytical queries to combine student, course, assessment, VLE, and time information efficiently.
