DROP VIEW IF EXISTS active_policies_view;

CREATE VIEW active_policies_view
AS
SELECT
  chain_id,
  cover_key,
  bytes32_to_string(cover_key)                                                                        AS cover_key_string,
  product_key,
  bytes32_to_string(product_key)                                                                      AS product_key_string,
  cx_token,
  expires_on,
  on_behalf_of,
  SUM(amount_to_cover),
  get_active_product_status(chain_id, cover_key, product_key)                                         AS product_status_enum,
  array_length(enum_range(NULL,  get_active_product_status(chain_id, cover_key, product_key)), 1) - 1 AS product_status,
  (get_cover_info(chain_id, cover_key)).*,
  (get_product_info(chain_id, cover_key, product_key)).*
FROM policy.cover_purchased
WHERE expires_on > extract(epoch FROM NOW() AT TIME ZONE 'UTC')
GROUP BY 
  chain_id,
  cover_key,
  product_key,
  cx_token,
  expires_on,
  on_behalf_of;
