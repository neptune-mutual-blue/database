DROP FUNCTION IF EXISTS get_explorer_stats();

CREATE FUNCTION get_explorer_stats()
RETURNS TABLE
(
  transaction_count                                 integer,
  policy_purchased                                  numeric,
  liquidity_added                                   numeric,
  liquidity_removed                                 numeric,
  claimed                                           numeric,
  staked                                            numeric
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
  SET policy_purchased = 
  COALESCE((
    SELECT SUM(policy.cover_purchased.amount_to_cover)
    FROM policy.cover_purchased
  ), 0);
  
  UPDATE _get_explorer_stats_result
  SET liquidity_added =
  COALESCE((
    SELECT SUM(vault.pods_issued.liquidity_added)
    FROM vault.pods_issued
  ), 0);
  
  UPDATE _get_explorer_stats_result
  SET liquidity_removed =
  COALESCE((
    SELECT SUM(vault.pods_redeemed.liquidity_released)
    FROM vault.pods_redeemed
  ), 0);
  
  UPDATE _get_explorer_stats_result
  SET claimed =
  COALESCE((
    SELECT SUM(cxtoken.claimed.amount)
    FROM cxtoken.claimed
  ), 0);

  UPDATE _get_explorer_stats_result
  SET staked =
  COALESCE((
    SELECT SUM(amount)
    FROM cover.stake_added
  ), 0);

  UPDATE _get_explorer_stats_result
  SET staked = COALESCE(_get_explorer_stats_result.staked, 0) -
  COALESCE((
    SELECT SUM(amount)
    FROM cover.stake_removed
  ), 0);
  
  RETURN QUERY
  SELECT * FROM _get_explorer_stats_result;
END
$$
LANGUAGE plpgsql;

