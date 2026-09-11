# OULAD Bronze Data Quality Validation Results

This document records the data quality validation results for all OULAD Bronze tables.

The validation checks cover volume, NULL values, uniqueness, data types and formats, value ranges, accepted values, source sentinel values, and foreign key integrity.

---

## 1. assessment_bronze

### Validation Results

| Check                              | Type           | Records | Failures | Failure % | Status |
| ---------------------------------- | -------------- | ------: | -------: | --------: | ------ |
| Row count                          | VOLUME         |     206 |        0 |     0.00% | PASS   |
| Missing `id_assessment`            | NULL           |     206 |        0 |     0.00% | PASS   |
| Missing `code_module`              | NULL           |     206 |        0 |     0.00% | PASS   |
| Missing `code_presentation`        | NULL           |     206 |        0 |     0.00% | PASS   |
| Missing `assessment_type`          | NULL           |     206 |        0 |     0.00% | PASS   |
| Missing `date`                     | NULL           |     206 |        0 |     0.00% | PASS   |
| Missing `weight`                   | NULL           |     206 |        0 |     0.00% | PASS   |
| Duplicate assessment business key  | UNIQUE         |     206 |        0 |     0.00% | PASS   |
| Exact duplicate records            | UNIQUE         |     206 |        0 |     0.00% | PASS   |
| Invalid `id_assessment` format     | TYPE / FORMAT  |     206 |        0 |     0.00% | PASS   |
| Invalid `date` format              | TYPE / FORMAT  |     206 |        0 |     0.00% | PASS   |
| Invalid `weight` format            | TYPE / FORMAT  |     206 |        0 |     0.00% | PASS   |
| Invalid `assessment_type`          | ACCEPTED VALUE |     206 |        0 |     0.00% | PASS   |
| Invalid `weight` range             | RANGE          |     206 |        0 |     0.00% | PASS   |
| Source sentinel (`?`) in `date`    | SENTINEL       |     206 |       11 |     5.34% | WARN   |
| Assessment without matching course | FOREIGN KEY    |     206 |        0 |     0.00% | PASS   |
| Conflicting assessment ID          | BUSINESS RULE  |     206 |        0 |     0.00% | PASS   |

### Findings

All structural, uniqueness, type/format, range, accepted-value, and foreign key checks passed.

The only warning was the source sentinel `?` in `date`:

* 11 records
* 5.34%

### Bronze-to-Silver Action

Convert `?` in `date` to `NULL` during Silver cleaning. Retain the assessment records because an unavailable assessment date does not invalidate the assessment definition.

**Overall Status: PASS with expected source sentinel warning.**

---

## 2. courses_bronze

### Validation Results

| Check                                | Type          | Records | Failures | Failure % | Status |
| ------------------------------------ | ------------- | ------: | -------: | --------: | ------ |
| Row count                            | VOLUME        |      22 |        0 |     0.00% | PASS   |
| Missing `code_module`                | NULL          |      22 |        0 |     0.00% | PASS   |
| Missing `code_presentation`          | NULL          |      22 |        0 |     0.00% | PASS   |
| Missing `module_presentation_length` | NULL          |      22 |        0 |     0.00% | PASS   |
| Duplicate course business key        | UNIQUE        |      22 |        0 |     0.00% | PASS   |
| Exact duplicate records              | UNIQUE        |      22 |        0 |     0.00% | PASS   |
| Invalid/blank `code_module`          | TYPE / FORMAT |      22 |        0 |     0.00% | PASS   |
| Invalid/blank `code_presentation`    | TYPE / FORMAT |      22 |        0 |     0.00% | PASS   |
| Invalid `module_presentation_length` | RANGE         |      22 |        0 |     0.00% | PASS   |

### Findings

All validation checks passed. No missing mandatory fields, duplicate business keys, exact duplicates, or invalid presentation lengths were identified.

### Bronze-to-Silver Action

Standardize `code_module` and `code_presentation` using trimming and uppercase conversion. Cast `module_presentation_length` to the target Silver type.

No corrective data-quality action is required.

**Overall Status: PASS.**

---

## 3. student_assessment_bronze

### Validation Results

| Check                            | Type           | Records | Failures | Failure % | Status |
| -------------------------------- | -------------- | ------: | -------: | --------: | ------ |
| Row count                        | VOLUME         | 173,912 |        0 |     0.00% | PASS   |
| Missing `id_assessment`          | NULL           | 173,912 |        0 |     0.00% | PASS   |
| Missing `id_student`             | NULL           | 173,912 |        0 |     0.00% | PASS   |
| Missing `date_submitted`         | NULL           | 173,912 |        0 |     0.00% | PASS   |
| Missing `is_banked`              | NULL           | 173,912 |        0 |     0.00% | PASS   |
| Missing `score`                  | NULL           | 173,912 |        0 |     0.00% | PASS   |
| Duplicate student-assessment key | UNIQUE         | 173,912 |        0 |     0.00% | PASS   |
| Exact duplicate records          | UNIQUE         | 173,912 |        0 |     0.00% | PASS   |
| Invalid ID/date/flag format      | TYPE / FORMAT  | 173,912 |        0 |     0.00% | PASS   |
| Source sentinel (`?`) in `score` | SENTINEL       | 173,912 |      173 |     0.10% | WARN   |
| Invalid `score` range            | RANGE          | 173,912 |        0 |     0.00% | PASS   |
| Invalid `is_banked` value        | ACCEPTED VALUE | 173,912 |        0 |     0.00% | PASS   |
| Assessment FK violations         | FOREIGN KEY    | 173,912 |        0 |     0.00% | PASS   |
| Student FK violations            | FOREIGN KEY    | 173,912 |        0 |     0.00% | PASS   |

### Findings

All structural, uniqueness, type/format, range, accepted-value, and foreign key checks passed.

The only warning was the source sentinel `?` in `score`:

* 173 records
* 0.10%

### Bronze-to-Silver Action

Convert `?` in `score` to `NULL` while retaining the assessment records because the record remains valid even when the score is unavailable.

**Overall Status: PASS with expected source sentinel warning.**

---

## 4. student_info_bronze

### Validation Results

| Check                               | Type          | Records | Failures | Failure % | Status |
| ----------------------------------- | ------------- | ------: | -------: | --------: | ------ |
| Row count                           | VOLUME        |  32,593 |        0 |     0.00% | PASS   |
| Missing required fields             | NULL          |  32,593 |        0 |     0.00% | PASS   |
| Duplicate student business key      | UNIQUE        |  32,593 |        0 |     0.00% | PASS   |
| Exact duplicate records             | UNIQUE        |  32,593 |        0 |     0.00% | PASS   |
| Invalid numeric formats             | TYPE / FORMAT |  32,593 |        0 |     0.00% | PASS   |
| Invalid attempts range              | RANGE         |  32,593 |        0 |     0.00% | PASS   |
| Invalid studied credits range       | RANGE         |  32,593 |        0 |     0.00% | PASS   |
| Source sentinel (`?`) in `imd_band` | SENTINEL      |  32,593 |    1,111 |     3.41% | WARN   |
| Course FK violations                | FOREIGN KEY   |  32,593 |        0 |     0.00% | PASS   |

### Findings

All required-field, uniqueness, type/format, range, and foreign key checks passed.

A source sentinel `?` was found in `imd_band`:

* 1,111 records
* 3.41%

### Bronze-to-Silver Action

Convert `?` in `imd_band` to `NULL` during Silver cleaning and retain the student records because unavailable IMD information does not invalidate the student record.

**Overall Status: PASS with expected source sentinel warning.**

---

## 5. student_registration_bronze

### Validation Results

| Check                               | Type          | Records | Failures | Failure % | Status |
| ----------------------------------- | ------------- | ------: | -------: | --------: | ------ |
| Row count                           | VOLUME        |  32,593 |        0 |     0.00% | PASS   |
| Missing `id_student`                | NULL          |  32,593 |        0 |     0.00% | PASS   |
| Missing `code_module`               | NULL          |  32,593 |        0 |     0.00% | PASS   |
| Missing `code_presentation`         | NULL          |  32,593 |        0 |     0.00% | PASS   |
| Missing `date_registration`         | NULL          |  32,593 |        0 |     0.00% | PASS   |
| Missing `date_unregistration`       | NULL          |  32,593 |        0 |     0.00% | PASS   |
| Duplicate registration business key | UNIQUE        |  32,593 |        0 |     0.00% | PASS   |
| Exact duplicate records             | UNIQUE        |  32,593 |        0 |     0.00% | PASS   |
| Invalid ID/date format              | TYPE / FORMAT |  32,593 |        0 |     0.00% | PASS   |
| `?` in `date_registration`          | SENTINEL      |  32,593 |       45 |     0.14% | WARN   |
| `?` in `date_unregistration`        | SENTINEL      |  32,593 |   22,521 |    69.10% | WARN   |
| Course FK violations                | FOREIGN KEY   |  32,593 |        0 |     0.00% | PASS   |
| Student FK violations               | FOREIGN KEY   |  32,593 |        0 |     0.00% | PASS   |

### Findings

All mandatory-field, uniqueness, type/format, and foreign key checks passed.

Source sentinel values were found in:

* `date_registration`: 45 records (0.14%)
* `date_unregistration`: 22,521 records (69.10%)

The high percentage in `date_unregistration` is expected source behavior. A missing unregistration date can indicate that the student did not withdraw.

### Bronze-to-Silver Action

Convert `?` values in both registration dates to `NULL`.

Retain NULL `date_unregistration` values because they carry business meaning and should not be treated as data quality errors.

**Overall Status: PASS with expected source sentinel warnings.**

---

## 6. student_vle_bronze

### Validation Results

| Check                         | Type          |    Records |  Failures | Failure % | Status |
| ----------------------------- | ------------- | ---------: | --------: | --------: | ------ |
| Row count                     | VOLUME        | 10,655,280 |         0 |     0.00% | PASS   |
| Missing required fields       | NULL          | 10,655,280 |         0 |     0.00% | PASS   |
| Duplicate business key        | UNIQUE        | 10,655,280 | 2,195,960 |    20.61% | FAIL   |
| Exact duplicate records       | UNIQUE        | 10,655,280 |   787,170 |     7.39% | FAIL   |
| Invalid ID/date formats       | TYPE / FORMAT | 10,655,280 |         0 |     0.00% | PASS   |
| Negative `sum_click`          | RANGE         | 10,655,280 |         0 |     0.00% | PASS   |
| Source sentinel (`?`) in date | SENTINEL      | 10,655,280 |         0 |     0.00% | PASS   |
| Course FK violations          | FOREIGN KEY   | 10,655,280 |         0 |     0.00% | PASS   |
| Student FK violations         | FOREIGN KEY   | 10,655,280 |         0 |     0.00% | PASS   |
| VLE FK violations             | FOREIGN KEY   | 10,655,280 |         0 |     0.00% | PASS   |

### Business Grain

One record represents:

**One student × one VLE site × one day within a specific module presentation.**

Business key:

`id_student + code_module + code_presentation + id_site + date`

### Findings

The table passed all NULL, type/format, range, source sentinel, and foreign key checks.

However, duplicate business keys were identified:

* 2,195,960 records
* 20.61%

Exact duplicate records accounted for:

* 787,170 records
* 7.39%

Investigation found duplicate business-key groups where the same student, module presentation, VLE site, and date contained different `sum_click` values. This indicates source-level duplication rather than only exact duplicate rows.

### Bronze-to-Silver Action

Resolve duplicates during Silver processing using `ROW_NUMBER()` over the complete business key:

`id_student + code_module + code_presentation + id_site + date`

Retain the latest record based on `ingestion_timestamp`.

The duplicate records will **not be aggregated**, because different source records can contain different `sum_click` values and the established cleaning rule is to retain the latest source record.

**Overall Status: FAIL — source-level duplicate business keys require Silver deduplication.**

---

## 7. vle_bronze

### Validation Results

| Check                              | Type          | Records | Failures | Failure % | Status |
| ---------------------------------- | ------------- | ------: | -------: | --------: | ------ |
| Row count                          | VOLUME        |   6,364 |        0 |     0.00% | PASS   |
| Missing `activity_type`            | NULL          |   6,364 |        0 |     0.00% | PASS   |
| Missing `code_module`              | NULL          |   6,364 |        0 |     0.00% | PASS   |
| Missing `code_presentation`        | NULL          |   6,364 |        0 |     0.00% | PASS   |
| Missing `id_site`                  | NULL          |   6,364 |        0 |     0.00% | PASS   |
| Missing `week_from`                | NULL          |   6,364 |        0 |     0.00% | PASS   |
| Missing `week_to`                  | NULL          |   6,364 |        0 |     0.00% | PASS   |
| Duplicate VLE business key         | UNIQUE        |   6,364 |        0 |     0.00% | PASS   |
| Exact duplicate records            | UNIQUE        |   6,364 |        0 |     0.00% | PASS   |
| Invalid `id_site` format           | TYPE / FORMAT |   6,364 |        0 |     0.00% | PASS   |
| Invalid `week_from` format         | TYPE / FORMAT |   6,364 |        0 |     0.00% | PASS   |
| Invalid `week_to` format           | TYPE / FORMAT |   6,364 |        0 |     0.00% | PASS   |
| Negative `week_from`               | RANGE         |   6,364 |        0 |     0.00% | PASS   |
| Negative `week_to`                 | RANGE         |   6,364 |        0 |     0.00% | PASS   |
| `week_to` earlier than `week_from` | RANGE         |   6,364 |        0 |     0.00% | PASS   |
| `?` in `week_from`                 | SENTINEL      |   6,364 |    5,243 |    82.39% | WARN   |
| `?` in `week_to`                   | SENTINEL      |   6,364 |    5,243 |    82.39% | WARN   |
| Course FK violations               | FOREIGN KEY   |   6,364 |        0 |     0.00% | PASS   |

### Findings

All structural, uniqueness, type/format, range, and foreign key checks passed.

Source sentinel values were found in both VLE availability fields:

* `week_from`: 5,243 records (82.39%)
* `week_to`: 5,243 records (82.39%)

These values represent unavailable or non-timebound VLE timing information and are expected in the source dataset.

### Bronze-to-Silver Action

Convert `?` in `week_from` and `week_to` to `NULL` during Silver cleaning while retaining the VLE records.

The records remain useful because unavailable timing information does not invalidate the VLE resource.

**Overall Status: PASS with expected source sentinel warnings.**

---

# Overall Bronze Validation Summary

| Bronze Table                  |    Records | Main Finding                                                          | Status      | Silver Action                                                       |
| ----------------------------- | ---------: | --------------------------------------------------------------------- | ----------- | ------------------------------------------------------------------- |
| `assessment_bronze`           |        206 | 11 `?` values in `date` (5.34%)                                       | PASS / WARN | Convert `?` to `NULL`; retain records                               |
| `courses_bronze`              |         22 | No data quality issues                                                | PASS        | Standardize codes and cast to target types                          |
| `student_assessment_bronze`   |    173,912 | 173 `?` values in `score` (0.10%)                                     | PASS / WARN | Convert `?` to `NULL`; retain records                               |
| `student_info_bronze`         |     32,593 | 1,111 `?` values in `imd_band` (3.41%)                                | PASS / WARN | Convert `?` to `NULL`; retain records                               |
| `student_registration_bronze` |     32,593 | `?` in `date_registration` (0.14%) and `date_unregistration` (69.10%) | PASS / WARN | Convert `?` to `NULL`; retain valid registration records            |
| `student_vle_bronze`          | 10,655,280 | 2,195,960 duplicate business-key records (20.61%)                     | FAIL        | Deduplicate by business key and retain latest `ingestion_timestamp` |
| `vle_bronze`                  |      6,364 | 5,243 `?` values in both `week_from` and `week_to` (82.39%)           | PASS / WARN | Convert `?` to `NULL`; retain VLE records                           |


### Overall Conclusion

The Bronze validation confirms that the OULAD source data is generally structurally sound, with valid required fields, formats, ranges, and referential relationships across the datasets.

Most identified warnings are expected source conditions represented by `?` and will be converted to `NULL` during Silver processing.

The primary data quality issue is the presence of duplicate business keys in `student_vle_bronze`. These records require Silver-layer deduplication using the latest `ingestion_timestamp`.

The Bronze layer therefore serves as the first data quality gate before data progresses to Silver.
