DROP VIEW IF EXISTS protection_by_month_view;

CREATE VIEW protection_by_month_view
AS
WITH info
AS
(
  SELECT
    chain_id,
    expires_on,
    cover_duration AS duration,
    to_char(to_timestamp(expires_on), 'Mon-YY') AS expiry,
    SUM(get_stablecoin_value(chain_id, amount_to_cover)) AS protection,
    SUM(get_stablecoin_value(chain_id, fee)) AS income,
    to_timestamp(expires_on) < NOW() AS expired
  FROM policy.cover_purchased
  GROUP BY chain_id, expires_on, duration
  ORDER BY chain_id, expires_on DESC
),
summary
AS
(  
  SELECT
    chain_id,
    to_timestamp(expires_on) AS expires_on,
    expiry,
    duration,
    protection,
    income,
    expired,
    ((income * 12) / (protection * duration)) AS fee_rate
  FROM info
),
result
AS
(
  SELECT
    chain_id,
    expires_on,
    expiry,
    SUM(protection) AS protection,
    SUM(income) AS income,
    expired,
    AVG(fee_rate) AS fee_rate
  FROM summary
  GROUP BY chain_id, expires_on, expiry, expired
)
SELECT
  result.chain_id,
  config_blockchain_network_view.network_name,
  result.expires_on,
  result.expiry,
  result.protection,
  result.income,
  result.expired,
  result.fee_rate
FROM result
INNER JOIN config_blockchain_network_view
ON config_blockchain_network_view.chain_id = result.chain_id;

