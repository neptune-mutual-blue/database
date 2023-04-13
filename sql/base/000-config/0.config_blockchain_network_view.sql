DROP VIEW IF EXISTS config_blockchain_network_view CASCADE;

CREATE VIEW config_blockchain_network_view
AS
SELECT 1      AS chain_id, 'Main Ethereum Network'      AS network_name, 'Mainnet'      AS nick_name, 'ETH'     AS currency, 'USDC' AS stablecion, 6 AS stablecoin_decimals, 'https://etherscan.io/'              AS explorer UNION ALL
SELECT 42161  AS chain_id, 'Arbitrum One'               AS network_name, 'Arbitrum'     AS nick_name, 'ETH'     AS currency, 'USDC' AS stablecion, 6 AS stablecoin_decimals, 'https://arbiscan.io/'               AS explorer UNION ALL
SELECT 84531  AS chain_id, 'Base Goerli'                AS network_name, 'Base Goerli'  AS nick_name, 'ETH'     AS currency, 'USDC' AS stablecion, 6 AS stablecoin_decimals, 'https://goerli.basescan.org/'       AS explorer;
