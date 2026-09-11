%md
# OULAD Silver Data Quality Validation Results

The Silver layer validation confirms that Bronze data quality issues were appropriately handled during cleaning and standardization. Validation checks cover volume, NULL values, uniqueness, sentinel cleanup, standardization, foreign keys, and data lineage.

## 1. assessment_silver

### Validation Results

| Check                                | Type            | Records | Failures | Failure % | Status |
| ------------------------------------ | --------------- | ------: | -------: | --------: | ------ |
| Row count                            | VOLUME          |     206 |        0 |     0.00% | PASS   |
| Missing id_assessment                | NULL            |     206 |        0 |     0.00% | PASS   |
| Missing code_module                  | NULL            |     206 |        0 |     0.00% | PASS   |
| Missing code_presentation            | NULL            |     206 |        0 |     0.00% | PASS   |
| Missing assessment_type              | NULL            |     206 |        0 |     0.00% | PASS   |
| Missing assessment date              | NULL            |     206 |       11 |     5.34% | PASS   |
| Missing weight                       | NULL            |     206 |        0 |     0.00% | PASS   |
| Duplicate assessment business key    | UNIQUE          |     206 |        0 |     0.00% | PASS   |
| Unresolved sentinel (?) values       | SENTINEL        |     206 |        0 |     0.00% | PASS   |
| Invalid weight range                 | RANGE           |     206 |        0 |     0.00% | PASS   |
| Invalid assessment_type              | ACCEPTED VALUE  |     206 |        0 |     0.00% | PASS   |
| Untrimmed module/presentation values | STANDARDIZATION |     206 |        0 |     0.00% | PASS   |
| Assessment without matching course   | FOREIGN KEY     |     206 |        0 |     0.00% | PASS   |
| Missing Bronze ingestion timestamp   | LINEAGE         |     206 |        0 |     0.00% | PASS   |
| Missing Silver processing timestamp  | LINEAGE         |     206 |        0 |     0.00% | PASS   |

### Findings

* All 206 assessment records passed structural, uniqueness, range, standardization, and foreign key checks.
* 11 assessment dates remain NULL. These correspond exactly to the 11 `?` values identified in Bronze.
* The NULL assessment dates are expected because the source date was unavailable.
* No unresolved `?` values remain in Silver.
* All assessment weights and assessment types are valid.

### Silver Action

* Convert `?` assessment dates to NULL.
* Retain affected assessment records because the missing date does not invalidate the assessment definition.
* Standardize module, presentation, and assessment type values.
* Preserve lineage metadata.

**Overall Status: PASS**

---

## 2. courses_silver

### Validation Results

| Check                                     | Type            | Records | Failures | Failure % | Status |
| ----------------------------------------- | --------------- | ------: | -------: | --------: | ------ |
| Row count                                 | VOLUME          |      22 |        0 |     0.00% | PASS   |
| Missing code_module                       | NULL            |      22 |        0 |     0.00% | PASS   |
| Missing code_presentation                 | NULL            |      22 |        0 |     0.00% | PASS   |
| Missing module presentation length        | NULL            |      22 |        0 |     0.00% | PASS   |
| Invalid module presentation length        | RANGE           |      22 |        0 |     0.00% | PASS   |
| Duplicate course business key             | UNIQUE          |      22 |        0 |     0.00% | PASS   |
| Unresolved sentinel (?) values            | SENTINEL        |      22 |        0 |     0.00% | PASS   |
| Unstandardized module/presentation values | STANDARDIZATION |      22 |        0 |     0.00% | PASS   |
| Missing Bronze ingestion timestamp        | LINEAGE         |      22 |        0 |     0.00% | PASS   |
| Missing Silver processing timestamp       | LINEAGE         |      22 |        0 |     0.00% | PASS   |

### Findings

* All 22 course presentation records passed validation.
* No missing required fields were identified.
* No duplicate course business keys were found.
* Module and presentation codes were successfully standardized.
* All module presentation lengths are valid.

### Silver Action

* Standardize module and presentation codes.
* Cast module presentation length to the target numeric type.
* Retain one record per module presentation.
* Preserve lineage metadata.

**Overall Status: PASS**

---

## 3. student_assessment_silver

### Validation Results

| Check                                             | Type           | Records | Failures | Failure % | Status |
| ------------------------------------------------- | -------------- | ------: | -------: | --------: | ------ |
| Row count                                         | VOLUME         | 173,912 |        0 |     0.00% | PASS   |
| Missing date_submitted                            | NULL           | 173,912 |        0 |     0.00% | PASS   |
| Missing id_assessment                             | NULL           | 173,912 |        0 |     0.00% | PASS   |
| Missing id_student                                | NULL           | 173,912 |        0 |     0.00% | PASS   |
| Missing is_banked                                 | NULL           | 173,912 |        0 |     0.00% | PASS   |
| Missing score                                     | NULL           | 173,912 |      173 |     0.10% | PASS   |
| Duplicate student-assessment business key         | UNIQUE         | 173,912 |        0 |     0.00% | PASS   |
| Unresolved sentinel (?) in score                  | SENTINEL       | 173,912 |        0 |     0.00% | PASS   |
| Score outside valid range                         | RANGE          | 173,912 |        0 |     0.00% | PASS   |
| Invalid is_banked value                           | ACCEPTED VALUE | 173,912 |        0 |     0.00% | PASS   |
| Assessment without matching assessment definition | FOREIGN KEY    | 173,912 |        0 |     0.00% | PASS   |
| Assessment without matching student               | FOREIGN KEY    | 173,912 |        0 |     0.00% | PASS   |
| Missing ingestion date                            | LINEAGE        | 173,912 |        0 |     0.00% | PASS   |
| Missing ingestion timestamp                       | LINEAGE        | 173,912 |        0 |     0.00% | PASS   |

### Findings

* All student-assessment records passed structural, uniqueness, range, and foreign key checks.
* 173 scores remain NULL.
* These correspond exactly to the 173 `?` score values identified in Bronze.
* No unresolved sentinel values remain.
* All assessment scores are within the valid 0–100 range.
* All `is_banked` values are valid.

### Silver Action

* Convert `?` scores to NULL.
* Retain records with missing scores because the student-assessment relationship remains valid.
* Deduplicate using the student-assessment business key.
* Preserve ingestion lineage.

**Overall Status: PASS**

---

## 4. student_info_silver

### Validation Results

| Check                                              | Type            | Records | Failures | Failure % | Status |
| -------------------------------------------------- | --------------- | ------: | -------: | --------: | ------ |
| Row count                                          | VOLUME          |  32,593 |        0 |     0.00% | PASS   |
| Missing code_module                                | NULL            |  32,593 |        0 |     0.00% | PASS   |
| Missing code_presentation                          | NULL            |  32,593 |        0 |     0.00% | PASS   |
| Missing id_student                                 | NULL            |  32,593 |        0 |     0.00% | PASS   |
| Missing gender                                     | NULL            |  32,593 |        0 |     0.00% | PASS   |
| Missing region                                     | NULL            |  32,593 |        0 |     0.00% | PASS   |
| Missing highest_education                          | NULL            |  32,593 |        0 |     0.00% | PASS   |
| Missing imd_band                                   | NULL            |  32,593 |    1,111 |     3.41% | PASS   |
| Missing age_band                                   | NULL            |  32,593 |        0 |     0.00% | PASS   |
| Missing disability                                 | NULL            |  32,593 |        0 |     0.00% | PASS   |
| Missing final_result                               | NULL            |  32,593 |        0 |     0.00% | PASS   |
| Missing num_of_prev_attempts                       | NULL            |  32,593 |        0 |     0.00% | PASS   |
| Missing studied_credits                            | NULL            |  32,593 |        0 |     0.00% | PASS   |
| Invalid num_of_prev_attempts                       | RANGE           |  32,593 |        0 |     0.00% | PASS   |
| Invalid studied_credits                            | RANGE           |  32,593 |        0 |     0.00% | PASS   |
| Duplicate student-module-presentation business key | UNIQUE          |  32,593 |        0 |     0.00% | PASS   |
| Unresolved sentinel (?) values                     | SENTINEL        |  32,593 |        0 |     0.00% | PASS   |
| Untrimmed categorical values                       | STANDARDIZATION |  32,593 |        0 |     0.00% | PASS   |
| Student record without matching course             | FOREIGN KEY     |  32,593 |        0 |     0.00% | PASS   |
| Missing Bronze ingestion date                      | LINEAGE         |  32,593 |        0 |     0.00% | PASS   |
| Missing Bronze ingestion timestamp                 | LINEAGE         |  32,593 |        0 |     0.00% | PASS   |
| Missing Silver processing date                     | LINEAGE         |  32,593 |        0 |     0.00% | PASS   |
| Missing Silver processing timestamp                | LINEAGE         |  32,593 |        0 |     0.00% | PASS   |

### Findings

* All student records passed validation.
* The 1,111 Bronze `?` values in `imd_band` were correctly converted to NULL.
* The resulting NULL values are expected and therefore passed validation.
* No unresolved sentinel values remain.
* All numeric fields passed range validation.
* Student-module-presentation business keys are unique.
* All records have valid course relationships and complete lineage metadata.

### Silver Action

* Convert `?` in `imd_band` to NULL.
* Standardize categorical fields.
* Deduplicate using the student-module-presentation business key.
* Preserve lineage metadata.

**Overall Status: PASS**

---

## 5. student_registration_silver

### Validation Results

| Check                                       | Type            | Records | Failures | Failure % | Status |
| ------------------------------------------- | --------------- | ------: | -------: | --------: | ------ |
| Row count                                   | VOLUME          |  32,593 |        0 |     0.00% | PASS   |
| Missing code_module                         | NULL            |  32,593 |        0 |     0.00% | PASS   |
| Missing code_presentation                   | NULL            |  32,593 |        0 |     0.00% | PASS   |
| Missing id_student                          | NULL            |  32,593 |        0 |     0.00% | PASS   |
| Missing date_registration                   | NULL            |  32,593 |       45 |     0.14% | PASS   |
| Missing date_unregistration                 | NULL            |  32,593 |   22,521 |    69.10% | PASS   |
| Invalid date_registration range             | RANGE           |  32,593 |        0 |     0.00% | PASS   |
| Invalid date_unregistration range           | RANGE           |  32,593 |        0 |     0.00% | PASS   |
| Duplicate student-registration business key | UNIQUE          |  32,593 |        0 |     0.00% | PASS   |
| Unresolved sentinel (?) values              | SENTINEL        |  32,593 |        0 |     0.00% | PASS   |
| Unstandardized module/presentation values   | STANDARDIZATION |  32,593 |        0 |     0.00% | PASS   |
| Registration without matching course        | FOREIGN KEY     |  32,593 |        0 |     0.00% | PASS   |
| Registration without matching student       | FOREIGN KEY     |  32,593 |        0 |     0.00% | PASS   |
| Missing ingestion date                      | LINEAGE         |  32,593 |        0 |     0.00% | PASS   |
| Missing ingestion timestamp                 | LINEAGE         |  32,593 |        0 |     0.00% | PASS   |

### Findings

* All registration records passed validation.
* 45 `date_registration` NULLs correspond to the expected Bronze `?` values.
* 22,521 `date_unregistration` NULLs correspond to expected Bronze `?` values.
* NULL `date_unregistration` values are also consistent with students who did not unregister.
* No unresolved sentinel values remain.
* Registration dates passed range checks.
* No duplicate student-registration business keys were found.
* All student and course foreign key relationships are valid.

### Silver Action

* Convert `?` registration dates to NULL.
* Retain NULL `date_unregistration` values because they represent unavailable or non-applicable unregistration dates.
* Standardize module and presentation codes.
* Deduplicate registration records.
* Preserve lineage metadata.

**Overall Status: PASS**

---

## 6. student_vle_silver

### Validation Results

| Check                                     | Type            |   Records | Failures | Failure % | Status |
| ----------------------------------------- | --------------- | --------: | -------: | --------: | ------ |
| Bronze-to-Silver deduplication            | VOLUME          | 8,459,320 |        0 |     0.00% | PASS   |
| Missing id_student                        | NULL            | 8,459,320 |        0 |     0.00% | PASS   |
| Missing id_site                           | NULL            | 8,459,320 |        0 |     0.00% | PASS   |
| Missing date                              | NULL            | 8,459,320 |        0 |     0.00% | PASS   |
| Missing code_module                       | NULL            | 8,459,320 |        0 |     0.00% | PASS   |
| Missing code_presentation                 | NULL            | 8,459,320 |        0 |     0.00% | PASS   |
| Missing sum_click                         | NULL            | 8,459,320 |        0 |     0.00% | PASS   |
| Duplicate student-site-date business key  | UNIQUE          | 8,459,320 |        0 |     0.00% | PASS   |
| Unresolved sentinel (?) values            | SENTINEL        | 8,459,320 |        0 |     0.00% | PASS   |
| Unstandardized module/presentation values | STANDARDIZATION | 8,459,320 |        0 |     0.00% | PASS   |
| VLE activity without matching student     | FOREIGN KEY     | 8,459,320 |        0 |     0.00% | PASS   |
| VLE activity without matching site        | FOREIGN KEY     | 8,459,320 |        0 |     0.00% | PASS   |
| VLE activity without matching course      | FOREIGN KEY     | 8,459,320 |        0 |     0.00% | PASS   |
| Missing ingestion timestamp               | LINEAGE         | 8,459,320 |        0 |     0.00% | PASS   |
| Missing ingestion date                    | LINEAGE         | 8,459,320 |        0 |     0.00% | PASS   |

### Findings

* Silver contains 8,459,320 student-VLE activity records.
* The Bronze-to-Silver deduplication check passed, confirming that the Silver record count matches the expected deduplicated count.
* No duplicate student-site-date business keys remain in Silver.
* All required fields passed NULL checks.
* No unresolved sentinel values remain.
* Standardization checks passed.
* All student, VLE site, and course foreign key relationships are valid.
* Lineage metadata is complete.

### Silver Action

* Deduplicate student-VLE activity using the defined business key.
* Retain the valid deduplicated records.
* Preserve valid relative dates.
* Retain records with valid student, VLE site, and course relationships.
* Preserve ingestion lineage.

**Overall Status: PASS**

---

## 7. vle_silver

### Validation Results

| Check                                     | Type            | Records | Failures | Failure % | Status |
| ----------------------------------------- | --------------- | ------: | -------: | --------: | ------ |
| Bronze-to-Silver row reduction            | VOLUME          |   6,364 |        0 |     0.00% | PASS   |
| Missing id_site                           | NULL            |   6,364 |        0 |     0.00% | PASS   |
| Missing code_module                       | NULL            |   6,364 |        0 |     0.00% | PASS   |
| Missing code_presentation                 | NULL            |   6,364 |        0 |     0.00% | PASS   |
| Missing activity_type                     | NULL            |   6,364 |        0 |     0.00% | PASS   |
| Duplicate VLE site business key           | UNIQUE          |   6,364 |        0 |     0.00% | PASS   |
| Unresolved sentinel (?) values            | SENTINEL        |   6,364 |        0 |     0.00% | PASS   |
| Unstandardized module/presentation values | STANDARDIZATION |   6,364 |        0 |     0.00% | PASS   |
| VLE site without matching course          | FOREIGN KEY     |   6,364 |        0 |     0.00% | PASS   |
| Missing ingestion timestamp               | LINEAGE         |   6,364 |        0 |     0.00% | PASS   |
| Missing ingestion date                    | LINEAGE         |   6,364 |        0 |     0.00% | PASS   |

### Findings

* All 6,364 VLE records passed validation.
* The Silver row count satisfies the expected Bronze-to-Silver row reduction rule.
* All VLE site identifiers are unique and non-null.
* No unresolved sentinel values remain.
* Module, presentation, and activity type values were standardized.
* All VLE sites have valid course relationships.
* Lineage metadata is complete.

### Silver Action

* Standardize module and presentation codes.
* Standardize activity types to lowercase.
* Retain valid VLE site records.
* Preserve lineage metadata.

**Overall Status: PASS**

---

# Overall Silver Validation Summary

| Silver Table                  |   Records | Main Finding                                                               | Status | Silver Action                             |
| ----------------------------- | --------: | -------------------------------------------------------------------------- | ------ | ----------------------------------------- |
| `assessment_silver`           |       206 | 11 expected NULL assessment dates from Bronze `?` values                   | PASS   | Convert `?` to NULL; retain records       |
| `courses_silver`              |        22 | No data quality issues identified                                          | PASS   | Standardize and cast fields               |
| `student_assessment_silver`   |   173,912 | 173 expected NULL scores from Bronze `?` values                            | PASS   | Convert `?` to NULL; retain records       |
| `student_info_silver`         |    32,593 | 1,111 expected NULL `imd_band` values from Bronze `?` values               | PASS   | Convert `?` to NULL; retain records       |
| `student_registration_silver` |    32,593 | Expected NULL registration and unregistration dates from Bronze `?` values | PASS   | Convert `?` to NULL; retain valid records |
| `student_vle_silver`          | 8,459,320 | Bronze-to-Silver deduplication check passed                                | PASS   | Deduplicate using defined business key    |
| `vle_silver`                  |     6,364 | Silver satisfies the expected Bronze-to-Silver row reduction rule          | PASS   | Standardize and retain valid records      |

## Overall Silver Conclusion

All seven Silver tables passed their respective data quality validations.

The Silver layer successfully addressed the issues identified in Bronze by:

* converting source sentinel values (`?`) to NULL where appropriate;
* standardizing categorical and code fields;
* casting fields to their expected data types;
* deduplicating records where required;
* preserving intentional NULL values;
* validating foreign key relationships; and
* maintaining ingestion and processing lineage.

Expected NULL values were validated against their Bronze source values and were classified as **PASS** rather than data quality failures.

All validation checks returned **PASS**, with no WARN or FAIL conditions identified during the validation run.

**Overall Silver Status: PASS**
