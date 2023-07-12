DROP FUNCTION IF EXISTS get_gauge_pools();

CREATE FUNCTION get_gauge_pools()
RETURNS TABLE
(
  chain_id                                          numeric,
  key                                               bytes32,
  epoch_duration                                    uint256,
  pool_address                                      address,
  staking_token                                     address,
  name                                              text,
  info                                              text,
  platform_fee                                      uint256,
  token                                             address,
  lockup_period_in_blocks                           uint256,
  ratio                                             uint256,
  active                                            boolean,
  current_epoch                                     uint256,
  current_distribution                              uint256
)
AS
$$
  DECLARE _r                                        RECORD;
BEGIN
  DROP TABLE IF EXISTS _get_gauge_pools_result;
  CREATE TEMPORARY TABLE _get_gauge_pools_result
  (
    chain_id                                        numeric,
    key                                             bytes32,
    epoch_duration                                  uint256,
    pool_address                                    address,
    staking_token                                   address,
    name                                            text,
    info                                            text,
    platform_fee                                    uint256,
    token                                           address,
    lockup_period_in_blocks                         uint256,
    ratio                                           uint256,    
    active                                          boolean DEFAULT(true),
    current_epoch                                   uint256,
    current_distribution                            uint256
  ) ON COMMIT DROP;

  FOR _r IN
  (
    SELECT *
    FROM gauge_pool_lifecycle_view
    ORDER BY block_number::numeric
  )
  LOOP
    IF(_r.action = 'add') THEN
      INSERT INTO _get_gauge_pools_result
      SELECT
        liquidity_gauge_pool_set.chain_id,
        liquidity_gauge_pool_set.key,
        liquidity_gauge_pool_set.epoch_duration,
        liquidity_gauge_pool_set.address,
        liquidity_gauge_pool_set.staking_token,        
        liquidity_gauge_pool_set.name,
        liquidity_gauge_pool_set.info,
        liquidity_gauge_pool_set.platform_fee,
        liquidity_gauge_pool_set.staking_token,
        liquidity_gauge_pool_set.lockup_period_in_blocks,
        liquidity_gauge_pool_set.ve_boost_ratio
      FROM ve.liquidity_gauge_pool_set
      WHERE liquidity_gauge_pool_set.id = _r.id;
    END IF;
    
    IF(_r.action = 'edit') THEN
      UPDATE _get_gauge_pools_result
      SET 
        name = CASE WHEN COALESCE(liquidity_gauge_pool_set.name, '') = '' THEN _get_gauge_pools_result.name ELSE liquidity_gauge_pool_set.name END,
        info = CASE WHEN COALESCE(liquidity_gauge_pool_set.info, '') = '' THEN _get_gauge_pools_result.info ELSE liquidity_gauge_pool_set.info END,
        platform_fee = CASE WHEN COALESCE(liquidity_gauge_pool_set.platform_fee, 0) = 0 THEN _get_gauge_pools_result.platform_fee ELSE liquidity_gauge_pool_set.platform_fee END,
        lockup_period_in_blocks = CASE WHEN COALESCE(liquidity_gauge_pool_set.lockup_period_in_blocks, 0) = 0 THEN _get_gauge_pools_result.lockup_period_in_blocks ELSE liquidity_gauge_pool_set.lockup_period_in_blocks END,
        ratio = CASE WHEN COALESCE(liquidity_gauge_pool_set.ve_boost_ratio, 0) = 0 THEN _get_gauge_pools_result.ratio ELSE liquidity_gauge_pool_set.ve_boost_ratio END
      FROM ve.liquidity_gauge_pool_set AS liquidity_gauge_pool_set
      WHERE _get_gauge_pools_result.key = liquidity_gauge_pool_set.key
      AND _get_gauge_pools_result.chain_id = liquidity_gauge_pool_set.chain_id
      AND liquidity_gauge_pool_set.id = _r.id;
    END IF;
    
    IF(_r.action = 'deactivate') THEN
      UPDATE _get_gauge_pools_result
      SET active = false
      WHERE _get_gauge_pools_result.chain_id = _r.chain_id
      AND _get_gauge_pools_result.key = _r.key;      
    END IF;

    IF(_r.action = 'activate') THEN
      UPDATE _get_gauge_pools_result
      SET active = true
      WHERE _get_gauge_pools_result.chain_id = _r.chain_id
      AND _get_gauge_pools_result.key = _r.key;      
    END IF;

    IF(_r.action = 'delete') THEN
      DELETE FROM _get_gauge_pools_result
      WHERE _get_gauge_pools_result.chain_id = _r.chain_id
      AND _get_gauge_pools_result.key = _r.key;      
    END IF;
  END LOOP;
  
  --@todo: drop this when address bug of the `ve.liquidity_gauge_pool_set` is fixed
  UPDATE _get_gauge_pools_result
  SET pool_address = ve.liquidity_gauge_pool_added.pool
  FROM ve.liquidity_gauge_pool_added
  WHERE ve.liquidity_gauge_pool_added.chain_id = _get_gauge_pools_result.chain_id
  AND ve.liquidity_gauge_pool_added.key = _get_gauge_pools_result.key
  AND _get_gauge_pools_result.pool_address = '0x0000000000000000000000000000000000000000';
  
  UPDATE _get_gauge_pools_result
  SET
    current_epoch = ve.gauge_set.epoch,
    current_distribution = get_npm_value(ve.gauge_set.distribution)
  FROM ve.gauge_set
  WHERE ve.gauge_set.key = _get_gauge_pools_result.key
  AND ve.gauge_set.chain_id = _get_gauge_pools_result.chain_id
  AND ve.gauge_set.epoch = (SELECT MAX(epoch) FROM ve.gauge_set);
  

  -- @todo: The event EpochDurationUpdated hasn't been synchronized yet  
  -- UPDATE _get_gauge_pools_result
  -- SET epoch_duration =
  -- (
  --   SELECT current
  --   FROM ve.epoch_duration_updated
  --   WHERE ve.epoch_duration_updated.key = _get_gauge_pools_result.key
  --   AND ve.epoch_duration_updated.chain_id = _get_gauge_pools_result.chain_id    
  --   ORDER BY ve.epoch_duration_updated.block_timestamp DESC
  --   LIMIT 1
  -- );
  

  RETURN QUERY
  SELECT * FROM _get_gauge_pools_result;
END
$$
LANGUAGE plpgsql;


SELECT * FROM get_gauge_pools();




