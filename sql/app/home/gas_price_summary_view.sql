DROP VIEW IF EXISTS gas_price_summary_view;

CREATE VIEW gas_price_summary_view
AS
SELECT
  config_blockchain_network_view.chain_id,
  config_blockchain_network_view.network_name,
  config_blockchain_network_view.nick_name,
  AVG(gas_price) AS average_gas_price,
  MIN(gas_price) AS min_gas_price,
  MAX(gas_price) AS max_gas_price
FROM core.transactions
INNER JOIN config_blockchain_network_view
ON config_blockchain_network_view.chain_id = core.transactions.chain_id
GROUP BY 
  config_blockchain_network_view.chain_id,
  config_blockchain_network_view.network_name,
  config_blockchain_network_view.nick_name;
