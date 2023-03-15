DROP VIEW IF EXISTS cover_premium_by_pool;

CREATE VIEW cover_premium_by_pool
AS
SELECT
  cover_key,
  bytes32_to_string(cover_key) AS cover_key_string,
  product_key,
  bytes32_to_string(product_key) AS product_key_string,
  SUM(fee) AS total_premium
FROM policy.cover_purchased
GROUP BY cover_key, product_key;

