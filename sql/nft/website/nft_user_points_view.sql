CREATE OR REPLACE VIEW nft_user_points_view
AS
WITH policy_purchasers
AS
(
  SELECT
    on_behalf_of                                                        AS account,
    SUM(get_stablecoin_value(chain_id, amount_to_cover))                AS policy
  FROM policy.cover_purchased
  GROUP BY on_behalf_of
),
liquidity_providers
AS
(
  SELECT
    account,
    SUM(get_stablecoin_value(chain_id, liquidity_added))                AS liquidity
  FROM vault.pods_issued
  GROUP BY account
),
points
AS
(
  SELECT
    COALESCE(policy_purchasers.account, liquidity_providers.account)    AS account,
    COALESCE(policy_purchasers.policy, 0)                               AS policy,
    COALESCE(liquidity_providers.liquidity, 0)                          AS liquidity
  FROM policy_purchasers
  FULL OUTER JOIN liquidity_providers
  ON policy_purchasers.account = liquidity_providers.account
),
summary
AS
(
  SELECT
    account,
    policy,
    liquidity,
    FLOOR(policy * 0.00625 + liquidity * 0.0375)                        AS points
  FROM points
)
SELECT 
  account,
  policy,
  liquidity,
  points,
  CASE
    WHEN points >= 50000 THEN 7
    WHEN points >= 25000 THEN 6
    WHEN points >= 10000 THEN 5
    WHEN points >= 7500 THEN 4
    WHEN points >= 5000 THEN 3
    WHEN points >= 1000 THEN 2
    WHEN points >= 100 THEN 1
    WHEN points < 100 THEN 0
  END                                                                   AS level
FROM summary
WHERE points >= 100
ORDER BY points DESC;

