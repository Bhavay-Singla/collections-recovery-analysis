-- Run from repository root using MySQL client:
-- SOURCE sql/run_all.sql;
-- IMPORTANT: edit CSV paths in 02_load_data.sql first.

SOURCE sql/00_database.sql;
SOURCE sql/01_raw_ddl.sql;
SOURCE sql/02_load_data.sql;
SOURCE sql/03_staging_views.sql;
SOURCE sql/04_entity_resolution.sql;
SOURCE sql/05_clean_event_views.sql;
SOURCE sql/06_golden_account_month.sql;
SOURCE sql/07_metric_layer.sql;
SOURCE sql/08_data_quality_checks.sql;
SOURCE sql/09_validate_11pct_claim.sql;
SOURCE sql/10_driver_analysis.sql;
SOURCE sql/11_counterfactual_panel.sql;
SOURCE sql/12_investment_scenarios.sql;
SOURCE sql/13_validation_checks.sql;
