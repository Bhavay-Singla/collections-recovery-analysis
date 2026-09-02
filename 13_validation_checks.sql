USE collections_analytics;

-- ============================================================
-- PIPELINE VALIDATION / DATA CONTRACT TESTS
-- A production job can fail the pipeline when any CRITICAL test returns FAIL.
-- ============================================================

SELECT 'accounts_unique' AS test_name,
       CASE WHEN COUNT(*) = COUNT(DISTINCT account_id) THEN 'PASS' ELSE 'FAIL' END AS result,
       COUNT(*) AS rows_checked,
       COUNT(*)-COUNT(DISTINCT account_id) AS violations
FROM clean_accounts
UNION ALL
SELECT 'payments_unique',
       CASE WHEN COUNT(*) = COUNT(DISTINCT payment_id) THEN 'PASS' ELSE 'FAIL' END,
       COUNT(*), COUNT(*)-COUNT(DISTINCT payment_id)
FROM clean_payments
UNION ALL
SELECT 'calls_unique',
       CASE WHEN COUNT(*) = COUNT(DISTINCT call_id) THEN 'PASS' ELSE 'FAIL' END,
       COUNT(*), COUNT(*)-COUNT(DISTINCT call_id)
FROM clean_calls
UNION ALL
SELECT 'whatsapp_unique',
       CASE WHEN COUNT(*) = COUNT(DISTINCT whatsapp_event_id) THEN 'PASS' ELSE 'FAIL' END,
       COUNT(*), COUNT(*)-COUNT(DISTINCT whatsapp_event_id)
FROM clean_whatsapp_events
UNION ALL
SELECT 'payments_nonnegative_amount',
       CASE WHEN SUM(amount < 0) = 0 THEN 'PASS' ELSE 'FAIL' END,
       COUNT(*), SUM(amount < 0)
FROM clean_payments
UNION ALL
SELECT 'targeting_account_fk',
       CASE WHEN SUM(a.account_id IS NULL) = 0 THEN 'PASS' ELSE 'FAIL' END,
       COUNT(*), SUM(a.account_id IS NULL)
FROM clean_targeting t LEFT JOIN clean_accounts a ON t.account_id=a.account_id
UNION ALL
SELECT 'payments_account_fk',
       CASE WHEN SUM(a.account_id IS NULL) = 0 THEN 'PASS' ELSE 'FAIL' END,
       COUNT(*), SUM(a.account_id IS NULL)
FROM clean_payments p LEFT JOIN clean_accounts a ON p.account_id=a.account_id
UNION ALL
SELECT 'calls_account_fk',
       CASE WHEN SUM(a.account_id IS NULL) = 0 THEN 'PASS' ELSE 'FAIL' END,
       COUNT(*), SUM(a.account_id IS NULL)
FROM clean_calls c LEFT JOIN clean_accounts a ON c.account_id=a.account_id;

-- Golden row-count contract = accounts x observed months.
WITH expected AS (
  SELECT
    (SELECT COUNT(*) FROM clean_accounts) *
    (SELECT COUNT(DISTINCT month_start) FROM golden_account_month) AS expected_rows
), actual AS (
  SELECT COUNT(*) AS actual_rows FROM golden_account_month
)
SELECT
  'golden_account_month_row_count' AS test_name,
  CASE WHEN expected_rows=actual_rows THEN 'PASS' ELSE 'FAIL' END AS result,
  expected_rows,
  actual_rows,
  actual_rows-expected_rows AS difference
FROM expected CROSS JOIN actual;

-- Completeness check: latest month should be visibly flagged if partial.
SELECT
  month_start,
  MAX(observed_through) AS observed_through,
  MAX(is_complete_month) AS is_complete_month,
  CASE
    WHEN MAX(is_complete_month)=1 THEN 'FULL_MONTH'
    ELSE 'MTD_INCOMPLETE'
  END AS month_status
FROM golden_account_month
GROUP BY month_start
ORDER BY month_start;

-- Critical quality conditions that deliberately fail in this synthetic dataset
-- are reported rather than used to abort ingestion.
SELECT
  'call_attempt_link_integrity' AS quality_check,
  valid_link_rate,
  CASE WHEN valid_link_rate >= 0.95 THEN 'USABLE' ELSE 'UNRELIABLE_FOR_ATTRIBUTION' END AS decision
FROM dq_call_link_integrity WHERE dataset='call_attempts'
UNION ALL
SELECT
  'call_disposition_link_integrity', valid_link_rate,
  CASE WHEN valid_link_rate >= 0.95 THEN 'USABLE' ELSE 'UNRELIABLE_FOR_ATTRIBUTION' END
FROM dq_call_link_integrity WHERE dataset='call_dispositions';
