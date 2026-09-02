USE collections_analytics;

-- IMPORTANT: Replace /absolute/path/to/collections_30k_unzipped/ with your local CSV directory.
-- Run mysql client with --local-infile=1.

LOAD DATA LOCAL INFILE '/absolute/path/to/collections_30k_unzipped/borrowers.csv'
INTO TABLE raw_borrowers FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"' LINES TERMINATED BY '\n' IGNORE 1 LINES
(borrower_id,name,phone,email,city,created_at,updated_at,state);

LOAD DATA LOCAL INFILE '/absolute/path/to/collections_30k_unzipped/accounts.csv'
INTO TABLE raw_accounts FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"' LINES TERMINATED BY '\n' IGNORE 1 LINES
(account_id,borrower_id,loan_type,principal_amount,outstanding_amount,dpd,risk_segment,status,opened_at,timezone,schema_version);

LOAD DATA LOCAL INFILE '/absolute/path/to/collections_30k_unzipped/agents.csv'
INTO TABLE raw_agents FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"' LINES TERMINATED BY '\n' IGNORE 1 LINES
(agent_id,employee_code,agent_name,vendor_id,team,status,joined_at,updated_at);

LOAD DATA LOCAL INFILE '/absolute/path/to/collections_30k_unzipped/agent_sessions.csv'
INTO TABLE raw_agent_sessions FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"' LINES TERMINATED BY '\n' IGNORE 1 LINES
(session_id,agent_id,login_at,channel,device_id,timezone,logout_at);

LOAD DATA LOCAL INFILE '/absolute/path/to/collections_30k_unzipped/campaigns.csv'
INTO TABLE raw_campaigns FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"' LINES TERMINATED BY '\n' IGNORE 1 LINES
(campaign_id,campaign_name,channel,strategy_version,start_at,target_definition,end_at);

LOAD DATA LOCAL INFILE '/absolute/path/to/collections_30k_unzipped/daily_targeting.csv'
INTO TABLE raw_daily_targeting FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"' LINES TERMINATED BY '\n' IGNORE 1 LINES
(target_id,account_id,campaign_id,target_date,priority,recommended_channel,status);

LOAD DATA LOCAL INFILE '/absolute/path/to/collections_30k_unzipped/calls.csv'
INTO TABLE raw_calls FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"' LINES TERMINATED BY '\n' IGNORE 1 LINES
(call_id,account_id,borrower_id,event_at,agent_id,campaign_id,direction,vendor_id,call_status,duration_sec,timezone);

LOAD DATA LOCAL INFILE '/absolute/path/to/collections_30k_unzipped/call_attempts.csv'
INTO TABLE raw_call_attempts FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"' LINES TERMINATED BY '\n' IGNORE 1 LINES
(attempt_id,account_id,borrower_id,event_at,call_id,agent_id,attempt_no,vendor_id,attempt_status);

LOAD DATA LOCAL INFILE '/absolute/path/to/collections_30k_unzipped/call_dispositions.csv'
INTO TABLE raw_call_dispositions FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"' LINES TERMINATED BY '\n' IGNORE 1 LINES
(disposition_id,account_id,borrower_id,event_at,call_id,agent_id,disposition_code,disposition_version);

LOAD DATA LOCAL INFILE '/absolute/path/to/collections_30k_unzipped/whatsapp_events.csv'
INTO TABLE raw_whatsapp_events FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"' LINES TERMINATED BY '\n' IGNORE 1 LINES
(whatsapp_event_id,account_id,borrower_id,event_at,message_id,event_type,template_code,provider_id);

LOAD DATA LOCAL INFILE '/absolute/path/to/collections_30k_unzipped/sms_events.csv'
INTO TABLE raw_sms_events FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"' LINES TERMINATED BY '\n' IGNORE 1 LINES
(sms_event_id,account_id,borrower_id,event_at,message_id,event_type,template_code,provider_id);

LOAD DATA LOCAL INFILE '/absolute/path/to/collections_30k_unzipped/field_visits.csv'
INTO TABLE raw_field_visits FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"' LINES TERMINATED BY '\n' IGNORE 1 LINES
(visit_id,account_id,borrower_id,event_at,agent_id,visit_type,outcome,latitude,longitude,scheduled_at);

LOAD DATA LOCAL INFILE '/absolute/path/to/collections_30k_unzipped/promises_to_pay.csv'
INTO TABLE raw_promises_to_pay FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"' LINES TERMINATED BY '\n' IGNORE 1 LINES
(ptp_id,account_id,borrower_id,event_at,agent_id,promised_amount,promised_date,status,source);

LOAD DATA LOCAL INFILE '/absolute/path/to/collections_30k_unzipped/payments.csv'
INTO TABLE raw_payments FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"' LINES TERMINATED BY '\n' IGNORE 1 LINES
(payment_id,account_id,borrower_id,event_at,payment_reference,amount,payment_status,payment_method,provider_id);

LOAD DATA LOCAL INFILE '/absolute/path/to/collections_30k_unzipped/vendor_telephony.csv'
INTO TABLE raw_vendor_telephony FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"' LINES TERMINATED BY '\n' IGNORE 1 LINES
(vendor_id,vendor_name,vendor_account_id,timezone,status,schema_version);

LOAD DATA LOCAL INFILE '/absolute/path/to/collections_30k_unzipped/complaints.csv'
INTO TABLE raw_complaints FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"' LINES TERMINATED BY '\n' IGNORE 1 LINES
(complaint_id,account_id,borrower_id,event_at,complaint_type,severity,status,source,resolution_at);

LOAD DATA LOCAL INFILE '/absolute/path/to/collections_30k_unzipped/account_status_history.csv'
INTO TABLE raw_account_status_history FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"' LINES TERMINATED BY '\n' IGNORE 1 LINES
(history_id,account_id,borrower_id,event_at,status,changed_by,source,recorded_at);
