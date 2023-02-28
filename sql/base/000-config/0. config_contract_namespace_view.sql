DROP VIEW IF EXISTS config_contract_namespace_view CASCADE;

CREATE VIEW config_contract_namespace_view
AS
SELECT 'cns:cover:vault:factory' AS namespace,      'VaultFactory' AS contract_name UNION ALL
SELECT 'cns:cover:cxtoken:factory' AS namespace,    'cxTokenFactory' AS contract_name UNION ALL
SELECT 'cns:cover:reassurance' AS namespace,        'CoverReassurance' AS contract_name UNION ALL
SELECT 'cns:claim:processor' AS namespace,          'Processor' AS contract_name UNION ALL
SELECT 'cns:cover:policy:admin' AS namespace,       'PolicyAdmin' AS contract_name UNION ALL
SELECT 'cns:cover:policy' AS namespace,             'Policy' AS contract_name UNION ALL
SELECT 'cns:gov:resolution' AS namespace,           'Resolution' AS contract_name UNION ALL
SELECT 'cns:cover:stake' AS namespace,              'CoverStake' AS contract_name UNION ALL
SELECT 'cns:pools:staking' AS namespace,            'StakingPools' AS contract_name UNION ALL
SELECT 'cns:pools:bond' AS namespace,               'BondPool' AS contract_name UNION ALL
SELECT 'cns:cover' AS namespace,                    'Cover' AS contract_name UNION ALL
SELECT 'cns:gov' AS namespace,                      'Governance' AS contract_name UNION ALL
SELECT 'cns:cover:vault:delegate' AS namespace,     'VaultDelegate' AS contract_name UNION ALL
SELECT 'cns:liquidity:engine' AS namespace,         'LiquidityEngine' AS contract_name UNION ALL
SELECT 'cns:cover:vault' AS namespace,              'Vault' AS contract_name;

