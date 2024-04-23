CREATE OR REPLACE VIEW config_blockchain_network_view
AS
SELECT
  1                                             AS chain_id,
  'Main Ethereum Network'                       AS network_name,
  'Mainnet'                                     AS nick_name,
  'ETH'                                         AS currency,
  'USDC'                                        AS stablecion,
  6                                             AS stablecoin_decimals,
  '0xb452ac021a1151aaf342c1b75aa914e03e6503b5'  AS protocol_address,
  '0x6579df8f986e4a982f200dafa0c1b955a438f620'  AS store_address,
  '0x57f12FE6A4e5fe819eec699FAdf9Db2D06606bB4'  AS npm_address,
  'https://etherscan.io/'                       AS explorer 
UNION ALL
SELECT 42161                                    AS chain_id,
  'Arbitrum One'                                AS network_name,
  'Arbitrum'                                    AS nick_name,
  'ETH'                                         AS currency,
  'USDC'                                        AS stablecion,
  6                                             AS stablecoin_decimals,
  '0xb452ac021a1151aaf342c1b75aa914e03e6503b5'  AS protocol_address,
  '0x6579df8f986e4a982f200dafa0c1b955a438f620'  AS store_address,
  '0x57f12FE6A4e5fe819eec699FAdf9Db2D06606bB4'  AS npm_address,
  'https://arbiscan.io/'                        AS explorer 
UNION ALL
SELECT 43113                                    AS chain_id,
  'Avalanche Fuji Testnet'                      AS network_name,
  'Fuji'                                        AS nick_name,
  'AVAX'                                        AS currency,
  'USDC'                                        AS stablecion,
  6                                             AS stablecoin_decimals,
  '0xf90727FB4e61d7B45DB9C024e87042Ec38Afb782'  AS protocol_address,
  '0x3385A1896E6A76deDBf5498b1B1A65Bcf86eE58b'  AS store_address,
  '0x73643a4f85ccbEdA5db6397BF044f4CBF16DC4Df'  AS npm_address,
  'https://testnet.snowtrace.io/'               AS explorer 
UNION ALL
SELECT 84531                                    AS chain_id,
  'Base Goerli'                                 AS network_name,
  'Base Goerli'                                 AS nick_name,
  'ETH'                                         AS currency,
  'USDC'                                        AS stablecion,
  6                                             AS stablecoin_decimals,
  '0x3b60152bfea33b894e06291aa2bb3404b8dfdc2b'  AS protocol_address,
  '0x52b124a19023edf0386a3d9e674fdd7e02b8a8a8'  AS store_address,
  '0x4bbdc138dd105c7dde874df7fcd087b064f7973d'  AS npm_address,
  'https://goerli.basescan.org/'                AS explorer;

ALTER VIEW config_blockchain_network_view OWNER TO writeuser;
