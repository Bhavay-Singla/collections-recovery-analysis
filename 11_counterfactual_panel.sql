USE collections_analytics;

-- ============================================================
-- COUNTERFACTUAL ANALYSIS PANEL
-- The supplied data do not contain a clean single strategy-change flag.
-- Campaign strategy versions coexist across months. Therefore this SQL prepares
-- a transparent account-month panel for matching/regression/DiD in the notebook.
-- ============================================================

CREATE OR REPLACE VIEW analysis_counterfactual_panel AS
WITH base AS (
  SELECT
    g.*,
    CASE WHEN g.month_start >= '2026-07-01' THEN 1 ELSE 0 END AS post_midyear_flag,
    LAG(g.targeted_flag) OVER (PARTITION BY g.account_id ORDER BY g.month_start) AS prior_month_targeted_flag,
    AVG(g.successful_recovery) OVER (
      PARTITION BY g.account_id
      ORDER BY g.month_start
      ROWS BETWEEN UNBOUNDED PRECEDING AND 1 PRECEDING
    ) AS prior_avg_recovery,
    AVG(g.payer_flag) OVER (
      PARTITION BY g.account_id
      ORDER BY g.month_start
      ROWS BETWEEN UNBOUNDED PRECEDING AND 1 PRECEDING
    ) AS prior_payer_rate,
    AVG(g.calls_total) OVER (
      PARTITION BY g.account_id
      ORDER BY g.month_start
      ROWS BETWEEN UNBOUNDED PRECEDING AND 1 PRECEDING
    ) AS prior_avg_calls
  FROM golden_account_month g
)
SELECT
  month_start,
  account_id,
  borrower_id,
  post_midyear_flag,
  targeted_flag,
  CASE
    WHEN targeted_flag=1 AND COALESCE(prior_month_targeted_flag,0)=0 THEN 1 ELSE 0
  END AS newly_targeted_flag,

  -- Pre-treatment / matching covariates
  loan_type,
  dpd,
  dpd_bucket,
  risk_segment,
  outstanding_amount,
  state,
  city,
  borrower_conflict_flag,
  prior_avg_recovery,
  prior_payer_rate,
  prior_avg_calls,

  -- Treatment intensity / mechanism variables
  targeted_days,
  campaigns_targeted,
  max_priority,
  recommended_voice_flag,
  recommended_whatsapp_flag,
  recommended_sms_flag,
  recommended_field_flag,
  calls_total,
  answered_outbound_calls,
  whatsapp_payment_clicks,
  sms_clicked,
  field_visits,

  -- Outcomes
  successful_recovery,
  payer_flag,
  ptp_count,
  ptp_kept,
  complaint_count,
  severe_complaint_count,
  is_complete_month
FROM base;

-- Strategy-version composition check: demonstrates whether a clean treatment
-- switch is actually observable in the raw targeting records.
SELECT
  month_start,
  strategy_version,
  COUNT(*) AS target_rows,
  COUNT(*) / SUM(COUNT(*)) OVER (PARTITION BY month_start) AS share_of_month_targets
FROM clean_targeting
GROUP BY month_start, strategy_version
ORDER BY month_start, strategy_version;

-- Suggested identification dataset:
-- Treatment: newly targeted accounts in the post-midyear period.
-- Potential controls: comparable non-newly-targeted accounts matched on DPD,
-- risk, loan type, outstanding amount and pre-period outcomes.
SELECT *
FROM analysis_counterfactual_panel
WHERE is_complete_month=1
ORDER BY account_id, month_start;
