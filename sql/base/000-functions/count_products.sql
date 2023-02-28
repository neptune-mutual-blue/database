DROP FUNCTION IF EXISTS count_products
(
  _chain_id                           numeric,
  _cover_key                          text
) CASCADE;

CREATE FUNCTION count_products
(
  _chain_id                           numeric,
  _cover_key                          text
)
RETURNS integer
STABLE
AS
$$
BEGIN
  RETURN COUNT(product_key)
  FROM config_product_view
  WHERE chain_id = _chain_id
  AND cover_key = _cover_key;
END
$$
LANGUAGE plpgsql;
