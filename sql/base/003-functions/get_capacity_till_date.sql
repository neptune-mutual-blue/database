DROP FUNCTION IF EXISTS get_capacity_till_date
(
  _date                                     TIMESTAMP WITH TIME ZONE
) CASCADE;

DROP FUNCTION IF EXISTS get_total_capacity_by_date
(
  _date                                     TIMESTAMP WITH TIME ZONE
) CASCADE;

CREATE OR REPLACE FUNCTION get_total_capacity_by_date
(
  _date                                     TIMESTAMP WITH TIME ZONE
)
RETURNS uint256
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
    WHERE cover_key IS NOT NULL
  ),
  summary
  AS
  (
    SELECT
      chain_id,
      cover_key,
      bytes32_to_string(cover_key) AS cover,
      is_diversified(chain_id, cover_key) AS diversified,
      product_key,
      bytes32_to_string(product_key) AS product,
      get_cover_capacity_till(chain_id, cover_key, product_key, 'infinity') AS capacity,
      format_stablecoin(get_cover_capacity_till(chain_id, cover_key, product_key, 'infinity')) AS formatted_capacity
    FROM products
  )
  SELECT SUM(capacity)
  INTO _capacity
  FROM summary
  WHERE 1 = 1
  AND NOT (diversified = true AND product_key != string_to_bytes32(''))
  ORDER BY product;

  RETURN COALESCE(_capacity, 0);
END
$$
LANGUAGE plpgsql;


--SELECT get_total_capacity_by_date('infinity')