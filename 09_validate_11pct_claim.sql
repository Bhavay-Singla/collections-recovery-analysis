USE collections_analytics;

-- ============================================================
-- 1) RECONSTRUCT MONTHLY PERFORMANCE
-- August is expected to be incomplete and should not be used as a full MoM month.
-- ============================================================
SELECT
  month_start,
  is_complete_month,
  clean_successful_recovery,
  successful_payment_count,
  unique_paying_accounts,
  targeted_accounts,
  recovery_from_targeted_accounts,
  recovery_per_targeted_account,
  targeted_account_payer_conversion,
  targeted_balance_recovery_proxy,
  contact_rate,
  ptp_kept_rate,
  recovery_per_agent_hour
FROM mart_monthly_recovery
ORDER BY month_start;

-- ============================================================
-- 2) JUNE -> JULY: RAW, DEDUPED-SOURCE-TIME, CANONICAL-IST
-- This separates duplicate-event impact from timezone treatment.
-- ============================================================
WITH raw_month AS (
  SELECT
    CAST(DATE_FORMAT(event_at,'%Y-%m-01') AS DATE) AS month_start,
    SUM(amount) AS recovery
  FROM stg_payments
  WHERE payment_status='SUCCESS'
  GROUP BY CAST(DATE_FORMAT(event_at,'%Y-%m-01') AS DATE)
), clean_source_month AS (
  SELECT
    CAST(DATE_FORMAT(event_at_raw,'%Y-%m-01') AS DATE) AS month_start,
    SUM(amount) AS recovery
  FROM clean_payments
  WHERE payment_status='SUCCESS'
  GROUP BY CAST(DATE_FORMAT(event_at_raw,'%Y-%m-01') AS DATE)
), clean_ist_month AS (
  SELECT month_start, SUM(amount) AS recovery
  FROM clean_payments
  WHERE payment_status='SUCCESS'
  GROUP BY month_start
), p AS (
  SELECT
    'raw_undeduped_source_timestamp' AS definition,
    MAX(CASE WHEN month_start='2026-06-01' THEN recovery END) AS june_recovery,
    MAX(CASE WHEN month_start='2026-07-01' THEN recovery END) AS july_recovery
  FROM raw_month
  UNION ALL
  SELECT
    'deduped_source_timestamp',
    MAX(CASE WHEN month_start='2026-06-01' THEN recovery END),
    MAX(CASE WHEN month_start='2026-07-01' THEN recovery END)
  FROM clean_source_month
  UNION ALL
  SELECT
    'canonical_IST',
    MAX(CASE WHEN month_start='2026-06-01' THEN recovery END),
    MAX(CASE WHEN month_start='2026-07-01' THEN recovery END)
  FROM clean_ist_month
)
SELECT
  definition,
  june_recovery,
  july_recovery,
  (july_recovery / NULLIF(june_recovery,0)) - 1 AS june_to_july_change
FROM p;

-- ============================================================
-- 3) METRIC / DENOMINATOR SENSITIVITY
-- Different defensible metrics answer different business questions.
-- ============================================================
WITH x AS (
  SELECT * FROM mart_monthly_recovery
  WHERE month_start IN ('2026-06-01','2026-07-01')
), measures AS (
  SELECT 'clean_successful_recovery' AS metric,
         MAX(CASE WHEN month_start='2026-06-01' THEN clean_successful_recovery END) AS june_value,
         MAX(CASE WHEN month_start='2026-07-01' THEN clean_successful_recovery END) AS july_value FROM x
  UNION ALL
  SELECT 'recovery_from_targeted_accounts',
         MAX(CASE WHEN month_start='2026-06-01' THEN recovery_from_targeted_accounts END),
         MAX(CASE WHEN month_start='2026-07-01' THEN recovery_from_targeted_accounts END) FROM x
  UNION ALL
  SELECT 'recovery_per_targeted_account',
         MAX(CASE WHEN month_start='2026-06-01' THEN recovery_per_targeted_account END),
         MAX(CASE WHEN month_start='2026-07-01' THEN recovery_per_targeted_account END) FROM x
  UNION ALL
  SELECT 'targeted_account_payer_conversion',
         MAX(CASE WHEN month_start='2026-06-01' THEN targeted_account_payer_conversion END),
         MAX(CASE WHEN month_start='2026-07-01' THEN targeted_account_payer_conversion END) FROM x
  UNION ALL
  SELECT 'targeted_balance_recovery_proxy',
         MAX(CASE WHEN month_start='2026-06-01' THEN targeted_balance_recovery_proxy END),
         MAX(CASE WHEN month_start='2026-07-01' THEN targeted_balance_recovery_proxy END) FROM x
  UNION ALL
  SELECT 'contact_rate',
         MAX(CASE WHEN month_start='2026-06-01' THEN contact_rate END),
         MAX(CASE WHEN month_start='2026-07-01' THEN contact_rate END) FROM x
)
SELECT
  metric,
  june_value,
  july_value,
  (july_value / NULLIF(june_value,0)) - 1 AS relative_change
FROM measures;

-- ============================================================
-- 4) DENOMINATOR MANIPULATION TEST
-- Shows how restricting targeting status can change apparent conversion.
-- ============================================================
WITH target_sets AS (
  SELECT month_start, account_id, 'ALL_TARGETED' AS denominator
  FROM clean_targeting
  WHERE month_start IN ('2026-06-01','2026-07-01')
  GROUP BY month_start, account_id
  UNION ALL
  SELECT month_start, account_id, 'CONTACTED_ONLY'
  FROM clean_targeting
  WHERE month_start IN ('2026-06-01','2026-07-01') AND targeting_status='CONTACTED'
  GROUP BY month_start, account_id
  UNION ALL
  SELECT month_start, account_id, 'NON_SKIPPED_NON_EXPIRED'
  FROM clean_targeting
  WHERE month_start IN ('2026-06-01','2026-07-01') AND targeting_status IN ('QUEUED','CONTACTED')
  GROUP BY month_start, account_id
), account_outcome AS (
  SELECT month_start, account_id, successful_recovery, payer_flag
  FROM golden_account_month
  WHERE month_start IN ('2026-06-01','2026-07-01')
)
SELECT
  t.denominator,
  t.month_start,
  COUNT(*) AS denominator_accounts,
  SUM(COALESCE(o.payer_flag,0)) AS paying_accounts,
  SUM(COALESCE(o.successful_recovery,0)) AS recovery,
  SUM(COALESCE(o.payer_flag,0))/NULLIF(COUNT(*),0) AS payer_conversion,
  SUM(COALESCE(o.successful_recovery,0))/NULLIF(COUNT(*),0) AS recovery_per_account
FROM target_sets t
LEFT JOIN account_outcome o
  ON o.month_start=t.month_start AND o.account_id=t.account_id
GROUP BY t.denominator, t.month_start
ORDER BY t.denominator, t.month_start;

-- ============================================================
-- 5) SAME-ACCOUNT COHORT TEST
-- If operations improved, retained accounts should also show meaningful lift.
-- ============================================================
WITH june AS (
  SELECT DISTINCT account_id FROM clean_targeting WHERE month_start='2026-06-01'
), july AS (
  SELECT DISTINCT account_id FROM clean_targeting WHERE month_start='2026-07-01'
), cohort AS (
  SELECT a.account_id,
         CASE
           WHEN jn.account_id IS NOT NULL AND jy.account_id IS NOT NULL THEN 'TARGETED_BOTH_MONTHS'
           WHEN jn.account_id IS NOT NULL THEN 'JUNE_ONLY'
           WHEN jy.account_id IS NOT NULL THEN 'JULY_ONLY'
         END AS cohort
  FROM (SELECT account_id FROM june UNION SELECT account_id FROM july) a
  LEFT JOIN june jn ON a.account_id=jn.account_id
  LEFT JOIN july jy ON a.account_id=jy.account_id
), outcomes AS (
  SELECT account_id,
         SUM(CASE WHEN month_start='2026-06-01' THEN successful_recovery ELSE 0 END) AS june_recovery,
         SUM(CASE WHEN month_start='2026-07-01' THEN successful_recovery ELSE 0 END) AS july_recovery,
         MAX(CASE WHEN month_start='2026-06-01' THEN payer_flag ELSE 0 END) AS june_payer,
         MAX(CASE WHEN month_start='2026-07-01' THEN payer_flag ELSE 0 END) AS july_payer
  FROM golden_account_month
  WHERE month_start IN ('2026-06-01','2026-07-01')
  GROUP BY account_id
)
SELECT
  c.cohort,
  COUNT(*) AS accounts,
  SUM(o.june_recovery) AS june_recovery,
  SUM(o.july_recovery) AS july_recovery,
  SUM(o.june_recovery)/NULLIF(COUNT(*),0) AS june_recovery_per_account,
  SUM(o.july_recovery)/NULLIF(COUNT(*),0) AS july_recovery_per_account,
  (SUM(o.july_recovery)/NULLIF(COUNT(*),0))
    / NULLIF((SUM(o.june_recovery)/NULLIF(COUNT(*),0)),0) - 1 AS recovery_per_account_change,
  AVG(o.june_payer) AS june_payer_rate,
  AVG(o.july_payer) AS july_payer_rate
FROM cohort c
JOIN outcomes o ON c.account_id=o.account_id
GROUP BY c.cohort
ORDER BY c.cohort;

-- ============================================================
-- 6) PORTFOLIO MIX BY DPD / RISK / LOAN TYPE
-- DPD is static in supplied account master; treat this as a mix proxy.
-- ============================================================
SELECT
  month_start,
  dpd_bucket,
  risk_segment,
  loan_type,
  COUNT(*) AS targeted_accounts,
  SUM(successful_recovery) AS recovery,
  SUM(successful_recovery)/NULLIF(COUNT(*),0) AS recovery_per_targeted_account,
  AVG(payer_flag) AS payer_rate,
  AVG(outstanding_amount) AS avg_outstanding_amount
FROM golden_account_month
WHERE month_start IN ('2026-06-01','2026-07-01')
  AND targeted_flag=1
GROUP BY month_start, dpd_bucket, risk_segment, loan_type
ORDER BY dpd_bucket, risk_segment, loan_type, month_start;

-- ============================================================
-- 7) SIMPLE FIXED-MIX DECOMPOSITION
-- Expected July recovery if July had its observed segment mix but June's
-- segment-level recovery/account. Difference from June = mix contribution;
-- observed July minus expected = within-segment performance contribution.
-- ============================================================
WITH seg AS (
  SELECT
    month_start, dpd_bucket, risk_segment, loan_type,
    COUNT(*) AS accounts,
    SUM(successful_recovery) AS recovery,
    SUM(successful_recovery)/NULLIF(COUNT(*),0) AS recovery_per_account
  FROM golden_account_month
  WHERE month_start IN ('2026-06-01','2026-07-01') AND targeted_flag=1
  GROUP BY month_start, dpd_bucket, risk_segment, loan_type
), june_rates AS (
  SELECT dpd_bucket, risk_segment, loan_type, recovery_per_account AS june_rate
  FROM seg WHERE month_start='2026-06-01'
), july_mix AS (
  SELECT s.dpd_bucket, s.risk_segment, s.loan_type, s.accounts AS july_accounts, j.june_rate
  FROM seg s
  JOIN june_rates j USING (dpd_bucket,risk_segment,loan_type)
  WHERE s.month_start='2026-07-01'
), totals AS (
  SELECT
    (SELECT SUM(recovery) FROM seg WHERE month_start='2026-06-01') AS observed_june_recovery,
    (SELECT SUM(recovery) FROM seg WHERE month_start='2026-07-01') AS observed_july_recovery,
    (SELECT SUM(july_accounts*june_rate) FROM july_mix) AS expected_july_recovery_at_june_segment_rates
)
SELECT
  observed_june_recovery,
  expected_july_recovery_at_june_segment_rates,
  observed_july_recovery,
  expected_july_recovery_at_june_segment_rates - observed_june_recovery AS estimated_mix_effect,
  observed_july_recovery - expected_july_recovery_at_june_segment_rates AS estimated_within_segment_effect,
  'DESCRIPTIVE: static DPD/outstanding fields limit historical causal interpretation' AS caveat
FROM totals;
