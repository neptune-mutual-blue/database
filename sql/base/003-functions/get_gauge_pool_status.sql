CREATE OR REPLACE FUNCTION get_gauge_pool_status(_chain_id uint256, _pool_key bytes32)
RETURNS TABLE
(
  pool_address                                      address,
  active                                            boolean
)
AS
$$
BEGIN
  RETURN QUERY
  WITH latest_added
  AS
  (
    SELECT
      ve.liquidity_gauge_pool_added.key,
      ve.liquidity_gauge_pool_added.pool AS address,
      ve.liquidity_gauge_pool_added.block_timestamp
    FROM ve.liquidity_gauge_pool_added
    WHERE 1 = 1
    AND ve.liquidity_gauge_pool_added.chain_id = _chain_id
    AND ve.liquidity_gauge_pool_added.key = _pool_key
    ORDER BY ve.liquidity_gauge_pool_added.block_timestamp DESC
    LIMIT 1
  ),
  latest_activated
  AS
  (
    SELECT
      ve.gauge_controller_registry_pool_activated.key,
      ve.gauge_controller_registry_pool_activated.block_timestamp
    FROM ve.gauge_controller_registry_pool_activated
    WHERE 1 = 1
    AND ve.gauge_controller_registry_pool_activated.chain_id = _chain_id
    AND ve.gauge_controller_registry_pool_activated.key = _pool_key
    ORDER BY ve.gauge_controller_registry_pool_activated.block_timestamp DESC
    LIMIT 1
  ),
  latest_deactivated
  AS
  (
    SELECT
      ve.gauge_controller_registry_pool_deactivated.key,
      ve.gauge_controller_registry_pool_deactivated.block_timestamp
    FROM ve.gauge_controller_registry_pool_deactivated
    WHERE 1 = 1
    AND ve.gauge_controller_registry_pool_deactivated.chain_id = _chain_id
    AND ve.gauge_controller_registry_pool_deactivated.key = _pool_key
    ORDER BY ve.gauge_controller_registry_pool_deactivated.block_timestamp DESC
    LIMIT 1
  ),
  latest_deleted
  AS
  (
    SELECT
      ve.gauge_controller_registry_pool_deleted.key,
      ve.gauge_controller_registry_pool_deleted.block_timestamp
    FROM ve.gauge_controller_registry_pool_deleted
    WHERE 1 = 1
    AND ve.gauge_controller_registry_pool_deleted.chain_id = _chain_id
    AND ve.gauge_controller_registry_pool_deleted.key = _pool_key
    ORDER BY ve.gauge_controller_registry_pool_deleted.block_timestamp DESC
    LIMIT 1
  ),
  latest_updated
  AS
  (
    SELECT
      ve.liquidity_gauge_pool_updated.key,
      ve.liquidity_gauge_pool_updated.current AS address,
      ve.liquidity_gauge_pool_updated.block_timestamp
    FROM ve.liquidity_gauge_pool_updated
    WHERE 1 = 1
    AND ve.liquidity_gauge_pool_updated.chain_id = _chain_id
    AND ve.liquidity_gauge_pool_updated.key = _pool_key
    ORDER BY ve.liquidity_gauge_pool_updated.block_timestamp DESC
    LIMIT 1
  )
  SELECT
    CASE
      WHEN COALESCE(latest_updated.block_timestamp, 0) > COALESCE(latest_added.block_timestamp, 0)
      THEN latest_updated.address
      ELSE latest_added.address
    END AS pool_address,
    COALESCE(latest_deactivated.block_timestamp, 0) < 
    GREATEST
    (
      latest_added.block_timestamp,
      COALESCE(latest_updated.block_timestamp, 0),
      COALESCE(latest_activated.block_timestamp, 0)
    ) AS active
  FROM latest_added
  FULL OUTER JOIN latest_updated
  ON latest_added.key = latest_updated.key
  LEFT JOIN latest_activated
  ON latest_added.key = latest_activated.key
  LEFT JOIN latest_deactivated
  ON latest_added.key = latest_deactivated.key
  LEFT JOIN latest_deleted
  ON latest_added.key = latest_deleted.key
  WHERE COALESCE(latest_deleted.block_timestamp, 0) <
  GREATEST
  (
    latest_added.block_timestamp,
    COALESCE(latest_updated.block_timestamp, 0)
  );
END
$$
LANGUAGE plpgsql;

ALTER FUNCTION get_gauge_pool_status(_chain_id uint256, _pool_key bytes32) OWNER TO writeuser;

ALTER TABLE ve.gauge_controller_registry_pool_activated OWNER TO writeuser;
ALTER TABLE ve.gauge_controller_registry_pool_deactivated OWNER TO writeuser;
ALTER TABLE ve.gauge_controller_registry_pool_deleted OWNER TO writeuser;
ALTER TABLE ve.liquidity_gauge_pool_updated OWNER TO writeuser;
