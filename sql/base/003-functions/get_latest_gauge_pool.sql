CREATE OR REPLACE FUNCTION get_latest_gauge_pool(_chain_id numeric, _key bytes32)
RETURNS address
STABLE
AS
$$
  DECLARE _pool address;
BEGIN
  WITH lgps
  AS
  (
    SELECT block_timestamp, address 
    FROM ve.liquidity_gauge_pool_added
    WHERE ve.liquidity_gauge_pool_added.chain_id = _chain_id
    AND ve.liquidity_gauge_pool_added.key = _key

    UNION ALL

    SELECT block_timestamp, current 
    FROM ve.liquidity_gauge_pool_updated
    WHERE ve.liquidity_gauge_pool_updated.chain_id = _chain_id
    AND ve.liquidity_gauge_pool_updated.key = _key
  )
  SELECT address
  INTO _pool
  FROM lgps
  ORDER BY block_timestamp DESC
  LIMIT 1;
  
  RETURN _pool;
END
$$
LANGUAGE plpgsql;
