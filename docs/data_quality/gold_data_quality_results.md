# OULAD Gold Data Quality Validation Results

The Gold layer validation confirms that the dimensional and fact tables are structurally sound, maintain referential and business relationships, and are ready for downstream analytics. Validation checks cover volume, NULL values, uniqueness, ranges, accepted values, foreign keys, relationship consistency, and data lineage.

## 1. dim_assessment

### Validation Results

| Check                               | Type           | Records | Failures | Failure % | Status |
| ----------------------------------- | -------------- | ------: | -------: | --------: | ------ |
| Row count                           | VOLUME         |     206 |        0 |     0.00% | PASS   |
| Missing assessment_key              | NULL           |     206 |        0 |     0.00% | PASS   |
| Duplicate assessment_key            | UNIQUE         |     206 |        0 |     0.00% | PASS   |
| Duplicate assessment business key   | UNIQUE         |     206 |        0 |     0.00% | PASS   |
| Missing id_assessment               | NULL           |     206 |        0 |     0.00% | PASS   |
| Missing course_key                  | NULL           |     206 |        0 |     0.00% | PASS   |
| Assessment without matching course  | FOREIGN KEY    |     206 |        0 |     0.00% | PASS   |
| Invalid assessment_type             | ACCEPTED VALUE |     206 |        0 |     0.00% | PASS   |
| Missing assessment date             | NULL           |     206 |       11 |     5.34% | PASS   |
| Invalid weight range                | RANGE          |     206 |        0 |     0.00% | PASS   |
| Missing Silver processing timestamp | LINEAGE        |     206 |        0 |     0.00% | PASS   |
| Missing Gold processing timestamp   | LINEAGE        |     206 |        0 |     0.00% | PASS   |

### Findings

* All 206 assessment records passed structural, uniqueness, range, accepted value, foreign key, and lineage checks.
* 11 assessment dates remain NULL.
* These correspond exactly to the expected missing assessment dates identified from the Bronze source.
* The missing assessment dates are expected because the source did not provide a date.
* All assessment types and weights are valid.
* No duplicate assessment business keys were found.

### Gold Action

* Retain expected NULL assessment dates.
* Maintain the assessment business key of `id_assessment + code_module + code_presentation`.
* Preserve valid course relationships.
* Preserve Silver and Gold lineage metadata.

**Overall Status: PASS**

---

## 2. dim_course

### Validation Results

| Check                               | Type    | Records | Failures | Failure % | Status |
| ----------------------------------- | ------- | ------: | -------: | --------: | ------ |
| Row count                           | VOLUME  |      22 |        0 |     0.00% | PASS   |
| Missing course_key                  | NULL    |      22 |        0 |     0.00% | PASS   |
| Duplicate course_key                | UNIQUE  |      22 |        0 |     0.00% | PASS   |
| Duplicate course business key       | UNIQUE  |      22 |        0 |     0.00% | PASS   |
| Missing code_module                 | NULL    |      22 |        0 |     0.00% | PASS   |
| Missing code_presentation           | NULL    |      22 |        0 |     0.00% | PASS   |
| Invalid module presentation length  | RANGE   |      22 |        0 |     0.00% | PASS   |
| Missing Silver processing timestamp | LINEAGE |      22 |        0 |     0.00% | PASS   |
| Missing Gold processing timestamp   | LINEAGE |      22 |        0 |     0.00% | PASS   |

### Findings

* All 22 course presentation records passed validation.
* No missing required fields were identified.
* No duplicate course keys or course business keys were found.
* All module presentation lengths are valid.
* Silver and Gold lineage metadata is complete.

### Gold Action

* Maintain one record per module presentation.
* Preserve the course business key of `code_module + code_presentation`.
* Retain valid module presentation lengths.
* Preserve Silver and Gold lineage metadata.

**Overall Status: PASS**

---

## 3. dim_student

### Validation Results

| Check                               | Type           | Records | Failures | Failure % | Status |
| ----------------------------------- | -------------- | ------: | -------: | --------: | ------ |
| Row count                           | VOLUME         |  32,593 |        0 |     0.00% | PASS   |
| Missing student_key                 | NULL           |  32,593 |        0 |     0.00% | PASS   |
| Duplicate student_key               | UNIQUE         |  32,593 |        0 |     0.00% | PASS   |
| Duplicate student enrollment        | UNIQUE         |  32,593 |        0 |     0.00% | PASS   |
| Missing id_student                  | NULL           |  32,593 |        0 |     0.00% | PASS   |
| Missing course_key                  | NULL           |  32,593 |        0 |     0.00% | PASS   |
| Student without matching course     | FOREIGN KEY    |  32,593 |        0 |     0.00% | PASS   |
| Invalid final_result                | ACCEPTED VALUE |  32,593 |        0 |     0.00% | PASS   |
| Invalid gender                      | ACCEPTED VALUE |  32,593 |        0 |     0.00% | PASS   |
| Invalid age_band                    | ACCEPTED VALUE |  32,593 |        0 |     0.00% | PASS   |
| Invalid disability                  | ACCEPTED VALUE |  32,593 |        0 |     0.00% | PASS   |
| Invalid previous attempts           | RANGE          |  32,593 |        0 |     0.00% | PASS   |
| Invalid studied credits             | RANGE          |  32,593 |        0 |     0.00% | PASS   |
| Missing Silver processing timestamp | LINEAGE        |  32,593 |        0 |     0.00% | PASS   |
| Missing Gold processing timestamp   | LINEAGE        |  32,593 |        0 |     0.00% | PASS   |

### Findings

* All 32,593 student enrollment records passed validation.
* Student surrogate keys and student enrollment business keys are unique.
* All students have valid course relationships.
* All categorical fields contain valid values.
* Previous attempts and studied credits passed range validation.
* Silver and Gold lineage metadata is complete.

### Gold Action

* Maintain one record per student-course enrollment.
* Use `id_student + code_module + code_presentation` as the student enrollment business key.
* Preserve valid course relationships.
* Preserve Silver and Gold lineage metadata.

**Overall Status: PASS**

---

## 4. dim_date

### Validation Results

| Check                               | Type    | Records | Failures | Failure % | Status |
| ----------------------------------- | ------- | ------: | -------: | --------: | ------ |
| Row count                           | VOLUME  |     974 |        0 |     0.00% | PASS   |
| Missing date_key                    | NULL    |     974 |        0 |     0.00% | PASS   |
| Duplicate date_key                  | UNIQUE  |     974 |        0 |     0.00% | PASS   |
| Missing relative_day                | NULL    |     974 |        0 |     0.00% | PASS   |
| Duplicate relative_day              | UNIQUE  |     974 |        0 |     0.00% | PASS   |
| Invalid relative_day range          | RANGE   |     974 |        0 |     0.00% | PASS   |
| Invalid relative_week               | RANGE   |     974 |        0 |     0.00% | PASS   |
| Missing Silver processing timestamp | LINEAGE |     974 |        0 |     0.00% | PASS   |
| Missing Gold processing timestamp   | LINEAGE |     974 |        0 |     0.00% | PASS   |

### Findings

* All 974 relative-day records passed validation.
* The date sequence is complete and contains no duplicate relative days.
* All relative days fall within the expected range of `-365 to 608`.
* `relative_week` values are calculated consistently from `relative_day`.
* Silver and Gold lineage metadata is complete.

### Gold Action

* Maintain a complete sequence of relative days.
* Preserve unique `date_key` and `relative_day` values.
* Use the dimension for relative course progression and activity analysis.
* Preserve Silver and Gold lineage metadata.

**Overall Status: PASS**

---

## 5. dim_vle

### Validation Results

| Check                               | Type        | Records | Failures | Failure % | Status |
| ----------------------------------- | ----------- | ------: | -------: | --------: | ------ |
| Row count                           | VOLUME      |   6,364 |        0 |     0.00% | PASS   |
| Missing site_key                    | NULL        |   6,364 |        0 |     0.00% | PASS   |
| Duplicate site_key                  | UNIQUE      |   6,364 |        0 |     0.00% | PASS   |
| Missing id_site                     | NULL        |   6,364 |        0 |     0.00% | PASS   |
| Missing course_key                  | NULL        |   6,364 |        0 |     0.00% | PASS   |
| Duplicate VLE business key          | UNIQUE      |   6,364 |        0 |     0.00% | PASS   |
| VLE without matching course         | FOREIGN KEY |   6,364 |        0 |     0.00% | PASS   |
| Invalid week range                  | RANGE       |   6,364 |        0 |     0.00% | PASS   |
| Missing Silver processing timestamp | LINEAGE     |   6,364 |        0 |     0.00% | PASS   |
| Missing Gold processing timestamp   | LINEAGE     |   6,364 |        0 |     0.00% | PASS   |

### Findings

* All 6,364 VLE records passed validation.
* No missing site or course keys were found.
* VLE business keys are unique.
* All VLE sites have valid course relationships.
* Week ranges are valid.
* Silver and Gold lineage metadata is complete.

### Gold Action

* Maintain one record per VLE site within a course.
* Preserve the VLE business key of `id_site + course_key`.
* Retain valid course relationships.
* Preserve Silver and Gold lineage metadata.

**Overall Status: PASS**

---

## 6. fact_assessment

### Validation Results

| Check                                  | Type           | Records | Failures | Failure % | Status |
| -------------------------------------- | -------------- | ------: | -------: | --------: | ------ |
| Row count                              | VOLUME         | 207,319 |        0 |     0.00% | PASS   |
| Missing student_key                    | NULL           | 207,319 |        0 |     0.00% | PASS   |
| Missing course_key                     | NULL           | 207,319 |        0 |     0.00% | PASS   |
| Missing assessment_key                 | NULL           | 207,319 |        0 |     0.00% | PASS   |
| Missing date_key                       | NULL           | 207,319 |        0 |     0.00% | PASS   |
| Duplicate assessment fact              | UNIQUE         | 207,319 |        0 |     0.00% | PASS   |
| Assessment without matching student    | FOREIGN KEY    | 207,319 |        0 |     0.00% | PASS   |
| Assessment without matching course     | FOREIGN KEY    | 207,319 |        0 |     0.00% | PASS   |
| Assessment without matching assessment | FOREIGN KEY    | 207,319 |        0 |     0.00% | PASS   |
| Assessment without matching date       | FOREIGN KEY    | 207,319 |        0 |     0.00% | PASS   |
| Student-course mismatch                | RELATIONSHIP   | 207,319 |        0 |     0.00% | PASS   |
| Invalid score range                    | RANGE          | 207,319 |        0 |     0.00% | PASS   |
| Invalid is_banked value                | ACCEPTED VALUE | 207,319 |        0 |     0.00% | PASS   |
| Missing Gold processing timestamp      | LINEAGE        | 207,319 |        0 |     0.00% | PASS   |

### Findings

* All 207,319 assessment fact records passed validation.
* All required foreign keys are populated and reference valid dimension records.
* No duplicate assessment facts were identified.
* Student-course relationships are consistent with the assessment course.
* Scores are within the valid 0–100 range.
* All `is_banked` values are valid.
* Gold lineage metadata is complete.

### Gold Action

* Maintain the fact grain of one student assessment result.
* Use the correct student-course enrollment when assigning `student_key`.
* Validate the student-course relationship against the assessment course.
* Preserve Gold processing lineage.

**Overall Status: PASS**

---

## 7. fact_vle_interaction

### Validation Results

| Check                                 | Type         |    Records | Failures | Failure % | Status |
| ------------------------------------- | ------------ | ---------: | -------: | --------: | ------ |
| Row count                             | VOLUME       | 10,334,505 |        0 |     0.00% | PASS   |
| Missing student_key                   | NULL         | 10,334,505 |        0 |     0.00% | PASS   |
| Missing course_key                    | NULL         | 10,334,505 |        0 |     0.00% | PASS   |
| Missing site_key                      | NULL         | 10,334,505 |        0 |     0.00% | PASS   |
| Missing date_key                      | NULL         | 10,334,505 |        0 |     0.00% | PASS   |
| Duplicate VLE interaction             | UNIQUE       | 10,334,505 |        0 |     0.00% | PASS   |
| Interaction without matching student  | FOREIGN KEY  | 10,334,505 |        0 |     0.00% | PASS   |
| Interaction without matching course   | FOREIGN KEY  | 10,334,505 |        0 |     0.00% | PASS   |
| Interaction without matching VLE site | FOREIGN KEY  | 10,334,505 |        0 |     0.00% | PASS   |
| Interaction without matching date     | FOREIGN KEY  | 10,334,505 |        0 |     0.00% | PASS   |
| Student-course mismatch               | RELATIONSHIP | 10,334,505 |        0 |     0.00% | PASS   |
| Course-site mismatch                  | RELATIONSHIP | 10,334,505 |        0 |     0.00% | PASS   |
| Invalid sum_click                     | RANGE        | 10,334,505 |        0 |     0.00% | PASS   |
| Missing Gold processing timestamp     | LINEAGE      | 10,334,505 |        0 |     0.00% | PASS   |

### Findings

* All 10,334,505 VLE interaction records passed validation.
* All required keys are populated.
* No duplicate VLE interaction business keys were found.
* Student, course, VLE site, and date foreign key relationships are valid.
* Student-course relationships are consistent.
* Course-site relationships are consistent.
* All `sum_click` values are valid.
* Gold lineage metadata is complete.

### Gold Action

* Maintain the fact grain of one student-VLE-site interaction per relative day.
* Use the complete student-course business key when assigning `student_key`.
* Validate that the student's course matches the interaction course.
* Validate that the VLE site belongs to the interaction course.
* Preserve Gold processing lineage.

**Overall Status: PASS**

---

# Overall Gold Validation Summary

| Gold Table             |    Records | Main Finding                                           | Status | Gold Action                                        |
| ---------------------- | ---------: | ------------------------------------------------------ | ------ | -------------------------------------------------- |
| `dim_assessment`       |        206 | 11 expected NULL assessment dates                      | PASS   | Retain expected NULL dates and valid relationships |
| `dim_course`           |         22 | No data quality issues identified                      | PASS   | Maintain unique course presentations               |
| `dim_student`          |     32,593 | All student-course enrollments valid                   | PASS   | Maintain unique student-course enrollments         |
| `dim_date`             |        974 | Complete relative-day sequence                         | PASS   | Maintain relative date dimension                   |
| `dim_vle`              |      6,364 | All VLE sites have valid course relationships          | PASS   | Maintain unique course-site records                |
| `fact_assessment`      |    207,319 | Student-course relationships validated                 | PASS   | Maintain correct student-course mapping            |
| `fact_vle_interaction` | 10,334,505 | Student-course and course-site relationships validated | PASS   | Maintain correct relationship mappings             |

## Overall Gold Conclusion

All seven Gold tables passed their respective data quality validations.

The Gold layer successfully validated:

* expected record volumes;
* required and non-NULL keys;
* surrogate and business key uniqueness;
* foreign key relationships;
* accepted categorical values;
* numeric ranges;
* student-course and course-site relationship consistency; and
* Silver and Gold processing lineage.

Expected NULL values, such as missing assessment dates, were validated against the source expectations and classified as **PASS** rather than data quality failures.

The fact-table relationship checks confirm that student records are associated with the correct course presentation by using the complete student-course business key:

`id_student + code_module + code_presentation`

All validation checks returned **PASS**, with no WARN or FAIL conditions identified after the required fact-table relationship correction.

**Overall Gold Status: PASS**
