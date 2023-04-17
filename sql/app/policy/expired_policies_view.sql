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
    cx_token,
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
  bytes32_to_string(cover_key)            AS cover_key_string,
  product_key,
  bytes32_to_string(product_key)          AS product_key_string,
  cx_token,
  expires_on,
  on_behalf_of,
  SUM(amount_to_cover)                    AS amount,
  incident_date,
  get_product_status
  (
      chain_id,
      cover_key,
      product_key,
      incident_date
  )                                       AS product_status_enum,
  array_length(
    enum_range(
      NULL,  
      get_product_status
      (
          chain_id,
          cover_key,
          product_key,
          incident_date
      )
    ),
    1
  ) - 1                                         AS product_status,
  (get_cover_info(chain_id, cover_key)).*,
  (get_product_info(chain_id, cover_key, product_key)).*
FROM summary
GROUP BY
  chain_id,
  cover_key,
  product_key,
  on_behalf_of,
  cx_token,
  expires_on, 
  incident_date;

-- SELECT * FROM expired_policies_view
-- WHERE on_behalf_of = '0x201bcc0d375f10543e585fbb883b36c715c959b3'
-- AND chain_id = 84531