DROP VIEW IF EXISTS config_blockchain_network_view CASCADE;

CREATE VIEW config_blockchain_network_view
AS
SELECT 1      AS chain_id, 'Main Ethereum Network'      AS network_name, 'Mainnet'    AS nick_name, 'ETH'     AS currency, 'USDC' AS stablecion, 6 AS stablecoin_decimals, 'https://etherscan.io/'              AS explorer UNION ALL
SELECT 42161  AS chain_id, 'Arbitrum One'               AS network_name, 'Arbitrum'   AS nick_name, 'ETH'     AS currency, 'USDC' AS stablecion, 6 AS stablecoin_decimals, 'https://arbiscan.io/'               AS explorer UNION ALL
SELECT 43113  AS chain_id, 'Avalanche Fuji Testnet'     AS network_name, 'Fuji'       AS nick_name, 'AVAX'    AS currency, 'USDC' AS stablecion, 6 AS stablecoin_decimals, 'https://testnet.snowtrace.io/'      AS explorer;
