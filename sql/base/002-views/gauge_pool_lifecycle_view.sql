CREATE OR REPLACE VIEW gauge_pool_lifecycle_view
AS
SELECT
  ve.liquidity_gauge_pool_initialized.id,
  ve.liquidity_gauge_pool_initialized.block_number,
  ve.liquidity_gauge_pool_initialized.chain_id,
  'add' AS action,
  ve.liquidity_gauge_pool_initialized.key
FROM ve.liquidity_gauge_pool_initialized
UNION ALL
SELECT
	ve.liquidity_gauge_pool_set.id,
  ve.liquidity_gauge_pool_set.block_number,
  ve.liquidity_gauge_pool_set.chain_id,
  'edit' AS action,
  ve.liquidity_gauge_pool_set.key
FROM ve.liquidity_gauge_pool_set
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