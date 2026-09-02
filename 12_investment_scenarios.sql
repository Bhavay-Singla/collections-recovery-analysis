USE collections_analytics;

-- ============================================================
-- ₹10 Cr INVESTMENT SCENARIO MODEL
-- Recommendation candidate: Better Borrower Targeting
-- IMPORTANT: This is scenario analysis, not measured causal ROI.
-- No reliable historical cost table or randomized targeting experiment exists.
-- ============================================================

WITH complete_months AS (
  SELECT month_start, clean_successful_recovery
  FROM mart_monthly_recovery
  WHERE is_complete_month=1
), baseline AS (
  SELECT
    COUNT(*) AS complete_month_count,
    SUM(clean_successful_recovery) AS observed_recovery,
    SUM(clean_successful_recovery) / NULLIF(COUNT(*),0) * 12 AS annualized_recovery
  FROM complete_months
), scenarios AS (
  SELECT 'Downside' AS scenario, 0.03 AS assumed_incremental_lift
  UNION ALL SELECT 'Base', 0.05
  UNION ALL SELECT 'Upside', 0.07
), model AS (
  SELECT
    s.scenario,
    b.complete_month_count,
    b.observed_recovery,
    b.annualized_recovery,
    100000000.00 AS investment_rupees,
    s.assumed_incremental_lift,
    b.annualized_recovery * s.assumed_incremental_lift AS annual_incremental_recovery
  FROM baseline b CROSS JOIN scenarios s
)
SELECT
  scenario,
  complete_month_count,
  observed_recovery,
  annualized_recovery,
  investment_rupees,
  assumed_incremental_lift,
  annual_incremental_recovery,
  (annual_incremental_recovery - investment_rupees) / investment_rupees AS first_year_gross_recovery_roi,
  investment_rupees / NULLIF(annual_incremental_recovery/12.0,0) AS gross_break_even_months,
  'Targeting lift applied to annualized clean successful recovery; no contribution-margin assumption.' AS key_assumption,
  'LOW-MEDIUM until randomized holdout validates incremental recovery.' AS confidence
FROM model
ORDER BY FIELD(scenario,'Downside','Base','Upside');

-- Decision rationale indicators for the six investment options.
-- These are evidence availability flags, not scores pretending to be causal estimates.
SELECT 'Better telephony infrastructure' AS option_name,
       'AVAILABLE' AS operational_evidence,
       'Contact/vendor metrics exist, but recovery causality is not identified.' AS limitation
UNION ALL
SELECT 'More collection agents','PARTIAL','Agent-hours exist; agent master identity/tenure is highly conflicted and marginal agent recovery is not identified.'
UNION ALL
SELECT 'AI voice automation','INSUFFICIENT','No explicit AI-voice treatment/control flag or unit economics supplied.'
UNION ALL
SELECT 'Better borrower targeting','STRONGEST AVAILABLE','Targeting selection/mix is measurable and campaign-quality problems are directly observable; causal lift still needs holdout validation.'
UNION ALL
SELECT 'WhatsApp/digital engagement','PARTIAL','Digital engagement events exist; channel attribution is non-exclusive and costs are absent.'
UNION ALL
SELECT 'Field operations','PARTIAL','Visit outcomes exist; no clean cost base or causal recovery attribution is supplied.';
