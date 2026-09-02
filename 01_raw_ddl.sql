USE collections_analytics;

-- Raw tables intentionally preserve source values as strings.
-- Type casting, deduplication and business rules happen downstream.

CREATE TABLE raw_borrowers (
  _row_id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  borrower_id VARCHAR(32), name VARCHAR(255), phone VARCHAR(64), email VARCHAR(255), city VARCHAR(128),
  created_at VARCHAR(32), updated_at VARCHAR(32), state VARCHAR(128),
  _ingested_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE raw_accounts (
  _row_id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  account_id VARCHAR(32), borrower_id VARCHAR(32), loan_type VARCHAR(64), principal_amount VARCHAR(64),
  outstanding_amount VARCHAR(64), dpd VARCHAR(32), risk_segment VARCHAR(64), status VARCHAR(64),
  opened_at VARCHAR(32), timezone VARCHAR(64), schema_version VARCHAR(32),
  _ingested_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE raw_agents (
  _row_id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  agent_id VARCHAR(32), employee_code VARCHAR(64), agent_name VARCHAR(255), vendor_id VARCHAR(32),
  team VARCHAR(64), status VARCHAR(64), joined_at VARCHAR(32), updated_at VARCHAR(32),
  _ingested_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE raw_agent_sessions (
  _row_id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  session_id VARCHAR(32), agent_id VARCHAR(32), login_at VARCHAR(32), channel VARCHAR(64), device_id VARCHAR(64),
  timezone VARCHAR(64), logout_at VARCHAR(32),
  _ingested_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE raw_campaigns (
  _row_id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  campaign_id VARCHAR(32), campaign_name VARCHAR(128), channel VARCHAR(64), strategy_version VARCHAR(32),
  start_at VARCHAR(32), target_definition VARCHAR(255), end_at VARCHAR(32),
  _ingested_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE raw_daily_targeting (
  _row_id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  target_id VARCHAR(32), account_id VARCHAR(32), campaign_id VARCHAR(32), target_date VARCHAR(32),
  priority VARCHAR(32), recommended_channel VARCHAR(64), status VARCHAR(64),
  _ingested_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE raw_calls (
  _row_id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  call_id VARCHAR(32), account_id VARCHAR(32), borrower_id VARCHAR(32), event_at VARCHAR(32), agent_id VARCHAR(32),
  campaign_id VARCHAR(32), direction VARCHAR(32), vendor_id VARCHAR(32), call_status VARCHAR(64),
  duration_sec VARCHAR(32), timezone VARCHAR(64),
  _ingested_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE raw_call_attempts (
  _row_id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  attempt_id VARCHAR(32), account_id VARCHAR(32), borrower_id VARCHAR(32), event_at VARCHAR(32), call_id VARCHAR(32),
  agent_id VARCHAR(32), attempt_no VARCHAR(32), vendor_id VARCHAR(32), attempt_status VARCHAR(64),
  _ingested_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE raw_call_dispositions (
  _row_id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  disposition_id VARCHAR(32), account_id VARCHAR(32), borrower_id VARCHAR(32), event_at VARCHAR(32), call_id VARCHAR(32),
  agent_id VARCHAR(32), disposition_code VARCHAR(64), disposition_version VARCHAR(32),
  _ingested_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE raw_whatsapp_events (
  _row_id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  whatsapp_event_id VARCHAR(40), account_id VARCHAR(32), borrower_id VARCHAR(32), event_at VARCHAR(32),
  message_id VARCHAR(64), event_type VARCHAR(64), template_code VARCHAR(64), provider_id VARCHAR(32),
  _ingested_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE raw_sms_events (
  _row_id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  sms_event_id VARCHAR(40), account_id VARCHAR(32), borrower_id VARCHAR(32), event_at VARCHAR(32),
  message_id VARCHAR(64), event_type VARCHAR(64), template_code VARCHAR(64), provider_id VARCHAR(32),
  _ingested_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE raw_field_visits (
  _row_id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  visit_id VARCHAR(32), account_id VARCHAR(32), borrower_id VARCHAR(32), event_at VARCHAR(32), agent_id VARCHAR(32),
  visit_type VARCHAR(64), outcome VARCHAR(64), latitude VARCHAR(64), longitude VARCHAR(64), scheduled_at VARCHAR(32),
  _ingested_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE raw_promises_to_pay (
  _row_id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  ptp_id VARCHAR(32), account_id VARCHAR(32), borrower_id VARCHAR(32), event_at VARCHAR(32), agent_id VARCHAR(32),
  promised_amount VARCHAR(64), promised_date VARCHAR(32), status VARCHAR(64), source VARCHAR(64),
  _ingested_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE raw_payments (
  _row_id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  payment_id VARCHAR(32), account_id VARCHAR(32), borrower_id VARCHAR(32), event_at VARCHAR(32),
  payment_reference VARCHAR(64), amount VARCHAR(64), payment_status VARCHAR(64), payment_method VARCHAR(64), provider_id VARCHAR(32),
  _ingested_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE raw_vendor_telephony (
  _row_id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  vendor_id VARCHAR(32), vendor_name VARCHAR(128), vendor_account_id VARCHAR(64), timezone VARCHAR(64),
  status VARCHAR(64), schema_version VARCHAR(32),
  _ingested_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE raw_complaints (
  _row_id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  complaint_id VARCHAR(32), account_id VARCHAR(32), borrower_id VARCHAR(32), event_at VARCHAR(32),
  complaint_type VARCHAR(64), severity VARCHAR(32), status VARCHAR(64), source VARCHAR(64), resolution_at VARCHAR(32),
  _ingested_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE raw_account_status_history (
  _row_id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  history_id VARCHAR(32), account_id VARCHAR(32), borrower_id VARCHAR(32), event_at VARCHAR(32),
  status VARCHAR(64), changed_by VARCHAR(64), source VARCHAR(64), recorded_at VARCHAR(32),
  _ingested_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;
