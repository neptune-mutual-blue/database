CREATE OR REPLACE FUNCTION get_total_capacity_by_date
(
  _chain_id                                 uint256,
  _date                                     TIMESTAMP WITH TIME ZONE
)
RETURNS numeric
STABLE
AS
$$
  DECLARE _capacity                         uint256;
BEGIN
  WITH chains
  AS
  (
    SELECT DISTINCT core.transactions.chain_id
    FROM core.transactions
    WHERE 1 = 1
    AND (_chain_id IS NULL OR core.transactions.chain_id = _chain_id)
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
  SELECT SUM(get_cover_capacity_till(chain_id, cover_key, product_key, _date))
  INTO _capacity
  FROM products;

  RETURN COALESCE(_capacity, 0);
END
$$
LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION get_total_capacity_by_date
(
  _date                                     TIMESTAMP WITH TIME ZONE
)
RETURNS numeric
STABLE
AS
$$
  DECLARE _capacity                         uint256;
BEGIN
  RETURN get_total_capacity_by_date(NULL, _date);
END
$$
LANGUAGE plpgsql;



ALTER FUNCTION get_total_capacity_by_date(TIMESTAMP WITH TIME ZONE) OWNER TO writeuser;
ALTER FUNCTION get_total_capacity_by_date(uint256, TIMESTAMP WITH TIME ZONE) OWNER TO writeuser;


