DROP VIEW IF EXISTS cover_capacity_view;

CREATE VIEW cover_capacity_view
AS
WITH intermediate
AS
(
  SELECT
    chain_id,
    cover_key,
    (get_capital_efficiency(chain_id, cover_key)).*,
    SUM(total) AS total
  FROM stablecoin_transactions_view
  GROUP BY chain_id, cover_key
),
summary
AS
(
SELECT
  chain_id,
  cover_key,
  total,
  leverage_factor,
  COALESCE(average_capital_efficiency, 10000) AS capital_efficiency
FROM intermediate
)
SELECT
  chain_id,
  cover_key,
  total * leverage_factor * (capital_efficiency / 10000) as capacity
FROM summary;

