CREATE OR REPLACE VIEW active_liquidity_view
AS
WITH vaults
AS
(
  SELECT
    vault.pods_issued.chain_id,
    vault.pods_issued.account,
    vault.pods_issued.address                 AS vault_address
  FROM vault.pods_issued
  UNION
  SELECT
    vault.pods_redeemed.chain_id,
    vault.pods_redeemed.account,
    vault.pods_redeemed.address               AS vault_address
  FROM vault.pods_redeemed
),
balances
AS
(
  SELECT
    vaults.chain_id,
    vaults.account,
    vaults.vault_address,
    get_cover_key_by_vault_address
    (
      vaults.chain_id,
      vaults.vault_address
    )                                         AS cover_key,
    (
      SELECT COALESCE(SUM(vault.pods_issued.issued), 0)
      FROM vault.pods_issued
      WHERE 1 = 1
      AND chain_id                            = vaults.chain_id
      AND account                             = vaults.account
      AND vault.pods_issued.address           = vaults.vault_address
    ) -
    (
      SELECT COALESCE(SUM(vault.pods_redeemed.redeemed), 0)
      FROM vault.pods_redeemed
      WHERE 1 = 1
      AND chain_id                            = vaults.chain_id
      AND account                             = vaults.account
      AND vault.pods_redeemed.address         = vaults.vault_address
    ) AS balance
  FROM vaults
  GROUP BY
    vaults.chain_id,
    vaults.account,
    vaults.vault_address
)
SELECT
  balances.chain_id,
  account,
  wei_to_ether(balances.balance)              AS balance,
  balances.vault_address,
  balances.cover_key,
  bytes32_to_string(balances.cover_key)       AS cover_key_string,
  factory.vault_deployed.name                 AS token_name,
  factory.vault_deployed.symbol               AS token_symbol
FROM balances
LEFT JOIN factory.vault_deployed
ON 1=1
AND factory.vault_deployed.chain_id            = balances.chain_id
AND factory.vault_deployed.cover_key           = balances.cover_key
AND factory.vault_deployed.vault               = balances.vault_address;

ALTER VIEW active_liquidity_view OWNER TO writeuser;

-- SELECT * FROM active_liquidity_view
-- WHERE 1 = 1
-- AND chain_id                                = 43113
-- AND account                                 = LOWER('0x201Bcc0d375f10543e585fbB883B36c715c959B3');
