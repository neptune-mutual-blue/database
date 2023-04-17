DROP VIEW IF EXISTS top_accounts_by_liquidity_view CASCADE;

CREATE VIEW top_accounts_by_liquidity_view
AS
WITH pool_liquidity
AS
(
  SELECT
    account,
    COUNT(*) AS transactions,
    SUM(get_stablecoin_value(chain_id,liquidity_added)) AS added,
    0 AS removed
  FROM vault.pods_issued
  GROUP BY account
  
  UNION ALL
  
  SELECT
    account,
    COUNT(*) AS transactions,
    0 AS added,
    SUM(get_stablecoin_value(chain_id,liquidity_released)) AS removed
  FROM vault.pods_redeemed
  GROUP BY account
)
SELECT 
  account,
  SUM(transactions) AS transactions,
  SUM(COALESCE(added) - COALESCE(removed)) AS liquidity
FROM pool_liquidity
GROUP BY account
ORDER BY liquidity DESC
LIMIT 10;

