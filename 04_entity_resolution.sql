USE collections_analytics;

-- ============================================================
-- MASTER DATA SURVIVORSHIP / ENTITY RESOLUTION
-- ============================================================

CREATE OR REPLACE VIEW clean_accounts AS
SELECT
  account_id,
  borrower_id,
  loan_type,
  principal_amount,
  outstanding_amount,
  dpd,
  CASE
    WHEN dpd < 30 THEN 'DPD_00_29'
    WHEN dpd < 60 THEN 'DPD_30_59'
    WHEN dpd < 90 THEN 'DPD_60_89'
    WHEN dpd < 180 THEN 'DPD_90_179'
    ELSE 'DPD_180_PLUS'
  END AS dpd_bucket,
  risk_segment,
  status,
  opened_at,
  timezone,
  schema_version
FROM stg_accounts;

CREATE OR REPLACE VIEW clean_borrowers AS
WITH stats AS (
  SELECT
    borrower_id,
    COUNT(*) AS source_row_count,
    COUNT(DISTINCT CONCAT_WS('|',
      COALESCE(name,'<NULL>'), COALESCE(phone,'<NULL>'), COALESCE(email,'<NULL>'),
      COALESCE(city,'<NULL>'), COALESCE(state,'<NULL>')
    )) AS distinct_profile_count
  FROM stg_borrowers
  WHERE borrower_id IS NOT NULL
  GROUP BY borrower_id
), ranked AS (
  SELECT
    b.*,
    ROW_NUMBER() OVER (
      PARTITION BY borrower_id
      ORDER BY COALESCE(updated_at, created_at, '1000-01-01 00:00:00') DESC,
               COALESCE(created_at, '1000-01-01 00:00:00') DESC,
               _row_id DESC
    ) AS rn
  FROM stg_borrowers b
  WHERE borrower_id IS NOT NULL
)
SELECT
  r.borrower_id,
  r.name,
  r.phone,
  r.email,
  r.city,
  r.state,
  r.created_at,
  r.updated_at,
  s.source_row_count,
  s.distinct_profile_count,
  CASE WHEN s.distinct_profile_count > 1 THEN 1 ELSE 0 END AS borrower_conflict_flag
FROM ranked r
JOIN stats s USING (borrower_id)
WHERE r.rn = 1;

CREATE OR REPLACE VIEW clean_agents AS
WITH stats AS (
  SELECT
    agent_id,
    COUNT(*) AS source_row_count,
    COUNT(DISTINCT CONCAT_WS('|',
      COALESCE(employee_code,'<NULL>'), COALESCE(agent_name,'<NULL>'), COALESCE(vendor_id,'<NULL>'),
      COALESCE(team,'<NULL>'), COALESCE(status,'<NULL>'), COALESCE(DATE_FORMAT(joined_at,'%Y-%m-%d %H:%i:%s'),'<NULL>')
    )) AS distinct_profile_count
  FROM stg_agents
  WHERE agent_id IS NOT NULL
  GROUP BY agent_id
), ranked AS (
  SELECT
    a.*,
    ROW_NUMBER() OVER (
      PARTITION BY agent_id
      ORDER BY COALESCE(updated_at, joined_at, '1000-01-01 00:00:00') DESC,
               COALESCE(joined_at, '1000-01-01 00:00:00') DESC,
               _row_id DESC
    ) AS rn
  FROM stg_agents a
  WHERE agent_id IS NOT NULL
)
SELECT
  r.agent_id,
  r.employee_code,
  r.agent_name,
  r.vendor_id,
  r.team,
  r.status,
  r.joined_at,
  r.updated_at,
  s.source_row_count,
  s.distinct_profile_count,
  CASE WHEN s.distinct_profile_count > 1 THEN 1 ELSE 0 END AS agent_conflict_flag
FROM ranked r
JOIN stats s USING (agent_id)
WHERE r.rn = 1;

CREATE OR REPLACE VIEW clean_campaigns AS
SELECT
  campaign_id,
  campaign_name,
  channel,
  strategy_version,
  start_at,
  target_definition,
  end_at
FROM stg_campaigns;

CREATE OR REPLACE VIEW clean_vendors AS
SELECT
  vendor_id,
  vendor_name,
  vendor_account_id,
  timezone,
  status,
  schema_version
FROM stg_vendor_telephony;

CREATE OR REPLACE VIEW dim_account AS
SELECT
  a.account_id,
  a.borrower_id,
  a.loan_type,
  a.principal_amount,
  a.outstanding_amount,
  a.dpd,
  a.dpd_bucket,
  a.risk_segment,
  a.status AS account_status,
  a.opened_at,
  a.timezone AS account_timezone,
  a.schema_version,
  b.name AS borrower_name,
  b.city,
  b.state,
  b.borrower_conflict_flag,
  b.source_row_count AS borrower_master_versions
FROM clean_accounts a
LEFT JOIN clean_borrowers b
  ON a.borrower_id = b.borrower_id;
