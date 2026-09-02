USE collections_analytics;

-- ============================================================
-- DRIVER ANALYSIS
-- Use these outputs for descriptive evidence. They do not establish causality.
-- ============================================================

-- 1) Portfolio / DPD / borrower-segment proxy
SELECT
  month_start,
  dpd_bucket,
  risk_segment,
  loan_type,
  COUNT(*) AS targeted_accounts,
  SUM(successful_recovery) AS recovery,
  SUM(successful_recovery)/NULLIF(COUNT(*),0) AS recovery_per_targeted_account,
  AVG(payer_flag) AS payer_rate,
  AVG(outstanding_amount) AS avg_outstanding,
  'CORRELATION / MIX' AS evidence_level
FROM golden_account_month
WHERE targeted_flag=1 AND is_complete_month=1
GROUP BY month_start, dpd_bucket, risk_segment, loan_type
ORDER BY month_start, dpd_bucket, risk_segment, loan_type;

-- 2) Geography. Borrower master conflicts are surfaced, not hidden.
SELECT
  month_start,
  state,
  city,
  COUNT(*) AS targeted_accounts,
  SUM(borrower_conflict_flag) AS accounts_with_borrower_master_conflict,
  SUM(successful_recovery) AS recovery,
  AVG(payer_flag) AS payer_rate,
  SUM(successful_recovery)/NULLIF(COUNT(*),0) AS recovery_per_targeted_account,
  'CORRELATION; GEOGRAPHY LOW-CONFIDENCE WHERE MASTER CONFLICTS' AS evidence_level
FROM golden_account_month
WHERE targeted_flag=1 AND is_complete_month=1
GROUP BY month_start, state, city
ORDER BY month_start, recovery DESC;

-- 3) Campaign performance. Non-exclusive because one account can be in multiple campaigns.
WITH campaign_accounts AS (
  SELECT DISTINCT month_start, campaign_id, campaign_name, strategy_version, campaign_channel, account_id,
         campaign_window_valid_flag
  FROM clean_targeting
), outcomes AS (
  SELECT month_start, account_id, successful_recovery, payer_flag
  FROM golden_account_month
)
SELECT
  c.month_start,
  c.campaign_id,
  c.campaign_name,
  c.strategy_version,
  c.campaign_channel,
  COUNT(*) AS targeted_accounts,
  SUM(c.campaign_window_valid_flag=0) AS accounts_from_out_of_window_target_rows,
  SUM(o.successful_recovery) AS nonexclusive_account_month_recovery,
  AVG(o.payer_flag) AS payer_rate,
  SUM(o.successful_recovery)/NULLIF(COUNT(*),0) AS recovery_per_targeted_account,
  'CORRELATION / NON-EXCLUSIVE CAMPAIGN ASSOCIATION' AS evidence_level
FROM campaign_accounts c
JOIN outcomes o ON o.month_start=c.month_start AND o.account_id=c.account_id
GROUP BY c.month_start,c.campaign_id,c.campaign_name,c.strategy_version,c.campaign_channel
ORDER BY c.month_start, nonexclusive_account_month_recovery DESC;

-- 4) Channel conversion (7-day descriptive window)
SELECT *, 'CORRELATION / NON-EXCLUSIVE ATTRIBUTION' AS evidence_level
FROM mart_channel_conversion_7d
ORDER BY month_start, channel;

-- 5) Telephony vendor
SELECT *, 'STRONG DESCRIPTIVE EVIDENCE FOR CONTACT RATE; NOT RECOVERY CAUSALITY' AS evidence_level
FROM mart_vendor_calling
ORDER BY month_start, contact_rate DESC;

-- 6) Calling time
SELECT *, 'STRONG DESCRIPTIVE EVIDENCE FOR CONTACT RATE; NOT CAUSAL RECOVERY' AS evidence_level
FROM mart_calling_hour
ORDER BY month_start, hour_ist;

-- 7) Agent identity / tenure. Filter or caveat conflict_flag before conclusions.
SELECT *,
       CASE WHEN agent_conflict_flag=1
            THEN 'LOW-CONFIDENCE: AGENT MASTER CONFLICT'
            ELSE 'CORRELATION'
       END AS evidence_level
FROM mart_agent_calling
ORDER BY month_start, contact_rate DESC;

-- 8) Attempt frequency proxy from clean call count
SELECT *, 'CORRELATION; SUSCEPTIBLE TO SELECTION BIAS' AS evidence_level
FROM mart_attempt_frequency
ORDER BY month_start,
  FIELD(monthly_call_frequency_bucket,'0','1','2','3-5','6-10','11+');

-- 9) Complaints vs attempt intensity
SELECT
  month_start,
  CASE
    WHEN calls_total = 0 THEN '0'
    WHEN calls_total BETWEEN 1 AND 2 THEN '1-2'
    WHEN calls_total BETWEEN 3 AND 5 THEN '3-5'
    WHEN calls_total BETWEEN 6 AND 10 THEN '6-10'
    ELSE '11+'
  END AS call_intensity,
  COUNT(*) AS accounts,
  AVG(complaint_count > 0) AS complaint_account_rate,
  AVG(severe_complaint_count > 0) AS severe_complaint_account_rate,
  AVG(payer_flag) AS payer_rate,
  'CORRELATION / POSSIBLE FREQUENCY-HARM TRADEOFF' AS evidence_level
FROM golden_account_month
WHERE is_complete_month=1
GROUP BY month_start,
  CASE
    WHEN calls_total = 0 THEN '0'
    WHEN calls_total BETWEEN 1 AND 2 THEN '1-2'
    WHEN calls_total BETWEEN 3 AND 5 THEN '3-5'
    WHEN calls_total BETWEEN 6 AND 10 THEN '6-10'
    ELSE '11+'
  END
ORDER BY month_start, call_intensity;

-- 10) Explicit unsupported dimensions requested by the brief.
SELECT
  'client' AS requested_dimension,
  'UNAVAILABLE' AS status,
  'No client identifier/attribute exists in supplied datasets; do not infer one.' AS reason
UNION ALL
SELECT
  'language',
  'UNAVAILABLE',
  'No borrower language field or defensible language proxy exists in supplied datasets; geography must not be silently converted into language.';
