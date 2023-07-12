CREATE OR REPLACE VIEW ve.liquidity_gauge_pool_transactions
AS
SELECT
  ve.liquidity_gauge_deposited.chain_id,
  ve.liquidity_gauge_deposited.block_timestamp,
  ve.liquidity_gauge_deposited.transaction_hash,
  ve.liquidity_gauge_deposited.account,
  'Added' AS event,
  ve.liquidity_gauge_deposited.key,
  ve.liquidity_gauge_deposited.staking_token AS token,
  get_npm_value(ve.liquidity_gauge_deposited.amount) AS amount
FROM ve.liquidity_gauge_deposited
UNION ALL
SELECT
  ve.liquidity_gauge_withdrawn.chain_id,
  ve.liquidity_gauge_withdrawn.block_timestamp,
  ve.liquidity_gauge_withdrawn.transaction_hash,
  ve.liquidity_gauge_withdrawn.account,
  'Removed' AS event,
  ve.liquidity_gauge_withdrawn.key,
  ve.liquidity_gauge_withdrawn.staking_token AS token,
  get_npm_value(ve.liquidity_gauge_withdrawn.amount)
FROM ve.liquidity_gauge_withdrawn
UNION ALL
SELECT
  ve.liquidity_gauge_rewards_withdrawn.chain_id,
  ve.liquidity_gauge_rewards_withdrawn.block_timestamp,
  ve.liquidity_gauge_rewards_withdrawn.transaction_hash,
  ve.liquidity_gauge_rewards_withdrawn.account,
  'Get Reward' AS event,
  ve.liquidity_gauge_rewards_withdrawn.key,
  get_npm(ve.liquidity_gauge_rewards_withdrawn.chain_id) AS token,
  get_npm_value(ve.liquidity_gauge_rewards_withdrawn.rewards - ve.liquidity_gauge_rewards_withdrawn.platform_fee)
FROM ve.liquidity_gauge_rewards_withdrawn;


