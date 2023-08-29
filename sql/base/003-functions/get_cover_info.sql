DROP FUNCTION IF EXISTS get_cover_info(_chain_id uint256, _cover_key bytes32);

CREATE FUNCTION get_cover_info(_chain_id uint256, _cover_key bytes32)
RETURNS TABLE
(
  cover_info                          text,
  cover_info_details                  text
)
STABLE
AS
$$
  DECLARE _cover_info                 text;
  DECLARE _cover_info_details         text;
BEGIN
  SELECT cover.cover_created.info
  INTO _cover_info
  FROM cover.cover_created
  WHERE cover.cover_created.chain_id = _chain_id
  AND cover.cover_created.cover_key = _cover_key;

  SELECT config_known_ipfs_hashes_view.ipfs_details
  INTO _cover_info_details
  FROM config_known_ipfs_hashes_view
  WHERE config_known_ipfs_hashes_view.ipfs_hash = _cover_info;

  RETURN QUERY
  SELECT _cover_info, _cover_info_details;
END
$$
LANGUAGE plpgsql;

-- SELECT * FROM get_cover_info(84531, string_to_bytes32('atlasswap-v1'));
