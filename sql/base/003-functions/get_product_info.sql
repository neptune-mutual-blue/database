DROP FUNCTION IF EXISTS get_product_info(_chain_id uint256, _cover_key bytes32, _product_key bytes32);

CREATE FUNCTION get_product_info(_chain_id uint256, _cover_key bytes32, _product_key bytes32)
RETURNS TABLE
(
  product_info                          text,
  product_info_details                  text
)
STABLE
AS
$$
BEGIN
  RETURN QUERY
  WITH result AS (
    SELECT
      cover.product_updated.info,
      config_known_ipfs_hashes_view.ipfs_details,
      cover.product_updated.block_timestamp
    FROM cover.product_updated
    INNER JOIN config_known_ipfs_hashes_view
    ON config_known_ipfs_hashes_view.ipfs_hash = cover.product_updated.info
    WHERE cover.product_updated.chain_id = _chain_id
    AND cover.product_updated.cover_key = _cover_key
    AND cover.product_updated.product_key = _product_key
    UNION
    SELECT
      cover.product_created.info,
      config_known_ipfs_hashes_view.ipfs_details,
      cover.product_created.block_timestamp
    FROM cover.product_created
    INNER JOIN config_known_ipfs_hashes_view
    ON config_known_ipfs_hashes_view.ipfs_hash = cover.product_created.info
    WHERE cover.product_created.chain_id = _chain_id
    AND cover.product_created.cover_key = _cover_key
    AND cover.product_created.product_key = _product_key
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

--SELECT * FROM get_product_info(1, string_to_bytes32('popular-defi-apps'), string_to_bytes32('compound-v2'));
