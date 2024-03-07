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
  WITH result AS (
    SELECT
      cover.cover_updated.info,
      config_known_ipfs_hashes_view.ipfs_details,
      cover.cover_updated.block_timestamp
    FROM cover.cover_updated
    INNER JOIN config_known_ipfs_hashes_view
    ON config_known_ipfs_hashes_view.ipfs_hash = cover.cover_updated.info
    WHERE cover.cover_updated.chain_id = _chain_id
    AND cover.cover_updated.cover_key = _cover_key
    UNION
    SELECT
      cover.cover_created.info,
      config_known_ipfs_hashes_view.ipfs_details,
      cover.cover_created.block_timestamp
    FROM cover.cover_created
    INNER JOIN config_known_ipfs_hashes_view
    ON config_known_ipfs_hashes_view.ipfs_hash = cover.cover_created.info
    WHERE cover.cover_created.chain_id = _chain_id
    AND cover.cover_created.cover_key = _cover_key
  )
  SELECT 
    info,
    ipfs_details
  FROM result
  ORDER BY block_timestamp DESC
  LIMIT 1;
END
$$
LANGUAGE plpgsql;

-- SELECT * FROM get_cover_info(84531, string_to_bytes32('atlasswap-v1'));
