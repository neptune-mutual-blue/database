DROP VIEW IF EXISTS cover_expiring_this_month_view;

CREATE VIEW cover_expiring_this_month_view
AS
SELECT
  cover_key,
  bytes32_to_string(cover_key) AS cover_key_string,
  product_key,
  bytes32_to_string(product_key) AS product_key_string,
  SUM(get_stablecoin_value(chain_id, amount_to_cover)) AS total_protection
FROM policy.cover_purchased
WHERE to_timestamp(expires_on) = 
(
  date_trunc('MONTH', NOW() AT TIME ZONE 'UTC') + INTERVAL '1 MONTH' * 
    CASE
      WHEN EXTRACT(DAY FROM NOW() AT TIME ZONE 'UTC') > 24
      THEN 2
      ELSE 1
    END
    - INTERVAL '1 second'
) AT TIME ZONE 'UTC'
GROUP BY cover_key, product_key;


