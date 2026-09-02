USE collections_analytics;

-- ============================================================
-- RECONCILIATION: RAW -> CLEAN
-- ============================================================

CREATE OR REPLACE VIEW dq_record_reconciliation AS
SELECT 'borrowers' AS dataset,
       (SELECT COUNT(*) FROM raw_borrowers) AS raw_rows,
       (SELECT COUNT(DISTINCT borrower_id) FROM stg_borrowers) AS distinct_business_ids,
       (SELECT COUNT(*) FROM clean_borrowers) AS clean_rows,
       (SELECT COUNT(*) FROM raw_borrowers) - (SELECT COUNT(*) FROM clean_borrowers) AS rows_collapsed_or_resolved,
       'master survivorship; conflicts flagged' AS treatment
UNION ALL
SELECT 'accounts', (SELECT COUNT(*) FROM raw_accounts), (SELECT COUNT(DISTINCT account_id) FROM stg_accounts),
       (SELECT COUNT(*) FROM clean_accounts), (SELECT COUNT(*) FROM raw_accounts)-(SELECT COUNT(*) FROM clean_accounts),
       'account_id accepted as canonical key'
UNION ALL
SELECT 'agents', (SELECT COUNT(*) FROM raw_agents), (SELECT COUNT(DISTINCT agent_id) FROM stg_agents),
       (SELECT COUNT(*) FROM clean_agents), (SELECT COUNT(*) FROM raw_agents)-(SELECT COUNT(*) FROM clean_agents),
       'latest master version retained; identity conflict flagged'
UNION ALL
SELECT 'calls', (SELECT COUNT(*) FROM raw_calls), (SELECT COUNT(DISTINCT call_id) FROM stg_calls),
       (SELECT COUNT(*) FROM clean_calls), (SELECT COUNT(*) FROM raw_calls)-(SELECT COUNT(*) FROM clean_calls),
       'duplicate IDs collapsed; critical conflicts quarantined'
UNION ALL
SELECT 'payments', (SELECT COUNT(*) FROM raw_payments), (SELECT COUNT(DISTINCT payment_id) FROM stg_payments),
       (SELECT COUNT(*) FROM clean_payments), (SELECT COUNT(*) FROM raw_payments)-(SELECT COUNT(*) FROM clean_payments),
       'payment_id dedupe; conflicting critical IDs quarantined'
UNION ALL
SELECT 'whatsapp_events', (SELECT COUNT(*) FROM raw_whatsapp_events), (SELECT COUNT(DISTINCT whatsapp_event_id) FROM stg_whatsapp_events),
       (SELECT COUNT(*) FROM clean_whatsapp_events), (SELECT COUNT(*) FROM raw_whatsapp_events)-(SELECT COUNT(*) FROM clean_whatsapp_events),
       'event ID dedupe; critical conflicts quarantined';

CREATE OR REPLACE VIEW dq_payment_financial_impact AS
SELECT
  raw_success_rows,
  clean_success_rows,
  raw_success_recovery,
  clean_success_recovery,
  raw_success_recovery - clean_success_recovery AS duplicate_inflation_removed,
  (raw_success_recovery - clean_success_recovery) / NULLIF(clean_success_recovery,0) AS inflation_vs_clean
FROM (
  SELECT
    (SELECT COUNT(*) FROM stg_payments WHERE payment_status='SUCCESS') AS raw_success_rows,
    (SELECT COUNT(*) FROM clean_payments WHERE payment_status='SUCCESS') AS clean_success_rows,
    (SELECT SUM(amount) FROM stg_payments WHERE payment_status='SUCCESS') AS raw_success_recovery,
    (SELECT SUM(amount) FROM clean_payments WHERE payment_status='SUCCESS') AS clean_success_recovery
) x;

-- Payment references are not safe dedupe keys.
CREATE OR REPLACE VIEW dq_duplicate_payment_references AS
SELECT
  payment_reference,
  COUNT(*) AS payment_ids,
  COUNT(DISTINCT account_id) AS accounts,
  COUNT(DISTINCT amount) AS amounts,
  COUNT(DISTINCT payment_status) AS statuses,
  MIN(event_at_ist) AS first_seen_ist,
  MAX(event_at_ist) AS last_seen_ist
FROM clean_payments
WHERE payment_reference IS NOT NULL
GROUP BY payment_reference
HAVING COUNT(*) > 1;

-- ============================================================
-- BORROWER-ID INTEGRITY
-- ============================================================

CREATE OR REPLACE VIEW dq_event_borrower_id_mismatch AS
SELECT 'calls' AS dataset, COUNT(*) AS rows_checked, SUM(borrower_id_mismatch_flag) AS mismatch_rows,
       SUM(borrower_id_mismatch_flag)/NULLIF(COUNT(*),0) AS mismatch_rate FROM clean_calls
UNION ALL
SELECT 'call_attempts', COUNT(*), SUM(borrower_id_mismatch_flag), SUM(borrower_id_mismatch_flag)/NULLIF(COUNT(*),0) FROM clean_call_attempts
UNION ALL
SELECT 'call_dispositions', COUNT(*), SUM(borrower_id_mismatch_flag), SUM(borrower_id_mismatch_flag)/NULLIF(COUNT(*),0) FROM clean_call_dispositions
UNION ALL
SELECT 'whatsapp_events', COUNT(*), SUM(borrower_id_mismatch_flag), SUM(borrower_id_mismatch_flag)/NULLIF(COUNT(*),0) FROM clean_whatsapp_events
UNION ALL
SELECT 'sms_events', COUNT(*), SUM(borrower_id_mismatch_flag), SUM(borrower_id_mismatch_flag)/NULLIF(COUNT(*),0) FROM clean_sms_events
UNION ALL
SELECT 'field_visits', COUNT(*), SUM(borrower_id_mismatch_flag), SUM(borrower_id_mismatch_flag)/NULLIF(COUNT(*),0) FROM clean_field_visits
UNION ALL
SELECT 'promises_to_pay', COUNT(*), SUM(borrower_id_mismatch_flag), SUM(borrower_id_mismatch_flag)/NULLIF(COUNT(*),0) FROM clean_promises_to_pay
UNION ALL
SELECT 'payments', COUNT(*), SUM(borrower_id_mismatch_flag), SUM(borrower_id_mismatch_flag)/NULLIF(COUNT(*),0) FROM clean_payments
UNION ALL
SELECT 'complaints', COUNT(*), SUM(borrower_id_mismatch_flag), SUM(borrower_id_mismatch_flag)/NULLIF(COUNT(*),0) FROM clean_complaints
UNION ALL
SELECT 'account_status_history', COUNT(*), SUM(borrower_id_mismatch_flag), SUM(borrower_id_mismatch_flag)/NULLIF(COUNT(*),0) FROM clean_account_status_history;

-- ============================================================
-- CALL-LINK ATTRIBUTION INTEGRITY
-- ============================================================

CREATE OR REPLACE VIEW dq_call_link_integrity AS
SELECT 'call_attempts' AS dataset,
       COUNT(*) AS rows_checked,
       SUM(call_link_valid_flag) AS valid_links,
       COUNT(*) - SUM(call_link_valid_flag) AS invalid_links,
       SUM(call_link_valid_flag)/NULLIF(COUNT(*),0) AS valid_link_rate
FROM clean_call_attempts
UNION ALL
SELECT 'call_dispositions', COUNT(*), SUM(call_link_valid_flag), COUNT(*)-SUM(call_link_valid_flag),
       SUM(call_link_valid_flag)/NULLIF(COUNT(*),0)
FROM clean_call_dispositions;

-- ============================================================
-- CAMPAIGN / TARGETING QUALITY
-- ============================================================

CREATE OR REPLACE VIEW dq_campaign_targeting_quality AS
SELECT
  COUNT(*) AS target_rows,
  SUM(campaign_window_valid_flag = 1) AS in_campaign_window,
  SUM(campaign_window_valid_flag = 0) AS outside_campaign_window,
  SUM(campaign_window_valid_flag = 0)/NULLIF(COUNT(*),0) AS outside_campaign_window_rate,
  SUM(static_target_rule_match_flag = 1) AS static_rule_matches,
  SUM(static_target_rule_match_flag = 0) AS static_rule_mismatches,
  SUM(static_target_rule_match_flag IS NULL) AS static_rule_not_testable,
  SUM(static_target_rule_match_flag = 1)
    / NULLIF(SUM(static_target_rule_match_flag IS NOT NULL),0) AS static_rule_match_rate_when_testable
FROM clean_targeting;

-- ============================================================
-- MASTER CONFLICTS
-- ============================================================

CREATE OR REPLACE VIEW dq_master_conflicts AS
SELECT 'borrower' AS entity,
       COUNT(*) AS canonical_entities,
       SUM(borrower_conflict_flag) AS conflicting_entities,
       SUM(borrower_conflict_flag)/NULLIF(COUNT(*),0) AS conflict_rate
FROM clean_borrowers
UNION ALL
SELECT 'agent', COUNT(*), SUM(agent_conflict_flag), SUM(agent_conflict_flag)/NULLIF(COUNT(*),0)
FROM clean_agents;

-- ============================================================
-- TIMEZONE IMPACT
-- ============================================================

CREATE OR REPLACE VIEW dq_timezone_impact AS
SELECT
  'calls' AS dataset,
  COUNT(*) AS rows_checked,
  SUM(DATE(event_at_raw) <> DATE(event_at_ist)) AS calendar_date_changed,
  SUM(DATE_FORMAT(event_at_raw,'%Y-%m') <> DATE_FORMAT(event_at_ist,'%Y-%m')) AS calendar_month_changed,
  SUM(DATE(event_at_raw) <> DATE(event_at_ist))/NULLIF(COUNT(*),0) AS date_change_rate,
  SUM(DATE_FORMAT(event_at_raw,'%Y-%m') <> DATE_FORMAT(event_at_ist,'%Y-%m'))/NULLIF(COUNT(*),0) AS month_change_rate
FROM clean_calls
WHERE event_at_raw IS NOT NULL AND event_at_ist IS NOT NULL
UNION ALL
SELECT
  'payments', COUNT(*),
  SUM(DATE(event_at_raw) <> DATE(event_at_ist)),
  SUM(DATE_FORMAT(event_at_raw,'%Y-%m') <> DATE_FORMAT(event_at_ist,'%Y-%m')),
  SUM(DATE(event_at_raw) <> DATE(event_at_ist))/NULLIF(COUNT(*),0),
  SUM(DATE_FORMAT(event_at_raw,'%Y-%m') <> DATE_FORMAT(event_at_ist,'%Y-%m'))/NULLIF(COUNT(*),0)
FROM clean_payments
WHERE event_at_raw IS NOT NULL AND event_at_ist IS NOT NULL;

-- ============================================================
-- STATUS HISTORY ANOMALIES
-- ============================================================

CREATE OR REPLACE VIEW dq_status_history_anomalies AS
SELECT
  COUNT(*) AS rows_checked,
  SUM(recorded_before_event_flag) AS recorded_before_event_rows,
  SUM(recorded_before_event_flag)/NULLIF(COUNT(*),0) AS recorded_before_event_rate
FROM clean_account_status_history;

-- ============================================================
-- REPORT
-- ============================================================
SELECT * FROM dq_record_reconciliation ORDER BY dataset;
SELECT * FROM dq_payment_financial_impact;
SELECT COUNT(*) AS duplicate_payment_reference_groups FROM dq_duplicate_payment_references;
SELECT * FROM dq_event_borrower_id_mismatch ORDER BY dataset;
SELECT * FROM dq_call_link_integrity ORDER BY dataset;
SELECT * FROM dq_campaign_targeting_quality;
SELECT * FROM dq_master_conflicts;
SELECT * FROM dq_timezone_impact;
SELECT * FROM dq_status_history_anomalies;
