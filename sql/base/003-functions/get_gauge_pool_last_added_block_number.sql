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

  RETURN MIN(ve.gauge_controller_registry_pool_added_or_edited.block_number::numeric)
  FROM ve.gauge_controller_registry_pool_added_or_edited
  WHERE ve.gauge_controller_registry_pool_added_or_edited.chain_id = _chain_id
  AND ve.gauge_controller_registry_pool_added_or_edited.key = _key
  AND ve.gauge_controller_registry_pool_added_or_edited.block_number::numeric > COALESCE(_last_deleted_block_number, 0);
END
$$
LANGUAGE plpgsql;