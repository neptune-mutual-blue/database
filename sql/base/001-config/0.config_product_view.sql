DROP VIEW IF EXISTS config_product_view CASCADE;

CREATE VIEW config_product_view
AS
SELECT 56     AS chain_id, string_to_bytes32('popular-defi-apps')       AS cover_key, string_to_bytes32('alpaca-v1')        AS product_key, 7000 AS capital_efficiency UNION ALL
SELECT 56     AS chain_id, string_to_bytes32('popular-defi-apps')       AS cover_key, string_to_bytes32('dodo-v2')          AS product_key, 7000 AS capital_efficiency UNION ALL
SELECT 56     AS chain_id, string_to_bytes32('popular-defi-apps')       AS cover_key, string_to_bytes32('oneinch-v2')       AS product_key, 8000 AS capital_efficiency UNION ALL
SELECT 56     AS chain_id, string_to_bytes32('popular-defi-apps')       AS cover_key, string_to_bytes32('pancakeswap-v2')   AS product_key, 9000 AS capital_efficiency UNION ALL
SELECT 56     AS chain_id, string_to_bytes32('popular-defi-apps')       AS cover_key, string_to_bytes32('uniswap-v3')       AS product_key, 9500 AS capital_efficiency UNION ALL
SELECT 1      AS chain_id, string_to_bytes32('popular-defi-apps')       AS cover_key, string_to_bytes32('aave-v3')          AS product_key, 9000 AS capital_efficiency UNION ALL
SELECT 1      AS chain_id, string_to_bytes32('popular-defi-apps')       AS cover_key, string_to_bytes32('bancor-v3')        AS product_key, 5000 AS capital_efficiency UNION ALL
SELECT 1      AS chain_id, string_to_bytes32('popular-defi-apps')       AS cover_key, string_to_bytes32('compound-v2')      AS product_key, 7000 AS capital_efficiency UNION ALL
SELECT 1      AS chain_id, string_to_bytes32('popular-defi-apps')       AS cover_key, string_to_bytes32('convex-v1')        AS product_key, 5000 AS capital_efficiency UNION ALL
SELECT 1      AS chain_id, string_to_bytes32('popular-defi-apps')       AS cover_key, string_to_bytes32('dydx-v3')          AS product_key, 3000 AS capital_efficiency UNION ALL
SELECT 1      AS chain_id, string_to_bytes32('popular-defi-apps')       AS cover_key, string_to_bytes32('gmx-v1')           AS product_key, 6000 AS capital_efficiency UNION ALL
SELECT 1      AS chain_id, string_to_bytes32('popular-defi-apps')       AS cover_key, string_to_bytes32('oneinch-v2')       AS product_key, 4000 AS capital_efficiency UNION ALL
SELECT 1      AS chain_id, string_to_bytes32('popular-defi-apps')       AS cover_key, string_to_bytes32('sushiswap-v1')     AS product_key, 5000 AS capital_efficiency UNION ALL
SELECT 1      AS chain_id, string_to_bytes32('popular-defi-apps')       AS cover_key, string_to_bytes32('uniswap-v3')       AS product_key, 9000 AS capital_efficiency UNION ALL
SELECT 1      AS chain_id, string_to_bytes32('prime')                   AS cover_key, string_to_bytes32('aave-v2')          AS product_key, 9000 AS capital_efficiency UNION ALL
SELECT 1      AS chain_id, string_to_bytes32('prime')                   AS cover_key, string_to_bytes32('balancer-v2')      AS product_key, 7500 AS capital_efficiency UNION ALL
SELECT 1      AS chain_id, string_to_bytes32('prime')                   AS cover_key, string_to_bytes32('curve-v2')         AS product_key, 7000 AS capital_efficiency UNION ALL
SELECT 1      AS chain_id, string_to_bytes32('prime')                   AS cover_key, string_to_bytes32('gnosis-safe-v1')   AS product_key, 9500 AS capital_efficiency UNION ALL
SELECT 1      AS chain_id, string_to_bytes32('prime')                   AS cover_key, string_to_bytes32('maker-v1')         AS product_key, 9000 AS capital_efficiency UNION ALL
SELECT 1      AS chain_id, string_to_bytes32('prime')                   AS cover_key, string_to_bytes32('synthetix-v2')     AS product_key, 8000 AS capital_efficiency UNION ALL
SELECT 1      AS chain_id, string_to_bytes32('prime')                   AS cover_key, string_to_bytes32('uniswap-v2')       AS product_key, 9000 AS capital_efficiency UNION ALL
SELECT 42161  AS chain_id, string_to_bytes32('popular-defi-apps')       AS cover_key, string_to_bytes32('aave-v3')          AS product_key, 9000 AS capital_efficiency UNION ALL
SELECT 42161  AS chain_id, string_to_bytes32('popular-defi-apps')       AS cover_key, string_to_bytes32('bancor-v3')        AS product_key, 5000 AS capital_efficiency UNION ALL
SELECT 42161  AS chain_id, string_to_bytes32('popular-defi-apps')       AS cover_key, string_to_bytes32('compound-v2')      AS product_key, 7000 AS capital_efficiency UNION ALL
SELECT 42161  AS chain_id, string_to_bytes32('popular-defi-apps')       AS cover_key, string_to_bytes32('convex-v1')        AS product_key, 5000 AS capital_efficiency UNION ALL
SELECT 42161  AS chain_id, string_to_bytes32('popular-defi-apps')       AS cover_key, string_to_bytes32('dydx-v3')          AS product_key, 3000 AS capital_efficiency UNION ALL
SELECT 42161  AS chain_id, string_to_bytes32('popular-defi-apps')       AS cover_key, string_to_bytes32('gmx-v1')           AS product_key, 6000 AS capital_efficiency UNION ALL
SELECT 42161  AS chain_id, string_to_bytes32('popular-defi-apps')       AS cover_key, string_to_bytes32('oneinch-v2')       AS product_key, 4000 AS capital_efficiency UNION ALL
SELECT 42161  AS chain_id, string_to_bytes32('popular-defi-apps')       AS cover_key, string_to_bytes32('sushiswap-v1')     AS product_key, 5000 AS capital_efficiency UNION ALL
SELECT 42161  AS chain_id, string_to_bytes32('popular-defi-apps')       AS cover_key, string_to_bytes32('uniswap-v3')       AS product_key, 9000 AS capital_efficiency UNION ALL
SELECT 42161  AS chain_id, string_to_bytes32('prime')                   AS cover_key, string_to_bytes32('aave-v2')          AS product_key, 9000 AS capital_efficiency UNION ALL
SELECT 42161  AS chain_id, string_to_bytes32('prime')                   AS cover_key, string_to_bytes32('balancer-v2')      AS product_key, 7500 AS capital_efficiency UNION ALL
SELECT 42161  AS chain_id, string_to_bytes32('prime')                   AS cover_key, string_to_bytes32('curve-v2')         AS product_key, 7000 AS capital_efficiency UNION ALL
SELECT 42161  AS chain_id, string_to_bytes32('prime')                   AS cover_key, string_to_bytes32('gnosis-safe-v1')   AS product_key, 9500 AS capital_efficiency UNION ALL
SELECT 42161  AS chain_id, string_to_bytes32('prime')                   AS cover_key, string_to_bytes32('maker-v1')         AS product_key, 9000 AS capital_efficiency UNION ALL
SELECT 42161  AS chain_id, string_to_bytes32('prime')                   AS cover_key, string_to_bytes32('synthetix-v2')     AS product_key, 8000 AS capital_efficiency UNION ALL
SELECT 42161  AS chain_id, string_to_bytes32('prime')                   AS cover_key, string_to_bytes32('uniswap-v2')       AS product_key, 9000 AS capital_efficiency UNION ALL
SELECT 84531  AS chain_id, string_to_bytes32('defi')                    AS cover_key, string_to_bytes32('1inch-v2')         AS product_key, 9000 AS capital_efficiency UNION ALL
SELECT 84531  AS chain_id, string_to_bytes32('defi')                    AS cover_key, string_to_bytes32('compound-v2')      AS product_key, 9000 AS capital_efficiency UNION ALL
SELECT 84531  AS chain_id, string_to_bytes32('defi')                    AS cover_key, string_to_bytes32('convex-v1')        AS product_key, 9000 AS capital_efficiency UNION ALL
SELECT 84531  AS chain_id, string_to_bytes32('defi')                    AS cover_key, string_to_bytes32('kyberswap-v1')     AS product_key, 5000 AS capital_efficiency UNION ALL
SELECT 84531  AS chain_id, string_to_bytes32('defi')                    AS cover_key, string_to_bytes32('lido-v1')          AS product_key, 9000 AS capital_efficiency UNION ALL
SELECT 84531  AS chain_id, string_to_bytes32('defi')                    AS cover_key, string_to_bytes32('nexus-mutual-v1')  AS product_key, 9000 AS capital_efficiency UNION ALL
SELECT 84531  AS chain_id, string_to_bytes32('defi')                    AS cover_key, string_to_bytes32('rpl-v1')           AS product_key, 9000 AS capital_efficiency UNION ALL
SELECT 84531  AS chain_id, string_to_bytes32('defi')                    AS cover_key, string_to_bytes32('sushi-v2')         AS product_key, 7000 AS capital_efficiency UNION ALL
SELECT 84531  AS chain_id, string_to_bytes32('defi')                    AS cover_key, string_to_bytes32('uniswap-v3')       AS product_key, 9000 AS capital_efficiency UNION ALL
SELECT 84531  AS chain_id, string_to_bytes32('prime')                   AS cover_key, string_to_bytes32('aave-v2')          AS product_key, 10000 AS capital_efficiency UNION ALL
SELECT 84531  AS chain_id, string_to_bytes32('prime')                   AS cover_key, string_to_bytes32('balancer-v2')      AS product_key, 7500 AS capital_efficiency UNION ALL
SELECT 84531  AS chain_id, string_to_bytes32('prime')                   AS cover_key, string_to_bytes32('curve-v2')         AS product_key, 7000 AS capital_efficiency UNION ALL
SELECT 84531  AS chain_id, string_to_bytes32('prime')                   AS cover_key, string_to_bytes32('gnosis-safe-v1')   AS product_key, 7000 AS capital_efficiency UNION ALL
SELECT 84531  AS chain_id, string_to_bytes32('prime')                   AS cover_key, string_to_bytes32('maker-v1')         AS product_key, 9000 AS capital_efficiency UNION ALL
SELECT 84531  AS chain_id, string_to_bytes32('prime')                   AS cover_key, string_to_bytes32('synthetix-v2')     AS product_key, 7000 AS capital_efficiency UNION ALL
SELECT 84531  AS chain_id, string_to_bytes32('prime')                   AS cover_key, string_to_bytes32('uniswap-v2')       AS product_key, 9000 AS capital_efficiency;


