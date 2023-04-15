DROP VIEW IF EXISTS expired_policies_view;

CREATE VIEW expired_policies_view
AS
WITH summary
AS
(
  SELECT
    chain_id,
    cover_key,
    product_key,
    on_behalf_of,
    block_timestamp,
    expires_on,
    get_incident_date_by_expiry_date
    (
      chain_id,
      cover_key,
      product_key,
      block_timestamp,
      expires_on
    )                                     AS incident_date,
    amount_to_cover
  FROM policy.cover_purchased
  WHERE expires_on <= extract(epoch FROM NOW() AT TIME ZONE 'UTC')
)
SELECT
  chain_id,
  cover_key,
  product_key,
  on_behalf_of,
  expires_on, 
  incident_date,
  get_product_status
  (
      chain_id,
      cover_key,
      product_key,
      incident_date
  )                                     AS product_status,
  SUM(amount_to_cover)                  AS amount,
  (get_cover_info(chain_id, cover_key)).*,
  (get_product_info(chain_id, cover_key, product_key)).*
FROM summary
GROUP BY
  chain_id,
  cover_key,
  product_key,
  on_behalf_of,
  expires_on, 
  incident_date;
