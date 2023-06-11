CREATE OR REPLACE FUNCTION get_gauge_pool_last_added_block_number(_chain_id numeric, _key bytes32)
RETURNS numeric
STABLE
AS
$$
  DECLARE _last_deleted_block_number                    numeric;
  DECLARE _min_block_number                             numeric;
BEGIN
  SELECT MAX(ve.gauge_controller_registry_pool_deleted.block_number::numeric)
  INTO _last_deleted_block_number
  FROM ve.gauge_controller_registry_pool_deleted
  WHERE ve.gauge_controller_registry_pool_deleted.chain_id = _chain_id
  AND ve.gauge_controller_registry_pool_deleted.key = _key;

  RETURN MIN(ve.liquidity_gauge_pool_set.block_number::numeric)
  FROM ve.liquidity_gauge_pool_set
  WHERE ve.liquidity_gauge_pool_set.chain_id = _chain_id
  AND ve.liquidity_gauge_pool_set.key = _key
  AND ve.liquidity_gauge_pool_set.block_number::numeric > COALESCE(_last_deleted_block_number, 0);
END
$$
LANGUAGE plpgsql;