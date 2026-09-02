USE collections_analytics;

-- Staging = typed, trimmed, source-faithful. No business correction yet.

CREATE OR REPLACE VIEW stg_borrowers AS
SELECT
  _row_id,
  NULLIF(TRIM(borrower_id),'') AS borrower_id,
  NULLIF(TRIM(name),'') AS name,
  NULLIF(TRIM(phone),'') AS phone,
  NULLIF(TRIM(email),'') AS email,
  NULLIF(TRIM(city),'') AS city,
  STR_TO_DATE(NULLIF(TRIM(created_at),''), '%Y-%m-%d %H:%i:%s') AS created_at,
  STR_TO_DATE(NULLIF(TRIM(updated_at),''), '%Y-%m-%d %H:%i:%s') AS updated_at,
  NULLIF(TRIM(state),'') AS state
FROM raw_borrowers;

CREATE OR REPLACE VIEW stg_accounts AS
SELECT
  _row_id,
  NULLIF(TRIM(account_id),'') AS account_id,
  NULLIF(TRIM(borrower_id),'') AS borrower_id,
  NULLIF(TRIM(loan_type),'') AS loan_type,
  CAST(NULLIF(TRIM(principal_amount),'') AS DECIMAL(18,2)) AS principal_amount,
  CAST(NULLIF(TRIM(outstanding_amount),'') AS DECIMAL(18,2)) AS outstanding_amount,
  CAST(NULLIF(TRIM(dpd),'') AS SIGNED) AS dpd,
  NULLIF(TRIM(risk_segment),'') AS risk_segment,
  NULLIF(TRIM(status),'') AS status,
  STR_TO_DATE(NULLIF(TRIM(opened_at),''), '%Y-%m-%d %H:%i:%s') AS opened_at,
  NULLIF(TRIM(timezone),'') AS timezone,
  NULLIF(TRIM(schema_version),'') AS schema_version
FROM raw_accounts;

CREATE OR REPLACE VIEW stg_agents AS
SELECT
  _row_id,
  NULLIF(TRIM(agent_id),'') AS agent_id,
  NULLIF(TRIM(employee_code),'') AS employee_code,
  NULLIF(TRIM(agent_name),'') AS agent_name,
  NULLIF(TRIM(vendor_id),'') AS vendor_id,
  NULLIF(TRIM(team),'') AS team,
  NULLIF(TRIM(status),'') AS status,
  STR_TO_DATE(NULLIF(TRIM(joined_at),''), '%Y-%m-%d %H:%i:%s') AS joined_at,
  STR_TO_DATE(NULLIF(TRIM(updated_at),''), '%Y-%m-%d %H:%i:%s') AS updated_at
FROM raw_agents;

CREATE OR REPLACE VIEW stg_agent_sessions AS
SELECT
  _row_id,
  NULLIF(TRIM(session_id),'') AS session_id,
  NULLIF(TRIM(agent_id),'') AS agent_id,
  STR_TO_DATE(NULLIF(TRIM(login_at),''), '%Y-%m-%d %H:%i:%s') AS login_at,
  NULLIF(TRIM(channel),'') AS channel,
  NULLIF(TRIM(device_id),'') AS device_id,
  NULLIF(TRIM(timezone),'') AS timezone,
  STR_TO_DATE(NULLIF(TRIM(logout_at),''), '%Y-%m-%d %H:%i:%s') AS logout_at
FROM raw_agent_sessions;

CREATE OR REPLACE VIEW stg_campaigns AS
SELECT
  _row_id,
  NULLIF(TRIM(campaign_id),'') AS campaign_id,
  NULLIF(TRIM(campaign_name),'') AS campaign_name,
  NULLIF(TRIM(channel),'') AS channel,
  NULLIF(TRIM(strategy_version),'') AS strategy_version,
  STR_TO_DATE(NULLIF(TRIM(start_at),''), '%Y-%m-%d %H:%i:%s') AS start_at,
  NULLIF(TRIM(target_definition),'') AS target_definition,
  STR_TO_DATE(NULLIF(TRIM(end_at),''), '%Y-%m-%d %H:%i:%s') AS end_at
FROM raw_campaigns;

CREATE OR REPLACE VIEW stg_daily_targeting AS
SELECT
  _row_id,
  NULLIF(TRIM(target_id),'') AS target_id,
  NULLIF(TRIM(account_id),'') AS account_id,
  NULLIF(TRIM(campaign_id),'') AS campaign_id,
  DATE(STR_TO_DATE(NULLIF(TRIM(target_date),''), '%Y-%m-%d')) AS target_date,
  CAST(NULLIF(TRIM(priority),'') AS SIGNED) AS priority,
  NULLIF(TRIM(recommended_channel),'') AS recommended_channel,
  NULLIF(TRIM(status),'') AS status
FROM raw_daily_targeting;

CREATE OR REPLACE VIEW stg_calls AS
SELECT
  _row_id,
  NULLIF(TRIM(call_id),'') AS call_id,
  NULLIF(TRIM(account_id),'') AS account_id,
  NULLIF(TRIM(borrower_id),'') AS borrower_id,
  STR_TO_DATE(NULLIF(TRIM(event_at),''), '%Y-%m-%d %H:%i:%s') AS event_at,
  NULLIF(TRIM(agent_id),'') AS agent_id,
  NULLIF(TRIM(campaign_id),'') AS campaign_id,
  NULLIF(TRIM(direction),'') AS direction,
  NULLIF(TRIM(vendor_id),'') AS vendor_id,
  NULLIF(TRIM(call_status),'') AS call_status,
  CAST(NULLIF(TRIM(duration_sec),'') AS SIGNED) AS duration_sec,
  NULLIF(TRIM(timezone),'') AS timezone
FROM raw_calls;

CREATE OR REPLACE VIEW stg_call_attempts AS
SELECT
  _row_id,
  NULLIF(TRIM(attempt_id),'') AS attempt_id,
  NULLIF(TRIM(account_id),'') AS account_id,
  NULLIF(TRIM(borrower_id),'') AS borrower_id,
  STR_TO_DATE(NULLIF(TRIM(event_at),''), '%Y-%m-%d %H:%i:%s') AS event_at,
  NULLIF(TRIM(call_id),'') AS call_id,
  NULLIF(TRIM(agent_id),'') AS agent_id,
  CAST(NULLIF(TRIM(attempt_no),'') AS SIGNED) AS attempt_no,
  NULLIF(TRIM(vendor_id),'') AS vendor_id,
  NULLIF(TRIM(attempt_status),'') AS attempt_status
FROM raw_call_attempts;

CREATE OR REPLACE VIEW stg_call_dispositions AS
SELECT
  _row_id,
  NULLIF(TRIM(disposition_id),'') AS disposition_id,
  NULLIF(TRIM(account_id),'') AS account_id,
  NULLIF(TRIM(borrower_id),'') AS borrower_id,
  STR_TO_DATE(NULLIF(TRIM(event_at),''), '%Y-%m-%d %H:%i:%s') AS event_at,
  NULLIF(TRIM(call_id),'') AS call_id,
  NULLIF(TRIM(agent_id),'') AS agent_id,
  NULLIF(TRIM(disposition_code),'') AS disposition_code,
  NULLIF(TRIM(disposition_version),'') AS disposition_version
FROM raw_call_dispositions;

CREATE OR REPLACE VIEW stg_whatsapp_events AS
SELECT
  _row_id,
  NULLIF(TRIM(whatsapp_event_id),'') AS whatsapp_event_id,
  NULLIF(TRIM(account_id),'') AS account_id,
  NULLIF(TRIM(borrower_id),'') AS borrower_id,
  STR_TO_DATE(NULLIF(TRIM(event_at),''), '%Y-%m-%d %H:%i:%s') AS event_at,
  NULLIF(TRIM(message_id),'') AS message_id,
  NULLIF(TRIM(event_type),'') AS event_type,
  NULLIF(TRIM(template_code),'') AS template_code,
  NULLIF(TRIM(provider_id),'') AS provider_id
FROM raw_whatsapp_events;

CREATE OR REPLACE VIEW stg_sms_events AS
SELECT
  _row_id,
  NULLIF(TRIM(sms_event_id),'') AS sms_event_id,
  NULLIF(TRIM(account_id),'') AS account_id,
  NULLIF(TRIM(borrower_id),'') AS borrower_id,
  STR_TO_DATE(NULLIF(TRIM(event_at),''), '%Y-%m-%d %H:%i:%s') AS event_at,
  NULLIF(TRIM(message_id),'') AS message_id,
  NULLIF(TRIM(event_type),'') AS event_type,
  NULLIF(TRIM(template_code),'') AS template_code,
  NULLIF(TRIM(provider_id),'') AS provider_id
FROM raw_sms_events;

CREATE OR REPLACE VIEW stg_field_visits AS
SELECT
  _row_id,
  NULLIF(TRIM(visit_id),'') AS visit_id,
  NULLIF(TRIM(account_id),'') AS account_id,
  NULLIF(TRIM(borrower_id),'') AS borrower_id,
  STR_TO_DATE(NULLIF(TRIM(event_at),''), '%Y-%m-%d %H:%i:%s') AS event_at,
  NULLIF(TRIM(agent_id),'') AS agent_id,
  NULLIF(TRIM(visit_type),'') AS visit_type,
  NULLIF(TRIM(outcome),'') AS outcome,
  CAST(NULLIF(TRIM(latitude),'') AS DECIMAL(10,6)) AS latitude,
  CAST(NULLIF(TRIM(longitude),'') AS DECIMAL(10,6)) AS longitude,
  STR_TO_DATE(NULLIF(TRIM(scheduled_at),''), '%Y-%m-%d %H:%i:%s') AS scheduled_at
FROM raw_field_visits;

CREATE OR REPLACE VIEW stg_promises_to_pay AS
SELECT
  _row_id,
  NULLIF(TRIM(ptp_id),'') AS ptp_id,
  NULLIF(TRIM(account_id),'') AS account_id,
  NULLIF(TRIM(borrower_id),'') AS borrower_id,
  STR_TO_DATE(NULLIF(TRIM(event_at),''), '%Y-%m-%d %H:%i:%s') AS event_at,
  NULLIF(TRIM(agent_id),'') AS agent_id,
  CAST(NULLIF(TRIM(promised_amount),'') AS DECIMAL(18,2)) AS promised_amount,
  STR_TO_DATE(NULLIF(TRIM(promised_date),''), '%Y-%m-%d %H:%i:%s') AS promised_date,
  NULLIF(TRIM(status),'') AS status,
  NULLIF(TRIM(source),'') AS source
FROM raw_promises_to_pay;

CREATE OR REPLACE VIEW stg_payments AS
SELECT
  _row_id,
  NULLIF(TRIM(payment_id),'') AS payment_id,
  NULLIF(TRIM(account_id),'') AS account_id,
  NULLIF(TRIM(borrower_id),'') AS borrower_id,
  STR_TO_DATE(NULLIF(TRIM(event_at),''), '%Y-%m-%d %H:%i:%s') AS event_at,
  NULLIF(TRIM(payment_reference),'') AS payment_reference,
  CAST(NULLIF(TRIM(amount),'') AS DECIMAL(18,2)) AS amount,
  NULLIF(TRIM(payment_status),'') AS payment_status,
  NULLIF(TRIM(payment_method),'') AS payment_method,
  NULLIF(TRIM(provider_id),'') AS provider_id
FROM raw_payments;

CREATE OR REPLACE VIEW stg_vendor_telephony AS
SELECT
  _row_id,
  NULLIF(TRIM(vendor_id),'') AS vendor_id,
  NULLIF(TRIM(vendor_name),'') AS vendor_name,
  NULLIF(TRIM(vendor_account_id),'') AS vendor_account_id,
  NULLIF(TRIM(timezone),'') AS timezone,
  NULLIF(TRIM(status),'') AS status,
  NULLIF(TRIM(schema_version),'') AS schema_version
FROM raw_vendor_telephony;

CREATE OR REPLACE VIEW stg_complaints AS
SELECT
  _row_id,
  NULLIF(TRIM(complaint_id),'') AS complaint_id,
  NULLIF(TRIM(account_id),'') AS account_id,
  NULLIF(TRIM(borrower_id),'') AS borrower_id,
  STR_TO_DATE(NULLIF(TRIM(event_at),''), '%Y-%m-%d %H:%i:%s') AS event_at,
  NULLIF(TRIM(complaint_type),'') AS complaint_type,
  NULLIF(TRIM(severity),'') AS severity,
  NULLIF(TRIM(status),'') AS status,
  NULLIF(TRIM(source),'') AS source,
  STR_TO_DATE(NULLIF(TRIM(resolution_at),''), '%Y-%m-%d %H:%i:%s') AS resolution_at
FROM raw_complaints;

CREATE OR REPLACE VIEW stg_account_status_history AS
SELECT
  _row_id,
  NULLIF(TRIM(history_id),'') AS history_id,
  NULLIF(TRIM(account_id),'') AS account_id,
  NULLIF(TRIM(borrower_id),'') AS borrower_id,
  STR_TO_DATE(NULLIF(TRIM(event_at),''), '%Y-%m-%d %H:%i:%s') AS event_at,
  NULLIF(TRIM(status),'') AS status,
  NULLIF(TRIM(changed_by),'') AS changed_by,
  NULLIF(TRIM(source),'') AS source,
  STR_TO_DATE(NULLIF(TRIM(recorded_at),''), '%Y-%m-%d %H:%i:%s') AS recorded_at
FROM raw_account_status_history;
