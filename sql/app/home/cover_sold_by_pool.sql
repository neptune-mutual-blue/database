DROP VIEW IF EXISTS cover_sold_by_pool_view;

CREATE VIEW cover_sold_by_pool_view
AS
SELECT
  cover_key,
  bytes32_to_string(cover_key) AS cover_key_string,
  product_key,
  bytes32_to_string(product_key) AS product_key_string,
  SUM(get_stablecoin_value(chain_id, amount_to_cover)) AS total_protection
FROM policy.cover_purchased
GROUP BY cover_key, product_key;

