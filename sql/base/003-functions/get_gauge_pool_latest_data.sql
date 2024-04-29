CREATE OR REPLACE FUNCTION get_gauge_pool_latest_data(_chain_id uint256, _pool_address address)
RETURNS TABLE
(
  chain_id                                          uint256,
  key                                               bytes32,
  staking_token                                     address,
  ve_token                                          address,
  reward_token                                      address,
  registry                                          address,
  name                                              text,
  info                                              text,
  epoch_duration                                    uint256,
  ve_boost_ratio                                    uint256,
  platform_fee                                      uint256,
  treasury                                          address,
  last_updated_at                                   integer
)
AS
$$
BEGIN
  RETURN QUERY
  WITH latest_pool_updated
  AS
  (
    SELECT
      ve.liquidity_gauge_pool_set.chain_id,
      ve.liquidity_gauge_pool_set.name,
      ve.liquidity_gauge_pool_set.info,
      ve.liquidity_gauge_pool_set.epoch_duration,
      ve.liquidity_gauge_pool_set.ve_boost_ratio,
      ve.liquidity_gauge_pool_set.platform_fee,
      ve.liquidity_gauge_pool_set.treasury,
      ve.liquidity_gauge_pool_set.address,
      ve.liquidity_gauge_pool_set.block_timestamp
    FROM ve.liquidity_gauge_pool_set
    WHERE 1 = 1
    AND ve.liquidity_gauge_pool_set.address = _pool_address
    AND ve.liquidity_gauge_pool_set.chain_id = _chain_id
    ORDER BY ve.liquidity_gauge_pool_set.block_timestamp DESC
    LIMIT 1
  ),
  latest_epoch_duration_updated
  AS
  (
    SELECT
      ve.epoch_duration_updated.chain_id,
      ve.epoch_duration_updated.current AS epoch_duration,
      ve.epoch_duration_updated.address,
      ve.epoch_duration_updated.block_timestamp
    FROM ve.epoch_duration_updated
    WHERE 1 = 1
    AND ve.epoch_duration_updated.address = _pool_address
    AND ve.epoch_duration_updated.chain_id = _chain_id
    ORDER BY ve.epoch_duration_updated.block_timestamp DESC
    LIMIT 1
  )
  SELECT
    ve.liquidity_gauge_pool_initialized.chain_id,
    ve.liquidity_gauge_pool_initialized.key,
    ve.liquidity_gauge_pool_initialized.staking_token,
    ve.liquidity_gauge_pool_initialized.ve_token,
    ve.liquidity_gauge_pool_initialized.reward_token,
    ve.liquidity_gauge_pool_initialized.registry,
    ve.liquidity_gauge_pool_initialized.name,
    ve.liquidity_gauge_pool_initialized.info,
    CASE
      WHEN COALESCE(latest_pool_updated.block_timestamp, 0) > COALESCE(latest_epoch_duration_updated.block_timestamp, 0)
      THEN latest_pool_updated.epoch_duration
      ELSE latest_epoch_duration_updated.epoch_duration
    END AS epoch_duration,
    latest_pool_updated.ve_boost_ratio,
    latest_pool_updated.platform_fee,
    latest_pool_updated.treasury,
    GREATEST(latest_pool_updated.block_timestamp, latest_epoch_duration_updated.block_timestamp) AS last_updated_at
  FROM ve.liquidity_gauge_pool_initialized
  LEFT JOIN latest_pool_updated
  ON ve.liquidity_gauge_pool_initialized.address = latest_pool_updated.address
  AND ve.liquidity_gauge_pool_initialized.chain_id = latest_pool_updated.chain_id  
  LEFT JOIN latest_epoch_duration_updated
  ON ve.liquidity_gauge_pool_initialized.address = latest_epoch_duration_updated.address
  AND ve.liquidity_gauge_pool_initialized.chain_id = latest_epoch_duration_updated.chain_id
  WHERE 1 = 1
  AND ve.liquidity_gauge_pool_initialized.address = _pool_address
  AND ve.liquidity_gauge_pool_initialized.chain_id = _chain_id;
END
$$
LANGUAGE plpgsql;

ALTER FUNCTION get_gauge_pool_latest_data(_chain_id uint256, _pool_address address) OWNER TO writeuser;

ALTER TABLE ve.liquidity_gauge_pool_set OWNER TO writeuser;
ALTER TABLE ve.epoch_duration_updated OWNER TO writeuser;
ALTER TABLE ve.liquidity_gauge_pool_initialized OWNER TO writeuser;
