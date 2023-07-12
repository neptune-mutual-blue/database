DROP VIEW IF EXISTS active_policies_view;

CREATE VIEW active_policies_view
AS
SELECT
  chain_id,
  cover_key,
  bytes32_to_string(cover_key)                                AS cover_key_string,
  product_key,
  bytes32_to_string(product_key)                              AS product_key_string,
  cx_token,
  expires_on,
  on_behalf_of,
  SUM(get_stablecoin_value(chain_id, amount_to_cover))        AS amount,
  get_active_product_status
  (
    chain_id,
    cover_key,
    product_key
  )                                                           AS product_status_enum,
  array_length(
    enum_range(NULL,  get_active_product_status(chain_id, cover_key, product_key)),
    1
  ) - 1                                                       AS product_status,
  (get_cover_info(chain_id, cover_key)).*,
  (get_product_info(chain_id, cover_key, product_key)).*,
  get_active_incident_date(chain_id, cover_key, product_key)  AS incident_date,
  (get_report_insight(
    chain_id,
    cover_key,
    product_key,
    get_active_incident_date(chain_id, cover_key, product_key)
  )).claim_begins_from,
  (get_report_insight(
    chain_id,
    cover_key,
    product_key,
    get_active_incident_date(chain_id, cover_key, product_key)
  )).claim_expires_at
FROM policy.cover_purchased
WHERE expires_on > extract(epoch FROM NOW() AT TIME ZONE 'UTC')
GROUP BY 
  chain_id,
  cover_key,
  product_key,
  cx_token,
  expires_on,
  on_behalf_of;

-- SELECT * FROM active_policies_view
-- WHERE on_behalf_of = '0x201bcc0d375f10543e585fbb883b36c715c959b3'
-- AND chain_id = 84531