DROP FUNCTION IF EXISTS get_policy_status
(
  _chain_id                                   uint256,
  _cover_key                                  bytes32,
  _product_key                                bytes32
) CASCADE;

CREATE FUNCTION get_policy_status
(
  _chain_id                                   uint256,
  _cover_key                                  bytes32,
  _product_key                                bytes32
)
RETURNS TABLE
(
  disabled                                   bool,
  reason                                     text
)
STABLE
AS
$$
  DECLARE _disabled                           bool;
  DECLARE _reason                             text;
BEGIN
  IF(_product_key IS NULL) THEN
    _product_key := string_to_bytes32('');
  END IF;

  SELECT cover.product_state_updated.status, cover.product_state_updated.reason
  INTO _disabled, _reason
  FROM cover.product_state_updated
  WHERE cover.product_state_updated.chain_id = _chain_id
  AND cover.product_state_updated.cover_key = _cover_key
  AND cover.product_state_updated.product_key = _product_key
  ORDER BY cover.product_state_updated.block_timestamp DESC
  LIMIT 1;

  RETURN QUERY
  SELECT COALESCE(_disabled, false), COALESCE(_reason, '');
END
$$
LANGUAGE plpgsql;

-- SELECT * FROM get_policy_status(80001, string_to_bytes32('coinbase'), string_to_bytes32(''));
-- SELECT * FROM get_policy_status(80001, string_to_bytes32('defi'), string_to_bytes32('kyberswap-v1'));

