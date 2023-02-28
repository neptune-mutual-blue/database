DROP VIEW IF EXISTS fee_earned_by_chain_view;

CREATE VIEW fee_earned_by_chain_view
AS
SELECT
  chain_id,
  SUM(fee) AS total_fee
FROM policy.cover_purchased
GROUP BY chain_id;

