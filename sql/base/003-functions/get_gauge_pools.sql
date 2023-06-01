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
        add_or_edit.chain_id,
        add_or_edit.key,
        add_or_edit.name,
        add_or_edit.info,
        add_or_edit.platform_fee,
        add_or_edit.token,
        add_or_edit.lockup_period_in_blocks,
        add_or_edit.ratio
      FROM ve.gauge_controller_registry_pool_added_or_edited AS add_or_edit
      WHERE add_or_edit.id = _r.id;
    END IF;
    
    IF(_r.action = 'edit') THEN
      UPDATE _get_gauge_pools_result
      SET 
        name = CASE WHEN COALESCE(add_or_edit.name, '') = '' THEN _get_gauge_pools_result.name ELSE add_or_edit.name END,
        info = CASE WHEN COALESCE(add_or_edit.info, '') = '' THEN _get_gauge_pools_result.info ELSE add_or_edit.info END,
        lockup_period_in_blocks = CASE WHEN COALESCE(add_or_edit.lockup_period_in_blocks, 0) = 0 THEN _get_gauge_pools_result.lockup_period_in_blocks ELSE add_or_edit.lockup_period_in_blocks END,
        ratio = CASE WHEN COALESCE(add_or_edit.ratio, 0) = 0 THEN _get_gauge_pools_result.ratio ELSE add_or_edit.ratio END
      FROM ve.gauge_controller_registry_pool_added_or_edited AS add_or_edit
      WHERE _get_gauge_pools_result.key = add_or_edit.key
      AND _get_gauge_pools_result.chain_id = add_or_edit.chain_id
      AND add_or_edit.id = _r.id;
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
