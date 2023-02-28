DROP VIEW IF EXISTS total_platform_fee_earned_view;

CREATE VIEW total_platform_fee_earned_view
AS
SELECT
  chain_id,
  cover_key,
  SUM(platform_fee) AS total_platform_fee
FROM policy.cover_purchased
GROUP BY chain_id, cover_key;

