DROP VIEW IF EXISTS gauge_pool_lifecycle_view;

CREATE VIEW gauge_pool_lifecycle_view
AS
SELECT
  add_or_edit.id,
  add_or_edit.block_number,
  add_or_edit.chain_id,
  CASE
    WHEN get_gauge_pool_last_added_block_number(add_or_edit.chain_id, add_or_edit.key) != add_or_edit.block_number::numeric
    THEN 'edit'
    ELSE 'add'
  END AS action,
  add_or_edit.key
FROM ve.liquidity_gauge_pool_set AS add_or_edit
UNION ALL
SELECT
  ve.gauge_controller_registry_pool_deactivated.id,
  ve.gauge_controller_registry_pool_deactivated.block_number,
  ve.gauge_controller_registry_pool_deactivated.chain_id,
  'deactivate' AS action,
  ve.gauge_controller_registry_pool_deactivated.key
FROM ve.gauge_controller_registry_pool_deactivated
UNION ALL
SELECT
  ve.gauge_controller_registry_pool_activated.id,
  ve.gauge_controller_registry_pool_activated.block_number,
  ve.gauge_controller_registry_pool_activated.chain_id,
  'activate' AS action,
  ve.gauge_controller_registry_pool_activated.key
FROM ve.gauge_controller_registry_pool_activated
UNION ALL
SELECT
  ve.gauge_controller_registry_pool_deleted.id,
  ve.gauge_controller_registry_pool_deleted.block_number,
  ve.gauge_controller_registry_pool_deleted.chain_id,
  'delete' AS action,
  ve.gauge_controller_registry_pool_deleted.key
FROM ve.gauge_controller_registry_pool_deleted;