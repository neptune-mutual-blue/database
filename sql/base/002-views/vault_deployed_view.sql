DROP VIEW IF EXISTS vault_deployed_view;
 
CREATE VIEW vault_deployed_view
AS
SELECT
  factory.vault_deployed.chain_id,
  factory.vault_deployed.cover_key,
  factory.vault_deployed.vault
FROM factory.vault_deployed;
