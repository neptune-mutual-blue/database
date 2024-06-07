CREATE OR REPLACE VIEW my_liquidity_view
AS
WITH stage1
AS
(
  SELECT
    vault.pods_redeemed.chain_id,
    vault.pods_redeemed.address                                     AS vault_address,
    vault.pods_redeemed.block_timestamp,
    vault.pods_redeemed.transaction_hash,
    vault.pods_redeemed.account,
    vault.pods_redeemed.redeemed                                    AS pod_amount,
    0                                                               AS npm_amount,
    vault.pods_redeemed.liquidity_released                          AS stablecoin_amount,
    'PodsRedeemed'                                                  AS tx_type
  FROM vault.pods_redeemed
  UNION ALL
  SELECT
    vault.pods_issued.chain_id,
    vault.pods_issued.address                                       AS vault_address,
    vault.pods_issued.block_timestamp,
    vault.pods_issued.transaction_hash,
    vault.pods_issued.account,
    vault.pods_issued.issued                                        AS pod_amount,
    0                                                               AS npm_amount,
    vault.pods_issued.liquidity_added                               AS stablecoin_amount,
    'PodsIssued'                                                    AS tx_type
  FROM vault.pods_issued
  UNION ALL
  SELECT
    vault.npm_unstaken.chain_id,
    vault.npm_unstaken.address                                      AS vault_address,
    vault.npm_unstaken.block_timestamp,
    vault.npm_unstaken.transaction_hash,
    vault.npm_unstaken.account,
    0                                                               AS pod_amount,
    vault.npm_unstaken.amount                                       AS npm_amount,
    0                                                               AS stablecoin_amount,
    'NpmUnstaken'                                                   AS tx_type
  FROM vault.npm_unstaken
  UNION ALL
  SELECT
    vault.npm_staken.chain_id,
    vault.npm_staken.address                                        AS vault_address,
    vault.npm_staken.block_timestamp,
    vault.npm_staken.transaction_hash,
    vault.npm_staken.account,
    0                                                               AS pod_amount,
    vault.npm_staken.amount                                         AS npm_amount,
    0                                                               AS stablecoin_amount,
    'NpmStaken'                                                     AS tx_type
  FROM vault.npm_staken
),
stage2
AS
(
  SELECT
    stage1.chain_id,
    stage1.vault_address,
    stage1.block_timestamp,
    stage1.transaction_hash,
    stage1.account,
    stage1.pod_amount,
    stage1.npm_amount,
    stage1.stablecoin_amount,
    stage1.tx_type,
    get_cover_key_by_vault_address
    (
      stage1.chain_id,
      stage1.vault_address
    )                                                               AS cover_key
  FROM stage1
)
SELECT
  stage2.chain_id,
  stage2.vault_address,
  stage2.block_timestamp,
  stage2.transaction_hash,
  stage2.account,
  wei_to_ether(stage2.pod_amount)                                   AS pod_amount,
  wei_to_ether(stage2.npm_amount)                                   AS npm_amount,
  get_stablecoin_value(stage2.chain_id, stage2.stablecoin_amount)   AS stablecoin_amount,
  stage2.tx_type,
  stage2.cover_key,
  get_products_of(stage2.chain_id, stage2.cover_key)                AS product_keys,
  factory.vault_deployed.name                                       AS token_name,
  factory.vault_deployed.symbol                                     AS token_symbol
FROM stage2
LEFT JOIN factory.vault_deployed
ON 1=1
AND factory.vault_deployed.chain_id                                 = stage2.chain_id
AND factory.vault_deployed.cover_key                                = stage2.cover_key
AND factory.vault_deployed.vault                                    = stage2.vault_address;

ALTER VIEW my_liquidity_view OWNER TO writeuser;
