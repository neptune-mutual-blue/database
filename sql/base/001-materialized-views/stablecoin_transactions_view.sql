DROP MATERIALIZED VIEW IF EXISTS stablecoin_transactions_view CASCADE;

CREATE MATERIALIZED VIEW stablecoin_transactions_view
AS
WITH transactions
AS
(
  SELECT
    'Liquidity Added' AS description,
    vault.pods_issued.chain_id,
    factory.vault_deployed.cover_key,
    SUM(get_stablecoin_value(vault.pods_issued.chain_id, vault.pods_issued.liquidity_added)) as total
  FROM vault.pods_issued
  INNER JOIN factory.vault_deployed
  ON factory.vault_deployed.vault = vault.pods_issued.address
  AND factory.vault_deployed.chain_id = vault.pods_issued.chain_id
  GROUP BY vault.pods_issued.chain_id, factory.vault_deployed.cover_key

  UNION ALL

  SELECT
    'Liquidity Removed' AS description,
    vault.pods_redeemed.chain_id,
    factory.vault_deployed.cover_key,
    SUM(get_stablecoin_value(vault.pods_redeemed.chain_id, vault.pods_redeemed.liquidity_released)) as total_liquidity
  FROM vault.pods_redeemed
  INNER JOIN factory.vault_deployed
  ON factory.vault_deployed.vault = vault.pods_redeemed.address
  AND factory.vault_deployed.chain_id = vault.pods_redeemed.chain_id
  GROUP BY vault.pods_redeemed.chain_id, factory.vault_deployed.cover_key

  UNION ALL

  SELECT
    'Fee Earned' AS description,
    chain_id,
    cover_key,
    SUM(get_stablecoin_value(chain_id, fee - platform_fee)) AS total_fee
  FROM policy.cover_purchased
  GROUP BY chain_id, cover_key
)
SELECT description, chain_id, cover_key, total
FROM transactions;


CREATE UNIQUE INDEX description_chain_id_cover_key_stablecoin_transactions_view
ON stablecoin_transactions_view(description, chain_id, cover_key);

CREATE INDEX chain_id_cover_key_stablecoin_transactions_view_inx
ON stablecoin_transactions_view(chain_id, cover_key);


DROP FUNCTION IF EXISTS core.refresh_stablecoin_transactions_view_trigger() CASCADE;

CREATE FUNCTION core.refresh_stablecoin_transactions_view_trigger()
RETURNS trigger
AS
$$
BEGIN
  REFRESH MATERIALIZED VIEW CONCURRENTLY stablecoin_transactions_view;
  RETURN NEW;
END
$$
LANGUAGE plpgsql;


CREATE TRIGGER refresh_stablecoin_transactions_view_trigger
BEFORE INSERT OR UPDATE ON core.transactions
FOR EACH STATEMENT
EXECUTE FUNCTION core.refresh_stablecoin_transactions_view_trigger();

