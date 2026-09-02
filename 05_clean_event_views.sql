USE collections_analytics;

-- ============================================================
-- EVENT CLEANING
-- Canonical analytical timezone: Asia/Kolkata (IST)
-- For event tables with no timezone column, account timezone is used as a proxy.
-- ============================================================

-- ---------- Payments ----------
CREATE OR REPLACE VIEW dq_payment_id_critical_conflicts AS
SELECT payment_id
FROM stg_payments
WHERE payment_id IS NOT NULL
GROUP BY payment_id
HAVING COUNT(DISTINCT COALESCE(account_id,'<NULL>')) > 1
    OR COUNT(DISTINCT COALESCE(DATE_FORMAT(event_at,'%Y-%m-%d %H:%i:%s'),'<NULL>')) > 1
    OR COUNT(DISTINCT COALESCE(CAST(amount AS CHAR),'<NULL>')) > 1
    OR COUNT(DISTINCT COALESCE(payment_status,'<NULL>')) > 1
    OR COUNT(DISTINCT COALESCE(payment_method,'<NULL>')) > 1
    OR COUNT(DISTINCT COALESCE(provider_id,'<NULL>')) > 1;

CREATE OR REPLACE VIEW clean_payments AS
WITH ranked AS (
  SELECT
    p.*,
    ROW_NUMBER() OVER (
      PARTITION BY payment_id
      ORDER BY (payment_reference IS NOT NULL) DESC, _row_id DESC
    ) AS rn
  FROM stg_payments p
  WHERE payment_id IS NOT NULL
    AND NOT EXISTS (
      SELECT 1 FROM dq_payment_id_critical_conflicts q WHERE q.payment_id = p.payment_id
    )
)
SELECT
  r.payment_id,
  r.account_id,
  r.borrower_id AS source_borrower_id,
  a.borrower_id AS borrower_id,
  r.event_at AS event_at_raw,
  CASE a.timezone
    WHEN 'UTC' THEN DATE_ADD(r.event_at, INTERVAL 330 MINUTE)
    WHEN 'Asia/Kolkata' THEN r.event_at
    WHEN 'Asia/Dubai' THEN DATE_ADD(r.event_at, INTERVAL 90 MINUTE)
    ELSE NULL
  END AS event_at_ist,
  DATE(CASE a.timezone
    WHEN 'UTC' THEN DATE_ADD(r.event_at, INTERVAL 330 MINUTE)
    WHEN 'Asia/Kolkata' THEN r.event_at
    WHEN 'Asia/Dubai' THEN DATE_ADD(r.event_at, INTERVAL 90 MINUTE)
    ELSE NULL END) AS event_date_ist,
  CAST(DATE_FORMAT(CASE a.timezone
    WHEN 'UTC' THEN DATE_ADD(r.event_at, INTERVAL 330 MINUTE)
    WHEN 'Asia/Kolkata' THEN r.event_at
    WHEN 'Asia/Dubai' THEN DATE_ADD(r.event_at, INTERVAL 90 MINUTE)
    ELSE NULL END, '%Y-%m-01') AS DATE) AS month_start,
  a.timezone AS timezone_used,
  1 AS timezone_inferred_flag,
  r.payment_reference,
  r.amount,
  r.payment_status,
  r.payment_method,
  r.provider_id,
  CASE WHEN r.borrower_id = a.borrower_id THEN 0 ELSE 1 END AS borrower_id_mismatch_flag
FROM ranked r
JOIN clean_accounts a ON r.account_id = a.account_id
WHERE r.rn = 1;

-- ---------- Calls ----------
CREATE OR REPLACE VIEW dq_call_id_critical_conflicts AS
SELECT call_id
FROM stg_calls
WHERE call_id IS NOT NULL
GROUP BY call_id
HAVING COUNT(DISTINCT COALESCE(account_id,'<NULL>')) > 1
    OR COUNT(DISTINCT COALESCE(DATE_FORMAT(event_at,'%Y-%m-%d %H:%i:%s'),'<NULL>')) > 1
    OR COUNT(DISTINCT COALESCE(campaign_id,'<NULL>')) > 1
    OR COUNT(DISTINCT COALESCE(direction,'<NULL>')) > 1
    OR COUNT(DISTINCT COALESCE(vendor_id,'<NULL>')) > 1
    OR COUNT(DISTINCT COALESCE(call_status,'<NULL>')) > 1
    OR COUNT(DISTINCT COALESCE(CAST(duration_sec AS CHAR),'<NULL>')) > 1
    OR COUNT(DISTINCT COALESCE(timezone,'<NULL>')) > 1;

CREATE OR REPLACE VIEW clean_calls AS
WITH ranked AS (
  SELECT
    c.*,
    ROW_NUMBER() OVER (
      PARTITION BY call_id
      ORDER BY (agent_id IS NOT NULL) DESC, _row_id DESC
    ) AS rn
  FROM stg_calls c
  WHERE call_id IS NOT NULL
    AND NOT EXISTS (
      SELECT 1 FROM dq_call_id_critical_conflicts q WHERE q.call_id = c.call_id
    )
)
SELECT
  r.call_id,
  r.account_id,
  r.borrower_id AS source_borrower_id,
  a.borrower_id AS borrower_id,
  r.event_at AS event_at_raw,
  CASE r.timezone
    WHEN 'UTC' THEN DATE_ADD(r.event_at, INTERVAL 330 MINUTE)
    WHEN 'Asia/Kolkata' THEN r.event_at
    WHEN 'Asia/Dubai' THEN DATE_ADD(r.event_at, INTERVAL 90 MINUTE)
    ELSE NULL
  END AS event_at_ist,
  DATE(CASE r.timezone
    WHEN 'UTC' THEN DATE_ADD(r.event_at, INTERVAL 330 MINUTE)
    WHEN 'Asia/Kolkata' THEN r.event_at
    WHEN 'Asia/Dubai' THEN DATE_ADD(r.event_at, INTERVAL 90 MINUTE)
    ELSE NULL END) AS event_date_ist,
  CAST(DATE_FORMAT(CASE r.timezone
    WHEN 'UTC' THEN DATE_ADD(r.event_at, INTERVAL 330 MINUTE)
    WHEN 'Asia/Kolkata' THEN r.event_at
    WHEN 'Asia/Dubai' THEN DATE_ADD(r.event_at, INTERVAL 90 MINUTE)
    ELSE NULL END, '%Y-%m-01') AS DATE) AS month_start,
  r.agent_id,
  r.campaign_id,
  r.direction,
  r.vendor_id,
  r.call_status,
  r.duration_sec,
  r.timezone AS timezone_used,
  0 AS timezone_inferred_flag,
  CASE WHEN r.borrower_id = a.borrower_id THEN 0 ELSE 1 END AS borrower_id_mismatch_flag
FROM ranked r
JOIN clean_accounts a ON r.account_id = a.account_id
WHERE r.rn = 1;

-- ---------- Agent sessions ----------
CREATE OR REPLACE VIEW clean_agent_sessions AS
SELECT
  session_id,
  agent_id,
  login_at AS login_at_raw,
  logout_at AS logout_at_raw,
  CASE timezone
    WHEN 'UTC' THEN DATE_ADD(login_at, INTERVAL 330 MINUTE)
    WHEN 'Asia/Kolkata' THEN login_at
    ELSE NULL
  END AS login_at_ist,
  CASE timezone
    WHEN 'UTC' THEN DATE_ADD(logout_at, INTERVAL 330 MINUTE)
    WHEN 'Asia/Kolkata' THEN logout_at
    ELSE NULL
  END AS logout_at_ist,
  CAST(DATE_FORMAT(CASE timezone
    WHEN 'UTC' THEN DATE_ADD(login_at, INTERVAL 330 MINUTE)
    WHEN 'Asia/Kolkata' THEN login_at
    ELSE NULL END, '%Y-%m-01') AS DATE) AS month_start,
  channel,
  device_id,
  timezone,
  CASE
    WHEN logout_at >= login_at THEN TIMESTAMPDIFF(SECOND, login_at, logout_at) / 3600.0
    ELSE NULL
  END AS session_hours
FROM stg_agent_sessions;

-- ---------- Targeting ----------
CREATE OR REPLACE VIEW clean_targeting AS
SELECT
  t.target_id,
  t.account_id,
  a.borrower_id,
  t.campaign_id,
  t.target_date,
  CAST(DATE_FORMAT(t.target_date, '%Y-%m-01') AS DATE) AS month_start,
  t.priority,
  t.recommended_channel,
  t.status AS targeting_status,
  c.campaign_name,
  c.channel AS campaign_channel,
  c.strategy_version,
  c.start_at AS campaign_start_at,
  c.end_at AS campaign_end_at,
  c.target_definition,
  CASE
    WHEN t.target_date BETWEEN DATE(c.start_at) AND DATE(c.end_at) THEN 1 ELSE 0
  END AS campaign_window_valid_flag,
  CASE
    WHEN c.target_definition = 'DPD>=30' THEN (a.dpd >= 30)
    WHEN c.target_definition = 'DPD>=60' THEN (a.dpd >= 60)
    WHEN c.target_definition = 'HIGH_RISK' THEN (a.risk_segment = 'HIGH')
    WHEN c.target_definition = 'NPA' THEN (a.risk_segment = 'NPA')
    ELSE NULL
  END AS static_target_rule_match_flag
FROM stg_daily_targeting t
JOIN clean_accounts a ON t.account_id = a.account_id
LEFT JOIN clean_campaigns c ON t.campaign_id = c.campaign_id;

-- ---------- WhatsApp ----------
CREATE OR REPLACE VIEW dq_whatsapp_id_critical_conflicts AS
SELECT whatsapp_event_id
FROM stg_whatsapp_events
WHERE whatsapp_event_id IS NOT NULL
GROUP BY whatsapp_event_id
HAVING COUNT(DISTINCT COALESCE(account_id,'<NULL>')) > 1
    OR COUNT(DISTINCT COALESCE(DATE_FORMAT(event_at,'%Y-%m-%d %H:%i:%s'),'<NULL>')) > 1
    OR COUNT(DISTINCT COALESCE(message_id,'<NULL>')) > 1
    OR COUNT(DISTINCT COALESCE(event_type,'<NULL>')) > 1
    OR COUNT(DISTINCT COALESCE(template_code,'<NULL>')) > 1
    OR COUNT(DISTINCT COALESCE(provider_id,'<NULL>')) > 1;

CREATE OR REPLACE VIEW clean_whatsapp_events AS
WITH ranked AS (
  SELECT w.*,
         ROW_NUMBER() OVER (PARTITION BY whatsapp_event_id ORDER BY _row_id DESC) AS rn
  FROM stg_whatsapp_events w
  WHERE whatsapp_event_id IS NOT NULL
    AND NOT EXISTS (
      SELECT 1 FROM dq_whatsapp_id_critical_conflicts q
      WHERE q.whatsapp_event_id = w.whatsapp_event_id
    )
)
SELECT
  r.whatsapp_event_id,
  r.account_id,
  r.borrower_id AS source_borrower_id,
  a.borrower_id AS borrower_id,
  r.event_at AS event_at_raw,
  CASE a.timezone
    WHEN 'UTC' THEN DATE_ADD(r.event_at, INTERVAL 330 MINUTE)
    WHEN 'Asia/Kolkata' THEN r.event_at
    WHEN 'Asia/Dubai' THEN DATE_ADD(r.event_at, INTERVAL 90 MINUTE)
    ELSE NULL
  END AS event_at_ist,
  DATE(CASE a.timezone
    WHEN 'UTC' THEN DATE_ADD(r.event_at, INTERVAL 330 MINUTE)
    WHEN 'Asia/Kolkata' THEN r.event_at
    WHEN 'Asia/Dubai' THEN DATE_ADD(r.event_at, INTERVAL 90 MINUTE)
    ELSE NULL END) AS event_date_ist,
  CAST(DATE_FORMAT(CASE a.timezone
    WHEN 'UTC' THEN DATE_ADD(r.event_at, INTERVAL 330 MINUTE)
    WHEN 'Asia/Kolkata' THEN r.event_at
    WHEN 'Asia/Dubai' THEN DATE_ADD(r.event_at, INTERVAL 90 MINUTE)
    ELSE NULL END, '%Y-%m-01') AS DATE) AS month_start,
  r.message_id,
  r.event_type,
  r.template_code,
  r.provider_id,
  a.timezone AS timezone_used,
  1 AS timezone_inferred_flag,
  CASE WHEN r.borrower_id = a.borrower_id THEN 0 ELSE 1 END AS borrower_id_mismatch_flag
FROM ranked r
JOIN clean_accounts a ON r.account_id = a.account_id
WHERE r.rn = 1;

-- ---------- SMS ----------
CREATE OR REPLACE VIEW clean_sms_events AS
SELECT
  s.sms_event_id,
  s.account_id,
  s.borrower_id AS source_borrower_id,
  a.borrower_id AS borrower_id,
  s.event_at AS event_at_raw,
  CASE a.timezone
    WHEN 'UTC' THEN DATE_ADD(s.event_at, INTERVAL 330 MINUTE)
    WHEN 'Asia/Kolkata' THEN s.event_at
    WHEN 'Asia/Dubai' THEN DATE_ADD(s.event_at, INTERVAL 90 MINUTE)
    ELSE NULL
  END AS event_at_ist,
  DATE(CASE a.timezone
    WHEN 'UTC' THEN DATE_ADD(s.event_at, INTERVAL 330 MINUTE)
    WHEN 'Asia/Kolkata' THEN s.event_at
    WHEN 'Asia/Dubai' THEN DATE_ADD(s.event_at, INTERVAL 90 MINUTE)
    ELSE NULL END) AS event_date_ist,
  CAST(DATE_FORMAT(CASE a.timezone
    WHEN 'UTC' THEN DATE_ADD(s.event_at, INTERVAL 330 MINUTE)
    WHEN 'Asia/Kolkata' THEN s.event_at
    WHEN 'Asia/Dubai' THEN DATE_ADD(s.event_at, INTERVAL 90 MINUTE)
    ELSE NULL END, '%Y-%m-01') AS DATE) AS month_start,
  s.message_id,
  s.event_type,
  s.template_code,
  s.provider_id,
  a.timezone AS timezone_used,
  1 AS timezone_inferred_flag,
  CASE WHEN s.borrower_id = a.borrower_id THEN 0 ELSE 1 END AS borrower_id_mismatch_flag
FROM stg_sms_events s
JOIN clean_accounts a ON s.account_id = a.account_id;

-- ---------- Field visits ----------
CREATE OR REPLACE VIEW clean_field_visits AS
SELECT
  f.visit_id,
  f.account_id,
  f.borrower_id AS source_borrower_id,
  a.borrower_id AS borrower_id,
  f.event_at AS event_at_raw,
  CASE a.timezone
    WHEN 'UTC' THEN DATE_ADD(f.event_at, INTERVAL 330 MINUTE)
    WHEN 'Asia/Kolkata' THEN f.event_at
    WHEN 'Asia/Dubai' THEN DATE_ADD(f.event_at, INTERVAL 90 MINUTE)
    ELSE NULL
  END AS event_at_ist,
  DATE(CASE a.timezone
    WHEN 'UTC' THEN DATE_ADD(f.event_at, INTERVAL 330 MINUTE)
    WHEN 'Asia/Kolkata' THEN f.event_at
    WHEN 'Asia/Dubai' THEN DATE_ADD(f.event_at, INTERVAL 90 MINUTE)
    ELSE NULL END) AS event_date_ist,
  CAST(DATE_FORMAT(CASE a.timezone
    WHEN 'UTC' THEN DATE_ADD(f.event_at, INTERVAL 330 MINUTE)
    WHEN 'Asia/Kolkata' THEN f.event_at
    WHEN 'Asia/Dubai' THEN DATE_ADD(f.event_at, INTERVAL 90 MINUTE)
    ELSE NULL END, '%Y-%m-01') AS DATE) AS month_start,
  f.agent_id,
  f.visit_type,
  f.outcome,
  f.latitude,
  f.longitude,
  f.scheduled_at,
  a.timezone AS timezone_used,
  1 AS timezone_inferred_flag,
  CASE WHEN f.borrower_id = a.borrower_id THEN 0 ELSE 1 END AS borrower_id_mismatch_flag
FROM stg_field_visits f
JOIN clean_accounts a ON f.account_id = a.account_id;

-- ---------- Promises to pay ----------
CREATE OR REPLACE VIEW clean_promises_to_pay AS
SELECT
  p.ptp_id,
  p.account_id,
  p.borrower_id AS source_borrower_id,
  a.borrower_id AS borrower_id,
  p.event_at AS event_at_raw,
  CASE a.timezone
    WHEN 'UTC' THEN DATE_ADD(p.event_at, INTERVAL 330 MINUTE)
    WHEN 'Asia/Kolkata' THEN p.event_at
    WHEN 'Asia/Dubai' THEN DATE_ADD(p.event_at, INTERVAL 90 MINUTE)
    ELSE NULL
  END AS event_at_ist,
  DATE(CASE a.timezone
    WHEN 'UTC' THEN DATE_ADD(p.event_at, INTERVAL 330 MINUTE)
    WHEN 'Asia/Kolkata' THEN p.event_at
    WHEN 'Asia/Dubai' THEN DATE_ADD(p.event_at, INTERVAL 90 MINUTE)
    ELSE NULL END) AS event_date_ist,
  CAST(DATE_FORMAT(CASE a.timezone
    WHEN 'UTC' THEN DATE_ADD(p.event_at, INTERVAL 330 MINUTE)
    WHEN 'Asia/Kolkata' THEN p.event_at
    WHEN 'Asia/Dubai' THEN DATE_ADD(p.event_at, INTERVAL 90 MINUTE)
    ELSE NULL END, '%Y-%m-01') AS DATE) AS month_start,
  p.agent_id,
  p.promised_amount,
  p.promised_date,
  p.status,
  p.source,
  a.timezone AS timezone_used,
  1 AS timezone_inferred_flag,
  CASE WHEN p.borrower_id = a.borrower_id THEN 0 ELSE 1 END AS borrower_id_mismatch_flag
FROM stg_promises_to_pay p
JOIN clean_accounts a ON p.account_id = a.account_id;

-- ---------- Complaints ----------
CREATE OR REPLACE VIEW clean_complaints AS
SELECT
  c.complaint_id,
  c.account_id,
  c.borrower_id AS source_borrower_id,
  a.borrower_id AS borrower_id,
  c.event_at AS event_at_raw,
  CASE a.timezone
    WHEN 'UTC' THEN DATE_ADD(c.event_at, INTERVAL 330 MINUTE)
    WHEN 'Asia/Kolkata' THEN c.event_at
    WHEN 'Asia/Dubai' THEN DATE_ADD(c.event_at, INTERVAL 90 MINUTE)
    ELSE NULL
  END AS event_at_ist,
  DATE(CASE a.timezone
    WHEN 'UTC' THEN DATE_ADD(c.event_at, INTERVAL 330 MINUTE)
    WHEN 'Asia/Kolkata' THEN c.event_at
    WHEN 'Asia/Dubai' THEN DATE_ADD(c.event_at, INTERVAL 90 MINUTE)
    ELSE NULL END) AS event_date_ist,
  CAST(DATE_FORMAT(CASE a.timezone
    WHEN 'UTC' THEN DATE_ADD(c.event_at, INTERVAL 330 MINUTE)
    WHEN 'Asia/Kolkata' THEN c.event_at
    WHEN 'Asia/Dubai' THEN DATE_ADD(c.event_at, INTERVAL 90 MINUTE)
    ELSE NULL END, '%Y-%m-01') AS DATE) AS month_start,
  c.complaint_type,
  c.severity,
  c.status,
  c.source,
  c.resolution_at,
  a.timezone AS timezone_used,
  1 AS timezone_inferred_flag,
  CASE WHEN c.borrower_id = a.borrower_id THEN 0 ELSE 1 END AS borrower_id_mismatch_flag
FROM stg_complaints c
JOIN clean_accounts a ON c.account_id = a.account_id;

-- ---------- Account status history ----------
CREATE OR REPLACE VIEW clean_account_status_history AS
SELECT
  h.history_id,
  h.account_id,
  h.borrower_id AS source_borrower_id,
  a.borrower_id AS borrower_id,
  h.event_at AS event_at_raw,
  CASE a.timezone
    WHEN 'UTC' THEN DATE_ADD(h.event_at, INTERVAL 330 MINUTE)
    WHEN 'Asia/Kolkata' THEN h.event_at
    WHEN 'Asia/Dubai' THEN DATE_ADD(h.event_at, INTERVAL 90 MINUTE)
    ELSE NULL
  END AS event_at_ist,
  h.status,
  h.changed_by,
  h.source,
  h.recorded_at,
  a.timezone AS timezone_used,
  1 AS timezone_inferred_flag,
  CASE WHEN h.borrower_id = a.borrower_id THEN 0 ELSE 1 END AS borrower_id_mismatch_flag,
  CASE WHEN h.recorded_at < h.event_at THEN 1 ELSE 0 END AS recorded_before_event_flag
FROM stg_account_status_history h
JOIN clean_accounts a ON h.account_id = a.account_id;

-- ---------- Call attempts ----------
CREATE OR REPLACE VIEW clean_call_attempts AS
SELECT
  x.attempt_id,
  x.account_id,
  x.borrower_id AS source_borrower_id,
  a.borrower_id AS borrower_id,
  x.event_at AS event_at_raw,
  CASE a.timezone
    WHEN 'UTC' THEN DATE_ADD(x.event_at, INTERVAL 330 MINUTE)
    WHEN 'Asia/Kolkata' THEN x.event_at
    WHEN 'Asia/Dubai' THEN DATE_ADD(x.event_at, INTERVAL 90 MINUTE)
    ELSE NULL
  END AS event_at_ist,
  DATE(CASE a.timezone
    WHEN 'UTC' THEN DATE_ADD(x.event_at, INTERVAL 330 MINUTE)
    WHEN 'Asia/Kolkata' THEN x.event_at
    WHEN 'Asia/Dubai' THEN DATE_ADD(x.event_at, INTERVAL 90 MINUTE)
    ELSE NULL END) AS event_date_ist,
  CAST(DATE_FORMAT(CASE a.timezone
    WHEN 'UTC' THEN DATE_ADD(x.event_at, INTERVAL 330 MINUTE)
    WHEN 'Asia/Kolkata' THEN x.event_at
    WHEN 'Asia/Dubai' THEN DATE_ADD(x.event_at, INTERVAL 90 MINUTE)
    ELSE NULL END, '%Y-%m-01') AS DATE) AS month_start,
  x.call_id,
  x.agent_id,
  x.attempt_no,
  x.vendor_id,
  x.attempt_status,
  CASE WHEN c.call_id IS NOT NULL AND c.account_id = x.account_id THEN 1 ELSE 0 END AS call_link_valid_flag,
  CASE WHEN x.borrower_id = a.borrower_id THEN 0 ELSE 1 END AS borrower_id_mismatch_flag
FROM stg_call_attempts x
JOIN clean_accounts a ON x.account_id = a.account_id
LEFT JOIN clean_calls c ON x.call_id = c.call_id;

-- ---------- Call dispositions ----------
CREATE OR REPLACE VIEW clean_call_dispositions AS
SELECT
  d.disposition_id,
  d.account_id,
  d.borrower_id AS source_borrower_id,
  a.borrower_id AS borrower_id,
  d.event_at AS event_at_raw,
  CASE a.timezone
    WHEN 'UTC' THEN DATE_ADD(d.event_at, INTERVAL 330 MINUTE)
    WHEN 'Asia/Kolkata' THEN d.event_at
    WHEN 'Asia/Dubai' THEN DATE_ADD(d.event_at, INTERVAL 90 MINUTE)
    ELSE NULL
  END AS event_at_ist,
  d.call_id,
  d.agent_id,
  d.disposition_code AS source_disposition_code,
  CASE
    WHEN d.disposition_code IN ('PTP','PROMISE_TO_PAY') THEN 'PTP'
    ELSE d.disposition_code
  END AS normalized_disposition_code,
  d.disposition_version,
  CASE WHEN c.call_id IS NOT NULL AND c.account_id = d.account_id THEN 1 ELSE 0 END AS call_link_valid_flag,
  CASE WHEN d.borrower_id = a.borrower_id THEN 0 ELSE 1 END AS borrower_id_mismatch_flag
FROM stg_call_dispositions d
JOIN clean_accounts a ON d.account_id = a.account_id
LEFT JOIN clean_calls c ON d.call_id = c.call_id;
