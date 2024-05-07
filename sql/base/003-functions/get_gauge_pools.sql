CREATE OR REPLACE FUNCTION get_gauge_pools()
RETURNS TABLE
(
  chain_id                                          numeric,
  key                                               bytes32,
  epoch_duration                                    uint256,
  pool_address                                      address,
  name                                              text,
  info                                              text,
  info_details                                      text,
  platform_fee                                      uint256,
  reward_token                                      address,
  token                                             address,
  balance                                           uint256,
  lockup_period_in_blocks                           uint256,
  ratio                                             uint256,
  active                                            boolean,
  current_epoch                                     uint256,
  current_distribution                              uint256
)
AS
$$
BEGIN
  DROP TABLE IF EXISTS _get_gauge_pools_result;
  CREATE TEMPORARY TABLE _get_gauge_pools_result
  (
    chain_id                                        numeric,
    key                                             bytes32,
    epoch_duration                                  uint256,
    pool_address                                    address,
    name                                            text,
    info                                            text,
    info_details                                    text,
    platform_fee                                    uint256,
    reward_token                                    address,
    token                                           address,
    balance                                         uint256,
    lockup_period_in_blocks                         uint256,
    ratio                                           uint256,    
    active                                          boolean DEFAULT(true),
    current_epoch                                   uint256,
    current_distribution                            uint256
  ) ON COMMIT DROP;

  INSERT INTO _get_gauge_pools_result(chain_id, key)
  SELECT DISTINCT ve.liquidity_gauge_pool_added.chain_id, ve.liquidity_gauge_pool_added.key
  FROM ve.liquidity_gauge_pool_added;

  UPDATE _get_gauge_pools_result
  SET (pool_address, active) = (SELECT * FROM get_gauge_pool_status(_get_gauge_pools_result.chain_id, _get_gauge_pools_result.key));

  UPDATE _get_gauge_pools_result
  SET lockup_period_in_blocks = 100;

  UPDATE _get_gauge_pools_result
  SET (epoch_duration, reward_token, name, info, platform_fee, token, ratio) = 
  (
    SELECT
      result.epoch_duration,
      result.reward_token,
      result.name,
      result.info,
      result.platform_fee,
      result.staking_token,
      result.ve_boost_ratio
    FROM get_gauge_pool_latest_data(_get_gauge_pools_result.chain_id, _get_gauge_pools_result.pool_address)
    AS result
  );

  UPDATE _get_gauge_pools_result
  SET balance = get_gauge_pool_locked_balance(_get_gauge_pools_result.chain_id, _get_gauge_pools_result.pool_address);
  
  -- ipfs info details
  UPDATE _get_gauge_pools_result
  SET info_details = config_known_ipfs_hashes_view.ipfs_details
  FROM config_known_ipfs_hashes_view
  WHERE 1 = 1
  AND config_known_ipfs_hashes_view.ipfs_hash = _get_gauge_pools_result.info;
  
  -- epoch number & distribution
  UPDATE _get_gauge_pools_result
  SET
    current_epoch           = ve.gauge_set.epoch,
    current_distribution    = get_npm_value(ve.gauge_set.distribution)
  FROM ve.gauge_set
  WHERE 1 = 1
  AND ve.gauge_set.key      = _get_gauge_pools_result.key
  AND ve.gauge_set.chain_id = _get_gauge_pools_result.chain_id
  AND ve.gauge_set.epoch    = (SELECT MAX(epoch) FROM ve.gauge_set);
  
  RETURN QUERY
  SELECT * FROM _get_gauge_pools_result;
END
$$
LANGUAGE plpgsql;

ALTER FUNCTION get_gauge_pools() OWNER TO writeuser;

ALTER TABLE ve.liquidity_gauge_pool_added OWNER TO writeuser;
ALTER TABLE ve.gauge_set OWNER TO writeuser;

ALTER VIEW config_known_ipfs_hashes_view OWNER TO writeuser;

-- SELECT * FROM get_gauge_pools();
