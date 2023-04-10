CREATE OR REPLACE FUNCTION get_products_of 
(
  _chain_id             uint256,
  _cover_key            bytes32
)
RETURNS jsonb
AS
$$
BEGIN
  RETURN jsonb_agg(product_key) FROM config_product_view
  WHERE chain_id = _chain_id
  AND cover_key  = _cover_key;
END
$$
LANGUAGE plpgsql;

-- SELECT * FROM get_products_of(43113, string_to_bytes32('prime'))