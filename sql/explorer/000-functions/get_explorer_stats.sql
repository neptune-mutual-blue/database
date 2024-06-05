CREATE OR REPLACE FUNCTION get_explorer_stats()
RETURNS TABLE
(
  transaction_count                                   integer,
  policy_purchased                                    numeric,
  liquidity_added                                     numeric,
  liquidity_removed                                   numeric,
  claimed                                             numeric,
  staked                                              numeric
)
AS
$$
BEGIN
  DROP TABLE IF EXISTS _get_explorer_stats_result;
  CREATE TEMPORARY TABLE _get_explorer_stats_result
  (
    transaction_count                                 integer,
    policy_purchased                                  numeric,
    liquidity_added                                   numeric,
    liquidity_removed                                 numeric,
    claimed                                           numeric,
    staked                                            numeric
  ) ON COMMIT DROP;

  INSERT INTO _get_explorer_stats_result(transaction_count)
  SELECT COUNT(*)
  FROM core.transactions;

  UPDATE _get_explorer_stats_result
  SET policy_purchased = COALESCE
  (
    (
      WITH total_by_chain
      AS
      (
        SELECT get_stablecoin_value
        (
          policy.cover_purchased.chain_id,
          SUM(policy.cover_purchased.amount_to_cover)
        )                                             AS total_covered
        FROM policy.cover_purchased
        GROUP BY policy.cover_purchased.chain_id
      )
      SELECT SUM(total_covered) FROM total_by_chain
    ),
    0
  );

  UPDATE _get_explorer_stats_result
  SET liquidity_added = COALESCE
  (
    (
      SELECT SUM
      (
        get_stablecoin_value
        (
          vault.pods_issued.chain_id,
          vault.pods_issued.liquidity_added
        )
      )
      FROM vault.pods_issued
    ),
    0
  );

  UPDATE _get_explorer_stats_result
  SET liquidity_removed = COALESCE
  (
    (
      SELECT SUM
      (
        get_stablecoin_value
        (
          vault.pods_redeemed.chain_id,
          vault.pods_redeemed.liquidity_released
        )
      )
      FROM vault.pods_redeemed
    ),
    0
  );

  UPDATE _get_explorer_stats_result
  SET claimed = COALESCE
  (
    (
      SELECT SUM(wei_to_ether(cxtoken.claimed.amount))
      FROM cxtoken.claimed
    ),
    0
  );

  UPDATE _get_explorer_stats_result
  SET staked = COALESCE
  (
    (
      SELECT SUM(get_npm_value(amount))
      FROM cover.stake_added
    ),
    0
  );

  UPDATE _get_explorer_stats_result
  SET staked = COALESCE(_get_explorer_stats_result.staked, 0) -
  COALESCE
  (
    (
      SELECT SUM(get_npm_value(amount))
      FROM cover.stake_removed
    ),
    0
  );

  RETURN QUERY
  SELECT * FROM _get_explorer_stats_result;
END
$$
LANGUAGE plpgsql;

ALTER FUNCTION get_explorer_stats() OWNER TO writeuser;
