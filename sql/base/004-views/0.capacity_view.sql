CREATE OR REPLACE VIEW capacity_view
AS
WITH chains
AS
(
  SELECT DISTINCT core.transactions.chain_id
  FROM core.transactions
),
unfiltered
AS
(
  SELECT chain_id, cover_key, product_key
  FROM config_product_view
  WHERE config_product_view.chain_id IN
  (
    SELECT chain_id FROM chains
  )
  UNION ALL
  SELECT  chain_id, cover_key, string_to_bytes32('') FROM config_cover_view
  WHERE config_cover_view.chain_id IN
  (
    SELECT chain_id FROM chains
  )
),
products
AS
(
  SELECT DISTINCT chain_id, cover_key, product_key
  FROM unfiltered
  WHERE COALESCE(cover_key, string_to_bytes32('')) != string_to_bytes32('')
  AND 
  (
    COALESCE(product_key, string_to_bytes32('')) != string_to_bytes32('')
    OR NOT is_diversified(chain_id, cover_key)
  )
)
SELECT
  chain_id,
  cover_key,
  bytes32_to_string(cover_key) AS cover,
  is_diversified(chain_id, cover_key) AS diversified,
  product_key,
  bytes32_to_string(product_key) AS product,
  get_cover_capacity_till(chain_id, cover_key, product_key, 'infinity') AS capacity
FROM products;

ALTER VIEW capacity_view OWNER TO writeuser;
