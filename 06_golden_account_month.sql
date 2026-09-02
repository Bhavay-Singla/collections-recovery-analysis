USE collections_analytics;

-- ============================================================
-- GOLDEN ANALYTICAL LAYER
-- Grain: one row per account x observed month.
-- This keeps denominators stable and lets recovery, targeting and
-- operational activity be analyzed from a single reproducible view.
-- ============================================================

CREATE OR REPLACE VIEW data_horizon AS
SELECT MAX(event_date) AS observed_through
FROM (
  SELECT target_date AS event_date FROM clean_targeting
  UNION ALL SELECT event_date_ist FROM clean_payments
  UNION ALL SELECT event_date_ist FROM clean_calls
  UNION ALL SELECT event_date_ist FROM clean_whatsapp_events
  UNION ALL SELECT event_date_ist FROM clean_sms_events
  UNION ALL SELECT event_date_ist FROM clean_field_visits
  UNION ALL SELECT event_date_ist FROM clean_promises_to_pay
  UNION ALL SELECT event_date_ist FROM clean_complaints
) u
WHERE event_date IS NOT NULL;

CREATE OR REPLACE VIEW golden_account_month AS
WITH months AS (
  SELECT DISTINCT month_start FROM (
    SELECT month_start FROM clean_targeting
    UNION ALL SELECT month_start FROM clean_payments
    UNION ALL SELECT month_start FROM clean_calls
    UNION ALL SELECT month_start FROM clean_whatsapp_events
    UNION ALL SELECT month_start FROM clean_sms_events
    UNION ALL SELECT month_start FROM clean_field_visits
    UNION ALL SELECT month_start FROM clean_promises_to_pay
    UNION ALL SELECT month_start FROM clean_complaints
  ) m
  WHERE month_start IS NOT NULL
),
targeting AS (
  SELECT
    account_id, month_start,
    COUNT(*) AS target_rows,
    COUNT(DISTINCT target_date) AS targeted_days,
    COUNT(DISTINCT campaign_id) AS campaigns_targeted,
    MAX(priority) AS max_priority,
    SUM(campaign_window_valid_flag = 1) AS valid_campaign_window_rows,
    SUM(campaign_window_valid_flag = 0) AS invalid_campaign_window_rows,
    SUM(static_target_rule_match_flag = 1) AS static_rule_match_rows,
    SUM(static_target_rule_match_flag = 0) AS static_rule_mismatch_rows,
    MAX(recommended_channel = 'VOICE') AS recommended_voice_flag,
    MAX(recommended_channel = 'WHATSAPP') AS recommended_whatsapp_flag,
    MAX(recommended_channel = 'SMS') AS recommended_sms_flag,
    MAX(recommended_channel = 'FIELD') AS recommended_field_flag
  FROM clean_targeting
  GROUP BY account_id, month_start
),
calls AS (
  SELECT
    account_id, month_start,
    COUNT(*) AS calls_total,
    SUM(direction = 'OUTBOUND') AS outbound_calls,
    SUM(direction = 'INBOUND') AS inbound_calls,
    SUM(call_status = 'ANSWERED') AS answered_calls,
    SUM(direction = 'OUTBOUND' AND call_status = 'ANSWERED') AS answered_outbound_calls,
    SUM(duration_sec) / 60.0 AS call_minutes,
    COUNT(DISTINCT agent_id) AS calling_agents,
    COUNT(DISTINCT vendor_id) AS calling_vendors
  FROM clean_calls
  GROUP BY account_id, month_start
),
wa AS (
  SELECT
    account_id, month_start,
    COUNT(*) AS whatsapp_events,
    COUNT(DISTINCT message_id) AS whatsapp_messages,
    SUM(event_type = 'SENT') AS whatsapp_sent,
    SUM(event_type = 'DELIVERED') AS whatsapp_delivered,
    SUM(event_type = 'READ') AS whatsapp_read,
    SUM(event_type = 'REPLIED') AS whatsapp_replied,
    SUM(event_type = 'PAYMENT_CLICK') AS whatsapp_payment_clicks,
    SUM(event_type = 'FAILED') AS whatsapp_failed
  FROM clean_whatsapp_events
  GROUP BY account_id, month_start
),
sms AS (
  SELECT
    account_id, month_start,
    COUNT(*) AS sms_events,
    COUNT(DISTINCT message_id) AS sms_messages,
    SUM(event_type = 'SENT') AS sms_sent,
    SUM(event_type = 'DELIVERED') AS sms_delivered,
    SUM(event_type = 'CLICKED') AS sms_clicked,
    SUM(event_type = 'FAILED') AS sms_failed
  FROM clean_sms_events
  GROUP BY account_id, month_start
),
field AS (
  SELECT
    account_id, month_start,
    COUNT(*) AS field_visits,
    SUM(outcome = 'CONTACTED') AS field_contacted,
    SUM(outcome = 'PTP') AS field_ptp,
    SUM(outcome = 'PAID') AS field_paid,
    SUM(outcome = 'WRONG_ADDRESS') AS field_wrong_address
  FROM clean_field_visits
  GROUP BY account_id, month_start
),
ptp AS (
  SELECT
    account_id, month_start,
    COUNT(*) AS ptp_count,
    SUM(status = 'KEPT') AS ptp_kept,
    SUM(status = 'BROKEN') AS ptp_broken,
    SUM(status = 'OPEN') AS ptp_open,
    SUM(status = 'CANCELLED') AS ptp_cancelled,
    SUM(promised_amount) AS promised_amount
  FROM clean_promises_to_pay
  GROUP BY account_id, month_start
),
pay AS (
  SELECT
    account_id, month_start,
    COUNT(*) AS payment_events,
    SUM(payment_status = 'SUCCESS') AS successful_payment_count,
    SUM(CASE WHEN payment_status = 'SUCCESS' THEN amount ELSE 0 END) AS successful_recovery,
    SUM(payment_status = 'FAILED') AS failed_payment_count,
    SUM(payment_status = 'PENDING') AS pending_payment_count,
    SUM(payment_status = 'REVERSED') AS reversed_payment_count,
    MAX(payment_status = 'SUCCESS') AS payer_flag
  FROM clean_payments
  GROUP BY account_id, month_start
),
complaints AS (
  SELECT
    account_id, month_start,
    COUNT(*) AS complaint_count,
    SUM(severity IN ('HIGH','CRITICAL')) AS severe_complaint_count,
    SUM(status IN ('OPEN','INVESTIGATING')) AS unresolved_complaint_count
  FROM clean_complaints
  GROUP BY account_id, month_start
)
SELECT
  m.month_start,
  a.account_id,
  a.borrower_id,
  a.loan_type,
  a.principal_amount,
  a.outstanding_amount,
  a.dpd,
  a.dpd_bucket,
  a.risk_segment,
  a.account_status,
  a.account_timezone,
  a.city,
  a.state,
  a.borrower_conflict_flag,
  CASE WHEN LAST_DAY(m.month_start) <= h.observed_through THEN 1 ELSE 0 END AS is_complete_month,
  h.observed_through,

  CASE WHEN COALESCE(t.target_rows,0) > 0 THEN 1 ELSE 0 END AS targeted_flag,
  COALESCE(t.target_rows,0) AS target_rows,
  COALESCE(t.targeted_days,0) AS targeted_days,
  COALESCE(t.campaigns_targeted,0) AS campaigns_targeted,
  t.max_priority,
  COALESCE(t.valid_campaign_window_rows,0) AS valid_campaign_window_rows,
  COALESCE(t.invalid_campaign_window_rows,0) AS invalid_campaign_window_rows,
  COALESCE(t.static_rule_match_rows,0) AS static_rule_match_rows,
  COALESCE(t.static_rule_mismatch_rows,0) AS static_rule_mismatch_rows,
  COALESCE(t.recommended_voice_flag,0) AS recommended_voice_flag,
  COALESCE(t.recommended_whatsapp_flag,0) AS recommended_whatsapp_flag,
  COALESCE(t.recommended_sms_flag,0) AS recommended_sms_flag,
  COALESCE(t.recommended_field_flag,0) AS recommended_field_flag,

  COALESCE(c.calls_total,0) AS calls_total,
  COALESCE(c.outbound_calls,0) AS outbound_calls,
  COALESCE(c.inbound_calls,0) AS inbound_calls,
  COALESCE(c.answered_calls,0) AS answered_calls,
  COALESCE(c.answered_outbound_calls,0) AS answered_outbound_calls,
  COALESCE(c.call_minutes,0) AS call_minutes,
  COALESCE(c.calling_agents,0) AS calling_agents,
  COALESCE(c.calling_vendors,0) AS calling_vendors,

  COALESCE(w.whatsapp_events,0) AS whatsapp_events,
  COALESCE(w.whatsapp_messages,0) AS whatsapp_messages,
  COALESCE(w.whatsapp_sent,0) AS whatsapp_sent,
  COALESCE(w.whatsapp_delivered,0) AS whatsapp_delivered,
  COALESCE(w.whatsapp_read,0) AS whatsapp_read,
  COALESCE(w.whatsapp_replied,0) AS whatsapp_replied,
  COALESCE(w.whatsapp_payment_clicks,0) AS whatsapp_payment_clicks,
  COALESCE(w.whatsapp_failed,0) AS whatsapp_failed,

  COALESCE(s.sms_events,0) AS sms_events,
  COALESCE(s.sms_messages,0) AS sms_messages,
  COALESCE(s.sms_sent,0) AS sms_sent,
  COALESCE(s.sms_delivered,0) AS sms_delivered,
  COALESCE(s.sms_clicked,0) AS sms_clicked,
  COALESCE(s.sms_failed,0) AS sms_failed,

  COALESCE(f.field_visits,0) AS field_visits,
  COALESCE(f.field_contacted,0) AS field_contacted,
  COALESCE(f.field_ptp,0) AS field_ptp,
  COALESCE(f.field_paid,0) AS field_paid,
  COALESCE(f.field_wrong_address,0) AS field_wrong_address,

  COALESCE(p.ptp_count,0) AS ptp_count,
  COALESCE(p.ptp_kept,0) AS ptp_kept,
  COALESCE(p.ptp_broken,0) AS ptp_broken,
  COALESCE(p.ptp_open,0) AS ptp_open,
  COALESCE(p.ptp_cancelled,0) AS ptp_cancelled,
  COALESCE(p.promised_amount,0) AS promised_amount,

  COALESCE(py.payment_events,0) AS payment_events,
  COALESCE(py.successful_payment_count,0) AS successful_payment_count,
  COALESCE(py.successful_recovery,0) AS successful_recovery,
  COALESCE(py.failed_payment_count,0) AS failed_payment_count,
  COALESCE(py.pending_payment_count,0) AS pending_payment_count,
  COALESCE(py.reversed_payment_count,0) AS reversed_payment_count,
  COALESCE(py.payer_flag,0) AS payer_flag,

  COALESCE(cp.complaint_count,0) AS complaint_count,
  COALESCE(cp.severe_complaint_count,0) AS severe_complaint_count,
  COALESCE(cp.unresolved_complaint_count,0) AS unresolved_complaint_count
FROM months m
CROSS JOIN dim_account a
CROSS JOIN data_horizon h
LEFT JOIN targeting t ON t.account_id = a.account_id AND t.month_start = m.month_start
LEFT JOIN calls c ON c.account_id = a.account_id AND c.month_start = m.month_start
LEFT JOIN wa w ON w.account_id = a.account_id AND w.month_start = m.month_start
LEFT JOIN sms s ON s.account_id = a.account_id AND s.month_start = m.month_start
LEFT JOIN field f ON f.account_id = a.account_id AND f.month_start = m.month_start
LEFT JOIN ptp p ON p.account_id = a.account_id AND p.month_start = m.month_start
LEFT JOIN pay py ON py.account_id = a.account_id AND py.month_start = m.month_start
LEFT JOIN complaints cp ON cp.account_id = a.account_id AND cp.month_start = m.month_start;
