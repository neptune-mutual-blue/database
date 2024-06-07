CREATE OR REPLACE VIEW my_policies_view
AS
WITH policy_txs
AS
(
  SELECT
    chain_id,
    cover_key,
    product_key,
    block_timestamp,
    cx_token,
    transaction_hash,
    on_behalf_of                                        AS account,
    get_stablecoin_value(chain_id, amount_to_cover)     AS cxtoken_amount,
    get_stablecoin_value(chain_id, fee)                 AS stablecoin_amount,
    'CoverPurchased'                                    AS tx_type
  FROM policy.cover_purchased
  UNION ALL
  SELECT
    chain_id,
    cover_key,
    product_key,
    block_timestamp,
    cx_token,
    transaction_hash,
    account                                             AS account,
    wei_to_ether(amount)                                AS cxtoken_amount,
    wei_to_ether(claimed)                               AS stablecoin_amount,
    'Claimed'                                           AS tx_type
  FROM cxtoken.claimed
)

SELECT
  policy_txs.chain_id,
  policy_txs.cover_key,
  policy_txs.product_key,
  policy_txs.block_timestamp,
  policy_txs.cx_token,
  policy_txs.transaction_hash,
  policy_txs.account,
  policy_txs.cxtoken_amount,
  policy_txs.stablecoin_amount,
  policy_txs.tx_type,
  bytes32_to_string(policy_txs.cover_key)       AS cover_key_string,
  bytes32_to_string(policy_txs.product_key)     AS product_key_string,
  'cxUSD'                                       AS token_symbol,
  factory.cx_token_deployed.token_name
FROM policy_txs
INNER JOIN factory.cx_token_deployed
ON factory.cx_token_deployed.chain_id           = policy_txs.chain_id
AND factory.cx_token_deployed.cover_key         = policy_txs.cover_key
AND factory.cx_token_deployed.product_key       = policy_txs.product_key
AND factory.cx_token_deployed.cx_token          = policy_txs.cx_token;

ALTER VIEW my_policies_view OWNER TO writeuser;
