USE collections_analytics;

-- ============================================================
-- MONTHLY KPI LAYER
-- ============================================================

CREATE OR REPLACE VIEW mart_monthly_recovery AS
WITH agent_hours AS (
  SELECT
    month_start,
    SUM(session_hours) AS agent_hours
  FROM clean_agent_sessions
  WHERE session_hours IS NOT NULL AND session_hours >= 0
  GROUP BY month_start
)
SELECT
  g.month_start,
  MAX(g.is_complete_month) AS is_complete_month,
  MAX(g.observed_through) AS observed_through,
  COUNT(*) AS account_population,

  SUM(g.successful_recovery) AS clean_successful_recovery,
  SUM(g.successful_payment_count) AS successful_payment_count,
  SUM(g.payer_flag) AS unique_paying_accounts,
  SUM(g.successful_recovery) / NULLIF(SUM(g.payer_flag),0) AS recovery_per_paying_account,

  SUM(g.targeted_flag) AS targeted_accounts,
  SUM(CASE WHEN g.targeted_flag = 1 THEN g.successful_recovery ELSE 0 END) AS recovery_from_targeted_accounts,
  SUM(CASE WHEN g.targeted_flag = 1 THEN g.successful_recovery ELSE 0 END)
    / NULLIF(SUM(g.targeted_flag),0) AS recovery_per_targeted_account,
  SUM(CASE WHEN g.targeted_flag = 1 THEN g.payer_flag ELSE 0 END)
    / NULLIF(SUM(g.targeted_flag),0) AS targeted_account_payer_conversion,
  SUM(CASE WHEN g.targeted_flag = 1 THEN g.successful_recovery ELSE 0 END)
    / NULLIF(SUM(CASE WHEN g.targeted_flag = 1 THEN g.outstanding_amount ELSE 0 END),0)
    AS targeted_balance_recovery_proxy,

  SUM(g.answered_outbound_calls) / NULLIF(SUM(g.outbound_calls),0) AS contact_rate,

  SUM(g.ptp_count) / NULLIF(SUM(g.targeted_flag),0) AS ptp_per_targeted_account,
  SUM(g.ptp_kept) / NULLIF(SUM(g.ptp_kept + g.ptp_broken),0) AS ptp_kept_rate,

  ah.agent_hours,
  SUM(g.successful_recovery) / NULLIF(ah.agent_hours,0) AS recovery_per_agent_hour,

  CAST(NULL AS DECIMAL(18,6)) AS rpc_rate,
  'UNRELIABLE: disposition-to-call account linkage fails DQ checks' AS rpc_metric_status,
  CAST(NULL AS DECIMAL(18,6)) AS cost_per_rupee_recovered,
  'UNAVAILABLE: no reliable cost table supplied' AS cost_metric_status,

  SUM(g.complaint_count) AS complaints,
  SUM(g.severe_complaint_count) AS severe_complaints
FROM golden_account_month g
LEFT JOIN agent_hours ah ON ah.month_start = g.month_start
GROUP BY g.month_start, ah.agent_hours;

-- ============================================================
-- 7-DAY NON-EXCLUSIVE CHANNEL CONVERSION
-- This is descriptive attribution, not causal attribution.
-- ============================================================

CREATE OR REPLACE VIEW interaction_account_day AS
SELECT DISTINCT account_id, event_date_ist AS interaction_date, 'VOICE' AS channel
FROM clean_calls
WHERE call_status = 'ANSWERED' AND event_date_ist IS NOT NULL
UNION
SELECT DISTINCT account_id, event_date_ist, 'WHATSAPP'
FROM clean_whatsapp_events
WHERE event_type IN ('READ','REPLIED','PAYMENT_CLICK') AND event_date_ist IS NOT NULL
UNION
SELECT DISTINCT account_id, event_date_ist, 'SMS'
FROM clean_sms_events
WHERE event_type IN ('DELIVERED','CLICKED') AND event_date_ist IS NOT NULL
UNION
SELECT DISTINCT account_id, event_date_ist, 'FIELD'
FROM clean_field_visits
WHERE outcome IN ('CONTACTED','PTP','PAID') AND event_date_ist IS NOT NULL;

CREATE OR REPLACE VIEW mart_channel_conversion_7d AS
WITH success_payments AS (
  SELECT payment_id, account_id, event_date_ist, amount
  FROM clean_payments
  WHERE payment_status = 'SUCCESS' AND event_date_ist IS NOT NULL
), interaction_outcome AS (
  SELECT
    i.account_id,
    i.interaction_date,
    i.channel,
    MAX(CASE WHEN p.payment_id IS NOT NULL THEN 1 ELSE 0 END) AS converted_7d_flag,
    SUM(CASE WHEN p.payment_id IS NOT NULL THEN p.amount ELSE 0 END) AS nonexclusive_recovery_7d
  FROM interaction_account_day i
  LEFT JOIN success_payments p
    ON p.account_id = i.account_id
   AND p.event_date_ist BETWEEN i.interaction_date AND DATE_ADD(i.interaction_date, INTERVAL 7 DAY)
  GROUP BY i.account_id, i.interaction_date, i.channel
)
SELECT
  CAST(DATE_FORMAT(interaction_date,'%Y-%m-01') AS DATE) AS month_start,
  channel,
  COUNT(*) AS account_interaction_days,
  SUM(converted_7d_flag) AS converted_account_interaction_days,
  SUM(converted_7d_flag) / NULLIF(COUNT(*),0) AS conversion_7d,
  SUM(nonexclusive_recovery_7d) AS nonexclusive_recovery_7d,
  'DESCRIPTIVE / NON-EXCLUSIVE' AS attribution_status
FROM interaction_outcome
GROUP BY CAST(DATE_FORMAT(interaction_date,'%Y-%m-01') AS DATE), channel;

-- ============================================================
-- VENDOR / CALLING-TIME PERFORMANCE
-- ============================================================

CREATE OR REPLACE VIEW mart_vendor_calling AS
SELECT
  c.month_start,
  c.vendor_id,
  v.vendor_name,
  COUNT(*) AS calls,
  SUM(c.direction = 'OUTBOUND') AS outbound_calls,
  SUM(c.direction = 'OUTBOUND' AND c.call_status = 'ANSWERED') AS answered_outbound_calls,
  SUM(c.direction = 'OUTBOUND' AND c.call_status = 'ANSWERED')
    / NULLIF(SUM(c.direction = 'OUTBOUND'),0) AS contact_rate,
  AVG(c.duration_sec) AS avg_duration_sec
FROM clean_calls c
LEFT JOIN clean_vendors v ON c.vendor_id = v.vendor_id
GROUP BY c.month_start, c.vendor_id, v.vendor_name;

CREATE OR REPLACE VIEW mart_calling_hour AS
SELECT
  month_start,
  HOUR(event_at_ist) AS hour_ist,
  COUNT(*) AS calls,
  SUM(direction = 'OUTBOUND') AS outbound_calls,
  SUM(direction = 'OUTBOUND' AND call_status = 'ANSWERED') AS answered_outbound_calls,
  SUM(direction = 'OUTBOUND' AND call_status = 'ANSWERED')
    / NULLIF(SUM(direction = 'OUTBOUND'),0) AS contact_rate
FROM clean_calls
WHERE event_at_ist IS NOT NULL
GROUP BY month_start, HOUR(event_at_ist);

-- ============================================================
-- AGENT / TENURE PERFORMANCE
-- Agent identity is explicitly quality-flagged because the master conflicts.
-- ============================================================

CREATE OR REPLACE VIEW mart_agent_calling AS
SELECT
  c.month_start,
  c.agent_id,
  a.employee_code,
  a.agent_name,
  a.team,
  a.vendor_id AS master_vendor_id,
  a.joined_at,
  a.agent_conflict_flag,
  CASE
    WHEN a.joined_at IS NULL THEN 'UNKNOWN'
    WHEN TIMESTAMPDIFF(MONTH, a.joined_at, c.event_at_ist) < 3 THEN '<3M'
    WHEN TIMESTAMPDIFF(MONTH, a.joined_at, c.event_at_ist) < 6 THEN '3-5M'
    WHEN TIMESTAMPDIFF(MONTH, a.joined_at, c.event_at_ist) < 12 THEN '6-11M'
    ELSE '12M+'
  END AS tenure_bucket,
  COUNT(*) AS calls,
  SUM(c.direction = 'OUTBOUND') AS outbound_calls,
  SUM(c.direction = 'OUTBOUND' AND c.call_status = 'ANSWERED') AS answered_outbound_calls,
  SUM(c.direction = 'OUTBOUND' AND c.call_status = 'ANSWERED')
    / NULLIF(SUM(c.direction = 'OUTBOUND'),0) AS contact_rate
FROM clean_calls c
LEFT JOIN clean_agents a ON c.agent_id = a.agent_id
GROUP BY
  c.month_start, c.agent_id, a.employee_code, a.agent_name, a.team,
  a.vendor_id, a.joined_at, a.agent_conflict_flag,
  CASE
    WHEN a.joined_at IS NULL THEN 'UNKNOWN'
    WHEN TIMESTAMPDIFF(MONTH, a.joined_at, c.event_at_ist) < 3 THEN '<3M'
    WHEN TIMESTAMPDIFF(MONTH, a.joined_at, c.event_at_ist) < 6 THEN '3-5M'
    WHEN TIMESTAMPDIFF(MONTH, a.joined_at, c.event_at_ist) < 12 THEN '6-11M'
    ELSE '12M+'
  END;

-- ============================================================
-- ATTEMPT FREQUENCY
-- Uses clean call count rather than call_attempt records because the latter's
-- call-account linkage fails integrity checks.
-- ============================================================

CREATE OR REPLACE VIEW mart_attempt_frequency AS
SELECT
  month_start,
  CASE
    WHEN calls_total = 0 THEN '0'
    WHEN calls_total = 1 THEN '1'
    WHEN calls_total = 2 THEN '2'
    WHEN calls_total BETWEEN 3 AND 5 THEN '3-5'
    WHEN calls_total BETWEEN 6 AND 10 THEN '6-10'
    ELSE '11+'
  END AS monthly_call_frequency_bucket,
  COUNT(*) AS accounts,
  AVG(payer_flag) AS payer_rate,
  AVG(successful_recovery) AS recovery_per_account,
  AVG(complaint_count > 0) AS complaint_account_rate
FROM golden_account_month
GROUP BY month_start,
  CASE
    WHEN calls_total = 0 THEN '0'
    WHEN calls_total = 1 THEN '1'
    WHEN calls_total = 2 THEN '2'
    WHEN calls_total BETWEEN 3 AND 5 THEN '3-5'
    WHEN calls_total BETWEEN 6 AND 10 THEN '6-10'
    ELSE '11+'
  END;
