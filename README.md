# collections-recovery-analysis

Project Overview

This project analyses collections data to answer two main business questions:

Is the reported 11% month-on-month recovery improvement actually supported by the data?

Where should the company invest the next ₹10 Cr to improve collections performance?

The raw data contains duplicates, inconsistent IDs, timezone differences, attribution problems, and misleading denominator choices.
The analysis first fixes these issues and then measures recovery using consistent business definitions.

Main Conclusion

The data shows that recovery improved in July, but the exact 11% improvement is not supported as a clean operational uplift.

After cleaning duplicate payments and converting timestamps to IST:

June recovery: ₹17.53 Cr

July recovery: ₹18.74 Cr

Actual June → July increase: +6.88%

Some targeted-account metrics improved by around 9–12%, but accounts that were targeted in both June and July improved by only about 1.3%.

This suggests that a meaningful part of the July improvement came from which borrowers were targeted, rather than a major improvement in calling or agent performance.

Key Findings

1. The 11% claim is not independently verified

Different recovery definitions produce different results.

For the latest complete month:

Clean total recovery: +6.88%

Targeted-account metrics: roughly +9% to +12%

Same-account cohort: only about +1.3%

So the safest conclusion is:

Recovery improved in July, but an 11% operational improvement is not proven.

2. Data quality has a real business impact

Important issues found in the raw data include:

500 duplicate payment records

Event-level borrower IDs are inconsistent with the account master

Agent records contain multiple conflicting versions

Calls are stored in different timezones

Campaign-to-payment attribution is weak

Some metric denominators can produce misleading results

For example, using only contacted accounts as the denominator for PTP rate can produce rates above 100%, which is clearly not a valid business metric.

3. No clear winner was found in calling operations

We checked:

telephony vendor

calling hour

attempt number

geography

DPD bucket

risk segment

loan type

Most of these showed only small differences.

Contact performance also did not improve enough to explain the July recovery increase.

4. ₹10 Cr Recommendation — Better Borrower Targeting

The recommended investment area is:

Better Borrower Targeting

Why?

July's improvement is stronger when looking at the targeted population.

The same-account cohort improved very little.

Contact rate did not improve.

Campaign and targeting data contains clear quality problems.

Better targeting can improve which borrowers are contacted, how they are prioritised, and how campaign performance is measured.

The financial estimate is treated as a scenario, not a guaranteed result, because the dataset does not contain a controlled experiment proving causal uplift.

Repository Structure

collections-recovery-analysis/
│
├── README.md
│
├── notebook/
│   └── Collections_Recovery_Analysis_Refined.ipynb
│
├── sql/
│   ├── database_setup_and_loading.sql
│   ├── cleaning_and_entity_resolution.sql
│   ├── metric_calculations.sql
│   ├── data_quality_checks.sql
│   ├── validate_11pct_claim.sql
│   ├── driver_and_cohort_analysis.sql
│   ├── counterfactual_analysis.sql
│   ├── investment_scenarios.sql
│   └── run_all.sql
│
├── dashboard/
│   └── executive_dashboard_refined.html
│
├── reports/
│   ├── executive_memo_revised.docx
│   └── data_quality_report_refined.docx
│
└── architecture/
    └── collections_architecture_diagram.png

Deliverables

Deliverable

Purpose

Executive Memo

Two-page leadership summary of what happened, why, and what to do

Executive Dashboard

One-screen summary of the most important findings

Analysis Notebook

Main Python analysis with cleaning, calculations and charts

SQL Repository

Reproducible MySQL cleaning, metric and analytical queries

Data Quality Report

Documents the major data issues and how they were handled

Architecture Diagram

Shows how raw data can move through cleaning, metrics and reporting in production

Tools Used

Python

The analysis notebook intentionally uses only:

pandas

NumPy

Matplotlib

SQL

MySQL 8.0

Reporting

HTML/CSS for the executive dashboard

Microsoft Word for the executive memo and data-quality report

Analysis Approach

The analysis follows a simple process:

Raw Data
   ↓
Data Quality Checks
   ↓
Cleaning & Standardisation
   ↓
Consistent Business Metrics
   ↓
Recovery Analysis
   ↓
Driver / Cohort Analysis
   ↓
₹10 Cr Investment Recommendation

Major cleaning steps include:

removing duplicate payments

using account_id as the main account key

rebuilding borrower mapping from the accounts table

standardising timestamps to IST

standardising disposition codes

checking campaign and event attribution

using consistent denominators for KPIs

How to Run the Analysis

Python Notebook

Install the required libraries:

pip install pandas numpy matplotlib jupyter

Open:

notebook/Collections_Recovery_Analysis_Refined.ipynb

Run the notebook cells from top to bottom.

The notebook expects the original CSV files to be available in the local data folder/path used in the loading section.

MySQL

The SQL repository is designed for MySQL 8.0.

Run:

sql/run_all.sql

after updating the CSV file paths in the loading script for your local system.

Data Note

The original raw dataset provided for the assignment is not included in this public repository.

This avoids unnecessarily redistributing the source assignment data.
The analysis notebook and SQL scripts show the complete cleaning and analysis logic needed to reproduce the work when the source CSV files are available.

Final Business Takeaway

The analysis does not support presenting 11% as a proven operational improvement.

The stronger conclusion is:

July recovery improved, but much of the apparent improvement is linked to targeting and portfolio selection rather than a clear improvement in collection operations.

Based on the available evidence, Better Borrower Targeting is the preferred area for the ₹10 Cr investment, with further controlled testing recommended before assuming a fixed financial uplift.
