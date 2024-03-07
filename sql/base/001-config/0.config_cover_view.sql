DROP VIEW IF EXISTS config_cover_view CASCADE;

CREATE VIEW config_cover_view
AS
SELECT
  1                              AS chain_id,
  string_to_bytes32('binance')   AS cover_key,
  1                              AS leverage,
  50                             AS policy_floor,
  700                            AS policy_ceiling,
  604800                         AS reporting_period,
  86400                          AS coverage_lag,
  50000000000000000000000        AS minimum_first_reporting_stake
UNION ALL
SELECT
  1                              AS chain_id,
  string_to_bytes32('okx')       AS cover_key,
  1                              AS leverage,
  50                             AS policy_floor,
  700                            AS policy_ceiling,
  604800                         AS reporting_period,
  86400                          AS coverage_lag,
  50000000000000000000000        AS minimum_first_reporting_stake
UNION ALL
SELECT
  1                                        AS chain_id,
  string_to_bytes32('popular-defi-apps')   AS cover_key,
  6                                        AS leverage,
  200                                      AS policy_floor,
  1200                                     AS policy_ceiling,
  604800                                   AS reporting_period,
  86400                                    AS coverage_lag,
  10000000000000000000000                  AS minimum_first_reporting_stake
UNION ALL
SELECT
  1                                        AS chain_id,
  string_to_bytes32('prime')               AS cover_key,
  6                                        AS leverage,
  50                                       AS policy_floor,
  400                                      AS policy_ceiling,
  604800                                   AS reporting_period,
  86400                                    AS coverage_lag,
  10000000000000000000000                  AS minimum_first_reporting_stake
UNION ALL
SELECT
  56                                       AS chain_id,
  string_to_bytes32('binance')             AS cover_key,
  1                                        AS leverage,
  50                                       AS policy_floor,
  1600                                     AS policy_ceiling,
  604800                                   AS reporting_period,
  86400                                    AS coverage_lag,
  50000000000000000000000                  AS minimum_first_reporting_stake
UNION ALL
SELECT
  56                                       AS chain_id,
  string_to_bytes32('popular-defi-apps')   AS cover_key,
  6                                        AS leverage,
  200                                      AS policy_floor,
  1200                                     AS policy_ceiling,
  604800                                   AS reporting_period,
  86400                                    AS coverage_lag,
  10000000000000000000000                  AS minimum_first_reporting_stake
UNION ALL
SELECT
  42161                                    AS chain_id,
  string_to_bytes32('binance')             AS cover_key,
  1                                        AS leverage,
  50                                       AS policy_floor,
  1600                                     AS policy_ceiling,
  604800                                   AS reporting_period,
  86400                                    AS coverage_lag,
  50000000000000000000000                  AS minimum_first_reporting_stake
UNION ALL
SELECT
  42161                                    AS chain_id,
  string_to_bytes32('okx')                 AS cover_key,
  1                                        AS leverage,
  50                                       AS policy_floor,
  700                                      AS policy_ceiling,
  604800                                   AS reporting_period,
  86400                                    AS coverage_lag,
  50000000000000000000000                  AS minimum_first_reporting_stake
UNION ALL
SELECT
  42161                                    AS chain_id,
  string_to_bytes32('popular-defi-apps')   AS cover_key,
  6                                        AS leverage,
  200                                      AS policy_floor,
  1200                                     AS policy_ceiling,
  604800                                   AS reporting_period,
  86400                                    AS coverage_lag,
  10000000000000000000000                  AS minimum_first_reporting_stake
UNION ALL
SELECT
  42161                                    AS chain_id,
  string_to_bytes32('prime')               AS cover_key,
  6                                        AS leverage,
  50                                       AS policy_floor,
  800                                      AS policy_ceiling,
  604800                                   AS reporting_period,
  86400                                    AS coverage_lag,
  10000000000000000000000                  AS minimum_first_reporting_stake
UNION ALL
SELECT
  80001                                    AS chain_id,
  string_to_bytes32('binance')             AS cover_key,
  1                                        AS leverage,
  400                                      AS policy_floor,
  1600                                     AS policy_ceiling,
  300                                      AS reporting_period,
  60                                       AS coverage_lag,
  2000000000000000000000                   AS minimum_first_reporting_stake
UNION ALL
SELECT
  80001                                    AS chain_id,
  string_to_bytes32('coinbase')            AS cover_key,
  1                                        AS leverage,
  400                                      AS policy_floor,
  1600                                     AS policy_ceiling,
  300                                      AS reporting_period,
  60                                       AS coverage_lag,
  2000000000000000000000                   AS minimum_first_reporting_stake
UNION ALL
SELECT
  80001                                    AS chain_id,
  string_to_bytes32('defi')                AS cover_key,
  10                                       AS leverage,
  200                                      AS policy_floor,
  1200                                     AS policy_ceiling,
  300                                      AS reporting_period,
  60                                       AS coverage_lag,
  2000000000000000000000                   AS minimum_first_reporting_stake
UNION ALL
SELECT
  80001                                    AS chain_id,
  string_to_bytes32('huobi')               AS cover_key,
  1                                        AS leverage,
  400                                      AS policy_floor,
  1600                                     AS policy_ceiling,
  300                                      AS reporting_period,
  60                                       AS coverage_lag,
  2000000000000000000000                   AS minimum_first_reporting_stake
UNION ALL
SELECT
  80001                                    AS chain_id,
  string_to_bytes32('okx')                 AS cover_key,
  1                                        AS leverage,
  400                                      AS policy_floor,
  1600                                     AS policy_ceiling,
  300                                      AS reporting_period,
  60                                       AS coverage_lag,
  2000000000000000000000                   AS minimum_first_reporting_stake
UNION ALL
SELECT
  80001                                    AS chain_id,
  string_to_bytes32('prime')               AS cover_key,
  10                                       AS leverage,
  50                                       AS policy_floor,
  800                                      AS policy_ceiling,
  300                                      AS reporting_period,
  60                                       AS coverage_lag,
  2000000000000000000000                   AS minimum_first_reporting_stake;
