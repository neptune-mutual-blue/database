DROP VIEW IF EXISTS my_liquidity_view;

CREATE VIEW my_liquidity_view
AS
WITH liquidity_add_txs
AS
(
  SELECT
    vault.pods_issued.chain_id,
    vault.pods_issued.address                   AS vault,
    get_cover_key_by_vault_address
    (
      vault.pods_issued.chain_id,
      vault.pods_issued.address
    )                                           AS cover_key,
    vault.pods_issued.block_timestamp,
    vault.pods_issued.transaction_hash,
    vault.pods_issued.account                   AS account,
    vault.pods_issued.issued                    AS pod_amount,
    vault.npm_staken.amount                     AS npm_amount,
    vault.pods_issued.liquidity_added           AS stablecoin_amount,
    'add'                                       AS tx_type
  FROM vault.pods_issued
  INNER JOIN vault.npm_staken
  ON vault.npm_staken.chain_id                  = vault.pods_issued.chain_id
  AND vault.npm_staken.address                  = vault.pods_issued.address
  AND vault.npm_staken.block_timestamp          = vault.pods_issued.block_timestamp
  AND vault.npm_staken.transaction_hash         = vault.pods_issued.transaction_hash
  AND vault.npm_staken.account                  = vault.pods_issued.account
),
liquidity_remove_txs
AS
(
  SELECT
    vault.pods_redeemed.chain_id,
    vault.pods_redeemed.address                 AS vault,
    get_cover_key_by_vault_address
    (
      vault.pods_redeemed.chain_id,
      vault.pods_redeemed.address
    )                                           AS cover_key,
    vault.pods_redeemed.block_timestamp,
    vault.pods_redeemed.transaction_hash,
    vault.pods_redeemed.account                 AS account,
    vault.pods_redeemed.redeemed                AS pod_amount,
    COALESCE(vault.npm_unstaken.amount, 0)      AS npm_amount,
    vault.pods_redeemed.liquidity_released      AS stablecoin_amount,
    'remove'                                    AS tx_type
  FROM vault.pods_redeemed
  LEFT JOIN vault.npm_unstaken
  ON vault.npm_unstaken.chain_id                = vault.pods_redeemed.chain_id
  AND vault.npm_unstaken.address                = vault.pods_redeemed.address
  AND vault.npm_unstaken.block_timestamp        = vault.pods_redeemed.block_timestamp
  AND vault.npm_unstaken.transaction_hash       = vault.pods_redeemed.transaction_hash
  AND vault.npm_unstaken.account                = vault.pods_redeemed.account
),
liquidity_txs
AS
(
  SELECT *, get_products_of(chain_id, cover_key) AS product_keys FROM liquidity_add_txs
  UNION ALL
  SELECT *, get_products_of(chain_id, cover_key) AS product_keys FROM liquidity_remove_txs
)
SELECT
  liquidity_txs.chain_id,
  liquidity_txs.vault,
  liquidity_txs.cover_key,
  liquidity_txs.block_timestamp,
  liquidity_txs.transaction_hash,
  liquidity_txs.account,
  liquidity_txs.pod_amount,
  liquidity_txs.npm_amount,
  liquidity_txs.stablecoin_amount,
  liquidity_txs.tx_type,
  factory.vault_deployed.name                         AS token_name,
  factory.vault_deployed.symbol                       AS token_symbol,
  liquidity_txs.product_keys
FROM liquidity_txs
INNER JOIN factory.vault_deployed
ON factory.vault_deployed.chain_id                    = liquidity_txs.chain_id
AND factory.vault_deployed.cover_key                  = liquidity_txs.cover_key
AND factory.vault_deployed.vault                      = liquidity_txs.vault;