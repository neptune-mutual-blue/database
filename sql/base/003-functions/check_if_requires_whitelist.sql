DROP FUNCTION IF EXISTS check_if_requires_whitelist(_chain_id uint256, _cover_key bytes32);

CREATE FUNCTION check_if_requires_whitelist(_chain_id uint256, _cover_key bytes32)
RETURNS boolean
STABLE
AS
$$
BEGIN
  RETURN requires_whitelist
  FROM cover.cover_created
  WHERE cover.cover_created.chain_id = _chain_id
  AND cover.cover_created.cover_key = _cover_key;
END
$$
LANGUAGE plpgsql;


