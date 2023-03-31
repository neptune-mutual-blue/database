DROP VIEW IF EXISTS cover_purchase_view;

CREATE VIEW cover_purchase_view
AS
SELECT
  transaction_hash,
  chain_id,
  cover_key,
  bytes32_to_string(cover_key) AS cover_key_string,
  product_key,
  bytes32_to_string(product_key) AS product_key_string,
  on_behalf_of,
  cover_duration,
  referral_code,
  cx_token,
  fee,
  policy_id,
  expires_on,
  amount_to_cover,
  get_active_product_status(chain_id, cover_key, product_key) AS product_status_enum,
  array_length(enum_range(NULL,  get_active_product_status(chain_id, cover_key, product_key)), 1) - 1 AS product_status,
  (get_cover_info(chain_id, cover_key)).*,
  (get_product_info(chain_id, cover_key, product_key)).*
FROM policy.cover_purchased;


