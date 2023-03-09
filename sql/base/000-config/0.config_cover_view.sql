DROP VIEW IF EXISTS config_cover_view CASCADE;

CREATE VIEW config_cover_view
AS
SELECT 42161  AS chain_id, '0x62696e616e636500000000000000000000000000000000000000000000000000' AS cover_key, 1   AS leverage, 50   AS policy_floor, 1600  AS policy_ceiling, EXTRACT(epoch FROM INTERVAL '7 days')     AS reporting_period,  EXTRACT(epoch FROM INTERVAL '1 days')     AS coverage_lag, ether(50000)   AS minimum_first_reporting_stake UNION ALL
SELECT 42161  AS chain_id, '0x6f6b780000000000000000000000000000000000000000000000000000000000' AS cover_key, 1   AS leverage, 50   AS policy_floor, 700   AS policy_ceiling, EXTRACT(epoch FROM INTERVAL '7 days')     AS reporting_period,  EXTRACT(epoch FROM INTERVAL '1 days')     AS coverage_lag, ether(50000)   AS minimum_first_reporting_stake UNION ALL
SELECT 42161  AS chain_id, '0x706f70756c61722d646566692d61707073000000000000000000000000000000' AS cover_key, 6   AS leverage, 200  AS policy_floor, 1200  AS policy_ceiling, EXTRACT(epoch FROM INTERVAL '7 days')     AS reporting_period,  EXTRACT(epoch FROM INTERVAL '1 days')     AS coverage_lag, ether(10000)   AS minimum_first_reporting_stake UNION ALL
SELECT 42161  AS chain_id, '0x7072696d65000000000000000000000000000000000000000000000000000000' AS cover_key, 6   AS leverage, 50   AS policy_floor, 800   AS policy_ceiling, EXTRACT(epoch FROM INTERVAL '7 days')     AS reporting_period,  EXTRACT(epoch FROM INTERVAL '1 days')     AS coverage_lag, ether(10000)   AS minimum_first_reporting_stake UNION ALL
SELECT 1      AS chain_id, '0x62696e616e636500000000000000000000000000000000000000000000000000' AS cover_key, 1   AS leverage, 50   AS policy_floor, 700   AS policy_ceiling, EXTRACT(epoch FROM INTERVAL '7 days')     AS reporting_period,  EXTRACT(epoch FROM INTERVAL '1 days')     AS coverage_lag, ether(50000)   AS minimum_first_reporting_stake UNION ALL
SELECT 1      AS chain_id, '0x6f6b780000000000000000000000000000000000000000000000000000000000' AS cover_key, 1   AS leverage, 50   AS policy_floor, 700   AS policy_ceiling, EXTRACT(epoch FROM INTERVAL '7 days')     AS reporting_period,  EXTRACT(epoch FROM INTERVAL '1 days')     AS coverage_lag, ether(50000)   AS minimum_first_reporting_stake UNION ALL
SELECT 1      AS chain_id, '0x706f70756c61722d646566692d61707073000000000000000000000000000000' AS cover_key, 6   AS leverage, 200  AS policy_floor, 1200  AS policy_ceiling, EXTRACT(epoch FROM INTERVAL '7 days')     AS reporting_period,  EXTRACT(epoch FROM INTERVAL '1 days')     AS coverage_lag, ether(10000)   AS minimum_first_reporting_stake UNION ALL
SELECT 1      AS chain_id, '0x7072696d65000000000000000000000000000000000000000000000000000000' AS cover_key, 6   AS leverage, 50   AS policy_floor, 400   AS policy_ceiling, EXTRACT(epoch FROM INTERVAL '7 days')     AS reporting_period,  EXTRACT(epoch FROM INTERVAL '1 days')     AS coverage_lag, ether(10000)   AS minimum_first_reporting_stake UNION ALL
SELECT 43113  AS chain_id, '0x62696e616e636500000000000000000000000000000000000000000000000000' AS cover_key, 1   AS leverage, 400  AS policy_floor, 1600  AS policy_ceiling, EXTRACT(epoch FROM INTERVAL '5 minutes')  AS reporting_period,  EXTRACT(epoch FROM INTERVAL '1 minutes')  AS coverage_lag, ether(2000)    AS minimum_first_reporting_stake UNION ALL
SELECT 43113  AS chain_id, '0x636f696e62617365000000000000000000000000000000000000000000000000' AS cover_key, 1   AS leverage, 400  AS policy_floor, 1600  AS policy_ceiling, EXTRACT(epoch FROM INTERVAL '5 minutes')  AS reporting_period,  EXTRACT(epoch FROM INTERVAL '1 minutes')  AS coverage_lag, ether(2000)    AS minimum_first_reporting_stake UNION ALL
SELECT 43113  AS chain_id, '0x6465666900000000000000000000000000000000000000000000000000000000' AS cover_key, 10  AS leverage, 200  AS policy_floor, 1200  AS policy_ceiling, EXTRACT(epoch FROM INTERVAL '5 minutes')  AS reporting_period,  EXTRACT(epoch FROM INTERVAL '1 minutes')  AS coverage_lag, ether(2000)    AS minimum_first_reporting_stake UNION ALL
SELECT 43113  AS chain_id, '0x68756f6269000000000000000000000000000000000000000000000000000000' AS cover_key, 1   AS leverage, 400  AS policy_floor, 1600  AS policy_ceiling, EXTRACT(epoch FROM INTERVAL '5 minutes')  AS reporting_period,  EXTRACT(epoch FROM INTERVAL '1 minutes')  AS coverage_lag, ether(2000)    AS minimum_first_reporting_stake UNION ALL
SELECT 43113  AS chain_id, '0x6f6b780000000000000000000000000000000000000000000000000000000000' AS cover_key, 1   AS leverage, 400  AS policy_floor, 1600  AS policy_ceiling, EXTRACT(epoch FROM INTERVAL '5 minutes')  AS reporting_period,  EXTRACT(epoch FROM INTERVAL '1 minutes')  AS coverage_lag, ether(2000)    AS minimum_first_reporting_stake UNION ALL
SELECT 43113  AS chain_id, '0x7072696d65000000000000000000000000000000000000000000000000000000' AS cover_key, 10  AS leverage, 50   AS policy_floor, 800   AS policy_ceiling, EXTRACT(epoch FROM INTERVAL '5 minutes')  AS reporting_period,  EXTRACT(epoch FROM INTERVAL '1 minutes')  AS coverage_lag, ether(2000)    AS minimum_first_reporting_stake;

