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
BEGIN
  RETURN QUERY
  SELECT
    cover.cover_created.info,
    config_known_ipfs_hashes_view.ipfs_details
  FROM cover.cover_created
  INNER JOIN config_known_ipfs_hashes_view
  ON config_known_ipfs_hashes_view.ipfs_hash = cover.cover_created.info
  WHERE cover.cover_created.chain_id = _chain_id
  AND cover.cover_created.cover_key = _cover_key;
END
$$
LANGUAGE plpgsql;

--SELECT * FROM get_cover_info(1, string_to_bytes32('popular-defi-apps'));


