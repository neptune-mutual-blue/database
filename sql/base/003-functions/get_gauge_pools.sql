CREATE OR REPLACE FUNCTION get_gauge_pools()
RETURNS TABLE
(
  chain_id                                          numeric,
  key                                               bytes32,
  name                                              text,
  info                                              text,
  platform_fee                                      uint256,
  token                                             address,
  lockup_period_in_blocks                           uint256,
  ratio                                             uint256,
  active                                            boolean
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
    name                                            text,
    info                                            text,
    platform_fee                                    uint256,
    token                                           address,
    lockup_period_in_blocks                         uint256,
    ratio                                           uint256,
    active                                          boolean DEFAULT(true)
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

  RETURN QUERY
  SELECT * FROM _get_gauge_pools_result;
END
$$
LANGUAGE plpgsql;


--SELECT * FROM get_gauge_pools(84531);
