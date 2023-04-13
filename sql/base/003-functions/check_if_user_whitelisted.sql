DROP FUNCTION IF EXISTS check_if_user_whitelisted
(
  _chain_id                                         uint256,
  _cover_key                                        bytes32,
  _product_key                                      bytes32,
  _account                                          address
) CASCADE;


CREATE FUNCTION check_if_user_whitelisted
(
  _chain_id                                         uint256,
  _cover_key                                        bytes32,
  _product_key                                      bytes32,
  _account                                          address
)
RETURNS BOOLEAN
STABLE
AS
$$
  DECLARE _status                                   boolean;
BEGIN
  IF(_product_key IS NULL) THEN
    _product_key := string_to_bytes32('');
  END IF;

  SELECT status INTO _status
  FROM cover.cover_user_whitelist_updated
  WHERE cover.cover_user_whitelist_updated.chain_id = _chain_id
  AND cover.cover_user_whitelist_updated.cover_key = _cover_key
  AND cover.cover_user_whitelist_updated.product_key = _product_key
  AND cover.cover_user_whitelist_updated.account = _account 
  ORDER BY cover.cover_user_whitelist_updated.block_timestamp DESC
  LIMIT 1;

  RETURN COALESCE(_status, false);
END
$$
LANGUAGE plpgsql;


--SELECT * FROM check_if_user_whitelisted(84531, '0x62696e616e636500000000000000000000000000000000000000000000000000', '0x0000000000000000000000000000000000000000000000000000000000000000', '0x0000000000000000000000000000000000000001');
