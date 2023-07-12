DROP TRIGGER IF EXISTS refresh_stablecoin_transactions_view_trigger ON core.transactions;
DROP TRIGGER IF EXISTS refresh_reassurance_transaction_view_trigger ON core.transactions;
DROP FUNCTION IF EXISTS core.refresh_stablecoin_transactions_view_trigger();
DROP FUNCTION IF EXISTS core.refresh_reassurance_transaction_view_trigger();

DROP FUNCTION get_tvl_till_date
(
  _date                                     TIMESTAMP WITH TIME ZONE
);

DROP FUNCTION get_tvl_till_date
(
  _chain_id                                 uint256,
  _cover_key                                bytes32,
  _date                                     TIMESTAMP WITH TIME ZONE
);

DROP FUNCTION get_tvl_till_date
(
  _chain_id                                 uint256,
  _date                                     TIMESTAMP WITH TIME ZONE
);

DROP FUNCTION sum_cover_purchased_during
(
  _start                                      TIMESTAMP WITH TIME ZONE,
  _end                                        TIMESTAMP WITH TIME ZONE
);

DROP FUNCTION sum_cover_purchased_during
(
  _chain_id                                   uint256,
  _start                                      TIMESTAMP WITH TIME ZONE,
  _end                                        TIMESTAMP WITH TIME ZONE
);

DROP FUNCTION sum_cover_purchased_during
(
  _chain_id                                   uint256,
  _cover_key                                  bytes32,
  _start                                      TIMESTAMP WITH TIME ZONE,
  _end                                        TIMESTAMP WITH TIME ZONE
);

DROP FUNCTION get_reassurance_till_date
(
  _date                                     TIMESTAMP WITH TIME ZONE
);

DROP FUNCTION get_reassurance_till_date
(
  _chain_id                                 uint256,
  _date                                     TIMESTAMP WITH TIME ZONE
);

DROP FUNCTION get_reassurance_till_date
(
  _chain_id                                 uint256,
  _cover_key                                bytes32,
  _date                                     TIMESTAMP WITH TIME ZONE
);

DROP FUNCTION IF EXISTS get_cover_capacity_till
(
  _chain_id                                           uint256,
  _cover_key                                          bytes32,
  _till                                               TIMESTAMP WITH TIME ZONE
);

DROP FUNCTION IF EXISTS get_cover_stats
(
  _chain_id                               uint256,
  _cover_key                              bytes32,
  _product_key                            bytes32,
  _account                                address
);

DROP FUNCTION IF EXISTS get_sum_commitment
(
  _chain_id                                   uint256,
  _cover_key                                  bytes32
);

DROP FUNCTION IF EXISTS get_product_summary(_account address);
DROP FUNCTION IF EXISTS get_explorer_stats();
DROP FUNCTION IF EXISTS get_min_first_reporting_stake(_chain_id uint256, _cover_key bytes32);
DROP FUNCTION IF EXISTS get_gauge_pools();

DROP VIEW IF EXISTS top_accounts_by_protection_view;
DROP VIEW IF EXISTS nft_user_points_view;
DROP VIEW IF EXISTS total_fee_earned_view;
DROP VIEW IF EXISTS total_value_locked_view;
DROP VIEW IF EXISTS total_liquidity_added_view;
DROP VIEW IF EXISTS total_liquidity_removed_view;
DROP VIEW IF EXISTS total_value_locked_by_chain_view;
DROP VIEW IF EXISTS cover_reassurance_view;
DROP VIEW IF EXISTS cover_expiring_this_month_view;
DROP VIEW IF EXISTS cover_premium_by_pool;
DROP VIEW IF EXISTS cover_sold_by_pool_view;
DROP VIEW IF EXISTS protection_by_month_view;
DROP VIEW IF EXISTS expired_policies_view;
DROP VIEW IF EXISTS my_policies_view;
DROP VIEW IF EXISTS top_accounts_by_liquidity_view;
DROP VIEW IF EXISTS commitment_by_chain_view;
DROP VIEW IF EXISTS fee_earned_by_chain_view;
DROP VIEW IF EXISTS incident_stakes_by_camp_view;
DROP VIEW IF EXISTS total_coverage_by_chain_view;
DROP VIEW IF EXISTS total_platform_fee_earned_view;
DROP VIEW IF EXISTS capacity_by_chain_view;
DROP VIEW IF EXISTS capacity_view;
DROP VIEW IF EXISTS active_policies_view;
DROP VIEW IF EXISTS product_commitment_view;

DROP MATERIALIZED VIEW IF EXISTS reassurance_transaction_view;
DROP MATERIALIZED VIEW IF EXISTS stablecoin_transactions_view;

DROP FUNCTION IF EXISTS get_report_insight
(
  _chain_id                                       uint256,
  _cover_key                                      bytes32,
  _product_key                                    bytes32,
  _incident_date                                  uint256
);

DROP FUNCTION IF EXISTS get_cover_capacity_till
(
  _chain_id                                           uint256,
  _cover_key                                          bytes32,
  _product_key                                        bytes32,
  _till                                               TIMESTAMP WITH TIME ZONE
);

DROP FUNCTION get_commitment
(
  _chain_id                                   uint256,
  _cover_key                                  bytes32,
  _product_key                                bytes32
);

DROP FUNCTION IF EXISTS public.get_stablecoin_value(_chain_id uint256, _amount uint256);

CREATE OR REPLACE FUNCTION get_stablecoin_value(_chain_id uint256, _amount numeric(100, 32))
RETURNS numeric(100, 32)
IMMUTABLE
AS
$$
BEGIN
  IF(_chain_id IN (56)) THEN
    RETURN _amount / POWER(10, 18)::numeric(100, 32);  
  END IF;

  RETURN _amount / POWER(10, 6)::numeric(100, 32);
END
$$
LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION get_npm_value(_amount uint256)
RETURNS numeric(100, 32)
IMMUTABLE
AS
$$
BEGIN
  RETURN _amount / POWER(10, 18)::numeric(100, 32);
END
$$
LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION get_cover_capacity_till
(
  _chain_id                                           uint256,
  _cover_key                                          bytes32,
  _product_key                                        bytes32,
  _till                                               TIMESTAMP WITH TIME ZONE
)
RETURNS numeric
STABLE
AS
$$
  DECLARE _stablecoin_balance                         numeric;
  DECLARE _leverage                                   numeric;
  DECLARE _capital_efficiency                         numeric;
  DECLARE _average_capital_efficiency                 numeric;
  DECLARE _capacity                                   numeric;
  DECLARE _siblings                                   integer;
  DECLARE _multiplier                                 integer = 10000;
BEGIN
  IF(_product_key IS NULL) THEN
    _product_key := string_to_bytes32('');
  END IF;
  
  _stablecoin_balance   := get_tvl_till_date(_chain_id, _cover_key, _till);
  _siblings             := count_products(_chain_id, _cover_key);

  IF(_siblings = 0) THEN
    RETURN _stablecoin_balance;
  END IF;

  SELECT leverage_factor, average_capital_efficiency
  INTO _leverage, _average_capital_efficiency
  FROM get_capital_efficiency(_chain_id, _cover_key);

  SELECT capital_efficiency
  INTO _capital_efficiency
  FROM get_capital_efficiency(_chain_id, _cover_key, _product_key);

  IF(_leverage IS NULL) THEN
    _leverage := 1;
  END IF;
  
  IF(_capital_efficiency IS NULL) THEN
    _capital_efficiency := _multiplier;
  END IF;


  IF(_product_key = string_to_bytes32('')) THEN
    _capacity := (_stablecoin_balance * _leverage * _average_capital_efficiency) / _multiplier;
    RETURN _capacity;
  END IF;
  
  _capacity := (_stablecoin_balance * _leverage * _capital_efficiency) / (_siblings * _multiplier);
  RETURN _capacity;
END
$$
LANGUAGE plpgsql;

CREATE MATERIALIZED VIEW stablecoin_transactions_view
AS
WITH transactions
AS
(
  SELECT
    'Liquidity Added' AS description,
    vault.pods_issued.chain_id,
    factory.vault_deployed.cover_key,
    SUM(get_stablecoin_value(vault.pods_issued.chain_id, vault.pods_issued.liquidity_added)) as total
  FROM vault.pods_issued
  INNER JOIN factory.vault_deployed
  ON factory.vault_deployed.vault = vault.pods_issued.address
  AND factory.vault_deployed.chain_id = vault.pods_issued.chain_id
  GROUP BY vault.pods_issued.chain_id, factory.vault_deployed.cover_key

  UNION ALL

  SELECT
    'Liquidity Removed' AS description,
    vault.pods_redeemed.chain_id,
    factory.vault_deployed.cover_key,
    SUM(get_stablecoin_value(vault.pods_redeemed.chain_id, vault.pods_redeemed.liquidity_released)) as total_liquidity
  FROM vault.pods_redeemed
  INNER JOIN factory.vault_deployed
  ON factory.vault_deployed.vault = vault.pods_redeemed.address
  AND factory.vault_deployed.chain_id = vault.pods_redeemed.chain_id
  GROUP BY vault.pods_redeemed.chain_id, factory.vault_deployed.cover_key

  UNION ALL

  SELECT
    'Fee Earned' AS description,
    chain_id,
    cover_key,
    SUM(get_stablecoin_value(chain_id, fee - platform_fee)) AS total_fee
  FROM policy.cover_purchased
  GROUP BY chain_id, cover_key
)
SELECT description, chain_id, cover_key, total
FROM transactions;


CREATE UNIQUE INDEX description_chain_id_cover_key_stablecoin_transactions_view
ON stablecoin_transactions_view(description, chain_id, cover_key);

CREATE INDEX chain_id_cover_key_stablecoin_transactions_view_inx
ON stablecoin_transactions_view(chain_id, cover_key);



CREATE FUNCTION core.refresh_stablecoin_transactions_view_trigger()
RETURNS trigger
AS
$$
BEGIN
  REFRESH MATERIALIZED VIEW CONCURRENTLY stablecoin_transactions_view;
  RETURN NEW;
END
$$
LANGUAGE plpgsql;


CREATE TRIGGER refresh_stablecoin_transactions_view_trigger
BEFORE INSERT OR UPDATE ON core.transactions
FOR EACH STATEMENT
EXECUTE FUNCTION core.refresh_stablecoin_transactions_view_trigger();

CREATE FUNCTION get_report_insight
(
  _chain_id                                       uint256,
  _cover_key                                      bytes32,
  _product_key                                    bytes32,
  _incident_date                                  uint256
)
RETURNS TABLE
(
  chain_id                                        uint256,
  cover_key                                       bytes32,
  product_key                                     bytes32,
  incident_date                                   uint256,
  report_resolution_timestamp                     uint256,
  report_transaction                              address,
  report_timestamp                                uint256,
  reporter                                        address,
  report_info                                     text,
  reporter_stake                                  numeric,
  dispute_transaction                             address,
  dispute_timestamp                               uint256,
  disputer                                        address,
  dispute_info                                    text,
  disputer_stake                                  numeric,
  total_attestation                               numeric,
  attestation_count                               integer,
  total_refutation                                numeric,
  refutation_count                                integer,
  resolved                                        boolean,
  resolution_transaction                          text,
  resolution_timestamp                            uint256,
  resolution_decision                             boolean,
  resolution_deadline                             uint256,
  emergency_resolved                              boolean,
  emergency_resolution_transaction                text,
  emergency_resolution_timestamp                  uint256,
  emergency_resolution_decision                   boolean,
  emergency_resolution_deadline                   uint256,
  finalized                                       boolean,
  status_enum                                     product_status_type,
  status                                          smallint,
  claim_begins_from                               uint256,
  claim_expires_at                                uint256
)
AS
$$
  DECLARE _total_attestation                      numeric;
  DECLARE _attestation_count                      integer;
  DECLARE _total_refutation                       numeric;
  DECLARE _refutation_count                       integer;
BEGIN
  DROP TABLE IF EXISTS _get_report_insight_result;
  
  CREATE TEMPORARY TABLE _get_report_insight_result
  (
    chain_id                                        uint256,
    cover_key                                       bytes32,
    product_key                                     bytes32,
    incident_date                                   uint256,
    report_resolution_timestamp                     uint256,
    report_transaction                              address,
    report_timestamp                                uint256,
    reporter                                        address,
    report_info                                     text,
    reporter_stake                                  numeric,
    dispute_transaction                             address,
    dispute_timestamp                               uint256,
    disputer                                        address,
    dispute_info                                    text,
    disputer_stake                                  numeric,
    total_attestation                               numeric,
    attestation_count                               integer,
    total_refutation                                numeric,
    refutation_count                                integer,
    resolved                                        boolean,
    resolution_transaction                          text,
    resolution_timestamp                            uint256,
    resolution_decision                             boolean,
    resolution_deadline                             uint256,
    emergency_resolved                              boolean,
    emergency_resolution_transaction                text,
    emergency_resolution_timestamp                  uint256,
    emergency_resolution_decision                   boolean,
    emergency_resolution_deadline                   uint256,
    finalized                                       boolean,
    status_enum                                     product_status_type,
    status                                          smallint,
    claim_begins_from                               uint256,
    claim_expires_at                                uint256
  ) ON COMMIT DROP;

  INSERT INTO _get_report_insight_result(chain_id, cover_key, product_key, incident_date, report_resolution_timestamp, report_transaction, report_timestamp, reporter, report_info, reporter_stake, status_enum)
  SELECT
    consensus.reported.chain_id,
    consensus.reported.cover_key,
    consensus.reported.product_key,
    consensus.reported.incident_date,
    consensus.reported.resolution_timestamp,
    consensus.reported.transaction_hash,
    consensus.reported.block_timestamp,
    consensus.reported.reporter,
    consensus.reported.info,
    get_npm_value(consensus.reported.initial_stake),
    get_product_status(_chain_id, _cover_key, _product_key, _incident_date)
  FROM consensus.reported
  WHERE consensus.reported.chain_id     = _chain_id
  AND consensus.reported.cover_key      = _cover_key
  AND consensus.reported.product_key    = _product_key
  AND consensus.reported.incident_date  = _incident_date;

  UPDATE _get_report_insight_result
  SET
    dispute_transaction   = consensus.disputed.transaction_hash,
    dispute_timestamp     = consensus.disputed.block_timestamp,
    disputer              = consensus.disputed.reporter,
    dispute_info          = consensus.disputed.info,
    disputer_stake        = get_npm_value(consensus.disputed.initial_stake)
  FROM consensus.disputed
  WHERE consensus.disputed.chain_id     = _get_report_insight_result.chain_id
  AND consensus.disputed.cover_key      = _get_report_insight_result.cover_key
  AND consensus.disputed.product_key    = _get_report_insight_result.product_key
  AND consensus.disputed.incident_date  = _get_report_insight_result.incident_date;
  
  SELECT COUNT(*), SUM(get_npm_value(consensus.attested.stake))
  INTO _attestation_count, _total_attestation
  FROM consensus.attested
  WHERE consensus.attested.chain_id     = _chain_id
  AND consensus.attested.cover_key      = _cover_key
  AND consensus.attested.product_key    = _product_key
  AND consensus.attested.incident_date  = _incident_date;

  SELECT COUNT(*), SUM(get_npm_value(consensus.refuted.stake))
  INTO _refutation_count, _total_refutation
  FROM consensus.refuted
  WHERE consensus.refuted.chain_id      = _chain_id
  AND consensus.refuted.cover_key       = _cover_key
  AND consensus.refuted.product_key     = _product_key
  AND consensus.refuted.incident_date   = _incident_date;

  UPDATE _get_report_insight_result
  SET
    total_attestation   = _total_attestation,
    attestation_count   = _attestation_count,
    total_refutation    = _total_refutation,
    refutation_count    = _refutation_count,
    status              = array_length(enum_range(NULL, _get_report_insight_result.status_enum), 1) - 1;


  WITH resolution
  AS
  (
    SELECT
      consensus.resolved.chain_id,
      consensus.resolved.cover_key,
      consensus.resolved.product_key,
      consensus.resolved.incident_date,
      true                                    AS resolved,
      consensus.resolved.transaction_hash     AS resolution_transaction,
      consensus.resolved.block_timestamp      AS resolution_timestamp,
      consensus.resolved.decision             AS resolution_decision, 
      consensus.resolved.resolution_deadline,
      consensus.resolved.claim_begins_from,
      consensus.resolved.claim_expires_at
    FROM consensus.resolved
    WHERE consensus.resolved.chain_id     = _chain_id
    AND consensus.resolved.cover_key      = _cover_key
    AND consensus.resolved.product_key    = _product_key
    AND consensus.resolved.incident_date  = _incident_date
  )
  UPDATE _get_report_insight_result
  SET
    resolved                              = resolution.resolved,
    resolution_transaction                = resolution.resolution_transaction,
    resolution_timestamp                  = resolution.resolution_timestamp,
    resolution_decision                   = resolution.resolution_decision,
    resolution_deadline                   = resolution.resolution_deadline,
    claim_begins_from                     = resolution.claim_begins_from,
    claim_expires_at                      = resolution.claim_expires_at
  FROM resolution
  WHERE resolution.chain_id               = _get_report_insight_result.chain_id
  AND resolution.cover_key                = _get_report_insight_result.cover_key
  AND resolution.product_key              = _get_report_insight_result.product_key
  AND resolution.incident_date            = _get_report_insight_result.incident_date;

  WITH emergency_resolution
  AS
  (
    SELECT
      consensus.resolved.chain_id,
      consensus.resolved.cover_key,
      consensus.resolved.product_key,
      consensus.resolved.incident_date,
      true AS resolved,
      consensus.resolved.transaction_hash     AS resolution_transaction,
      consensus.resolved.block_timestamp      AS resolution_timestamp,
      consensus.resolved.decision             AS resolution_decision, 
      consensus.resolved.resolution_deadline,
      consensus.resolved.claim_begins_from,
      consensus.resolved.claim_expires_at
    FROM consensus.resolved
    WHERE consensus.resolved.chain_id     = _chain_id
    AND consensus.resolved.cover_key      = _cover_key
    AND consensus.resolved.product_key    = _product_key
    AND consensus.resolved.incident_date  = _incident_date
    AND consensus.resolved.emergency      = true
    ORDER BY consensus.resolved.block_timestamp DESC
  )
  UPDATE _get_report_insight_result
  SET
    emergency_resolved                    = emergency_resolution.resolved,
    emergency_resolution_transaction      = emergency_resolution.resolution_transaction,
    emergency_resolution_timestamp        = emergency_resolution.resolution_timestamp,
    emergency_resolution_decision         = emergency_resolution.resolution_decision,
    emergency_resolution_deadline         = emergency_resolution.resolution_deadline,
    claim_begins_from                     = emergency_resolution.claim_begins_from,
    claim_expires_at                      = emergency_resolution.claim_expires_at
  FROM emergency_resolution
  WHERE emergency_resolution.chain_id     = _get_report_insight_result.chain_id
  AND emergency_resolution.cover_key      = _get_report_insight_result.cover_key
  AND emergency_resolution.product_key    = _get_report_insight_result.product_key
  AND emergency_resolution.incident_date  = _get_report_insight_result.incident_date;

  UPDATE _get_report_insight_result
  SET finalized = true
  WHERE EXISTS
  (
    SELECT 1
    FROM consensus.finalized
    WHERE consensus.finalized.chain_id    = _chain_id
    AND consensus.finalized.cover_key     = _cover_key
    AND consensus.finalized.product_key   = _product_key
    AND consensus.finalized.incident_date = _incident_date
  );


  RETURN QUERY
  SELECT * FROM _get_report_insight_result;
END
$$
LANGUAGE plpgsql;


CREATE OR REPLACE VIEW active_policies_view
AS
SELECT
  chain_id,
  cover_key,
  bytes32_to_string(cover_key)                                AS cover_key_string,
  product_key,
  bytes32_to_string(product_key)                              AS product_key_string,
  cx_token,
  expires_on,
  on_behalf_of,
  SUM(get_stablecoin_value(chain_id, amount_to_cover))        AS amount,
  get_active_product_status
  (
    chain_id,
    cover_key,
    product_key
  )                                                           AS product_status_enum,
  array_length(
    enum_range(NULL,  get_active_product_status(chain_id, cover_key, product_key)),
    1
  ) - 1                                                       AS product_status,
  (get_cover_info(chain_id, cover_key)).*,
  (get_product_info(chain_id, cover_key, product_key)).*,
  get_active_incident_date(chain_id, cover_key, product_key)  AS incident_date,
  (get_report_insight(
    chain_id,
    cover_key,
    product_key,
    get_active_incident_date(chain_id, cover_key, product_key)
  )).claim_begins_from,
  (get_report_insight(
    chain_id,
    cover_key,
    product_key,
    get_active_incident_date(chain_id, cover_key, product_key)
  )).claim_expires_at
FROM policy.cover_purchased
WHERE expires_on > extract(epoch FROM NOW() AT TIME ZONE 'UTC')
GROUP BY 
  chain_id,
  cover_key,
  product_key,
  cx_token,
  expires_on,
  on_behalf_of;

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
    SELECT SUM(get_stablecoin_value(policy.cover_purchased.chain_id, policy.cover_purchased.amount_to_cover))
    FROM policy.cover_purchased
  ), 0);
  
  UPDATE _get_explorer_stats_result
  SET liquidity_added =
  COALESCE((
    SELECT SUM(get_stablecoin_value(vault.pods_issued.chain_id, vault.pods_issued.liquidity_added))
    FROM vault.pods_issued
  ), 0);
  
  UPDATE _get_explorer_stats_result
  SET liquidity_removed =
  COALESCE((
    SELECT SUM(get_stablecoin_value(vault.pods_redeemed.chain_id, vault.pods_redeemed.liquidity_released))
    FROM vault.pods_redeemed
  ), 0);
  
  UPDATE _get_explorer_stats_result
  SET claimed =
  COALESCE((
    SELECT SUM(wei_to_ether(cxtoken.claimed.amount))
    FROM cxtoken.claimed
  ), 0);

  UPDATE _get_explorer_stats_result
  SET staked =
  COALESCE((
    SELECT SUM(get_npm_value(amount))
    FROM cover.stake_added
  ), 0);

  UPDATE _get_explorer_stats_result
  SET staked = COALESCE(_get_explorer_stats_result.staked, 0) -
  COALESCE((
    SELECT SUM(get_npm_value(amount))
    FROM cover.stake_removed
  ), 0);
  
  RETURN QUERY
  SELECT * FROM _get_explorer_stats_result;
END
$$
LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION get_tvl_till_date
(
  _date                                     TIMESTAMP WITH TIME ZONE
)
RETURNS numeric
IMMUTABLE
AS
$$
  DECLARE _result numeric;
BEGIN
  SELECT SUM
  (
    get_stablecoin_value(core.transactions.chain_id, core.transactions.transaction_stablecoin_amount)
    *
    CASE WHEN core.transactions.event_name IN ('Claimed') THEN -1 ELSE 1 END
  )
  INTO _result
  FROM core.transactions
  WHERE core.transactions.event_name IN ('CoverPurchased', 'PodsIssued', 'PodsRedeemed', 'Claimed', 'PoolCapitalized')
  AND to_timestamp(core.transactions.block_timestamp) <= _date;

  RETURN COALESCE(_result, 0);
END
$$
LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION get_tvl_till_date
(
  _chain_id                                 uint256,
  _date                                     TIMESTAMP WITH TIME ZONE
)
RETURNS numeric
STABLE
AS
$$
  DECLARE _result numeric;
BEGIN
  SELECT SUM
  (
    get_stablecoin_value(core.transactions.chain_id, core.transactions.transaction_stablecoin_amount)
    *
    CASE WHEN core.transactions.event_name IN ('Claimed') THEN -1 ELSE 1 END
  )
  INTO _result
  FROM core.transactions
  WHERE core.transactions.chain_id = _chain_id
  AND core.transactions.event_name IN ('CoverPurchased', 'PodsIssued', 'PodsRedeemed', 'Claimed', 'PoolCapitalized')
  AND to_timestamp(core.transactions.block_timestamp) <= _date;

  RETURN COALESCE(_result, 0);
END
$$
LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION get_tvl_till_date
(
  _chain_id                                 uint256,
  _cover_key                                bytes32,
  _date                                     TIMESTAMP WITH TIME ZONE
)
RETURNS numeric
STABLE
AS
$$
  DECLARE _result numeric;
BEGIN
  SELECT SUM
  (    
    get_stablecoin_value(core.transactions.chain_id, core.transactions.transaction_stablecoin_amount)
    *
    CASE WHEN core.transactions.event_name IN ('Claimed') THEN -1 ELSE 1 END
  )
  INTO _result
  FROM core.transactions
  WHERE core.transactions.chain_id = _chain_id
  AND core.transactions.ck = _cover_key
  AND core.transactions.event_name IN ('CoverPurchased', 'PodsIssued', 'PodsRedeemed', 'Claimed', 'PoolCapitalized')
  AND to_timestamp(core.transactions.block_timestamp) <= _date;

  RETURN COALESCE(_result, 0);
END
$$
LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION sum_cover_purchased_during
(
  _start                                      TIMESTAMP WITH TIME ZONE,
  _end                                        TIMESTAMP WITH TIME ZONE
)
RETURNS numeric
STABLE
AS
$$
  DECLARE _result numeric;
BEGIN
  SELECT
    SUM(get_stablecoin_value(policy.cover_purchased.chain_id, policy.cover_purchased.fee))
  INTO
    _result
  FROM policy.cover_purchased
  WHERE to_timestamp(policy.cover_purchased.block_timestamp)
  BETWEEN _start AND _end;

  RETURN COALESCE(_result, 0);
END
$$
LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION sum_cover_purchased_during
(
  _chain_id                                   uint256,
  _start                                      TIMESTAMP WITH TIME ZONE,
  _end                                        TIMESTAMP WITH TIME ZONE
)
RETURNS numeric
STABLE
AS
$$
  DECLARE _result numeric;
BEGIN
  SELECT
    SUM(get_stablecoin_value(policy.cover_purchased.chain_id, policy.cover_purchased.fee))
  INTO
    _result
  FROM policy.cover_purchased
  WHERE policy.cover_purchased.chain_id = _chain_id
  AND to_timestamp(policy.cover_purchased.block_timestamp)
  BETWEEN _start AND _end;

  RETURN COALESCE(_result, 0);
END
$$
LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION sum_cover_purchased_during
(
  _chain_id                                   uint256,
  _cover_key                                  bytes32,
  _start                                      TIMESTAMP WITH TIME ZONE,
  _end                                        TIMESTAMP WITH TIME ZONE
)
RETURNS numeric
STABLE
AS
$$
  DECLARE _result numeric;
BEGIN
  SELECT
    SUM(get_stablecoin_value(policy.cover_purchased.chain_id, policy.cover_purchased.fee))
  INTO
    _result
  FROM policy.cover_purchased
  WHERE policy.cover_purchased.chain_id = _chain_id
  AND policy.cover_purchased.cover_key = _cover_key
  AND to_timestamp(policy.cover_purchased.block_timestamp)
  BETWEEN _start AND _end;

  RETURN COALESCE(_result, 0);
END
$$
LANGUAGE plpgsql;

CREATE FUNCTION get_min_first_reporting_stake(_chain_id uint256, _cover_key bytes32)
RETURNS numeric
STABLE
AS
$$
  DECLARE _min_stake                            numeric;
BEGIN
  SELECT get_npm_value(consensus.first_reporting_stake_set.current)
  INTO _min_stake
  FROM consensus.first_reporting_stake_set
  WHERE consensus.first_reporting_stake_set.chain_id = _chain_id
  AND consensus.first_reporting_stake_set.cover_key = _cover_key
  ORDER BY consensus.first_reporting_stake_set.block_timestamp DESC
  LIMIT 1;

  IF(_min_stake IS NOT NULL) THEN
    RETURN _min_stake;
  END IF;

  SELECT get_npm_value(consensus.first_reporting_stake_set.current)
  INTO _min_stake
  FROM consensus.first_reporting_stake_set
  WHERE consensus.first_reporting_stake_set.chain_id = _chain_id
  AND consensus.first_reporting_stake_set.cover_key = string_to_bytes32('')
  ORDER BY consensus.first_reporting_stake_set.block_timestamp DESC
  LIMIT 1;

  IF(_min_stake IS NOT NULL) THEN
    RETURN _min_stake;
  END IF;

  SELECT get_npm_value(config_cover_view.minimum_first_reporting_stake)
  INTO _min_stake
  FROM config_cover_view
  WHERE config_cover_view.chain_id = _chain_id
  AND config_cover_view.cover_key = _cover_key;

  IF(_min_stake IS NOT NULL) THEN
    RETURN _min_stake;
  END IF;

  SELECT get_npm_value(protocol.initialized.first_reporting_stake)
  INTO _min_stake
  FROM protocol.initialized
  WHERE protocol.initialized.chain_id = _chain_id;
  
  RETURN COALESCE(_min_stake, 0);
END
$$
LANGUAGE plpgsql;


CREATE FUNCTION get_cover_stats
(
  _chain_id                               uint256,
  _cover_key                              bytes32,
  _product_key                            bytes32,
  _account                                address
)
RETURNS TABLE
(
  cover_key                               bytes32,
  cover_key_string                        text,
  product_key                             bytes32,
  product_key_string                      text,
  tvl                                     numeric,
  active_commitment                       numeric,
  available_for_underwriting              numeric,
  capacity                                numeric,
  coverage_lag                            numeric,
  policy_rate_floor                       integer,
  policy_rate_ceiling                     integer,
  reporter_commission                     integer,
  claim_platform_fee                      integer,
  reporting_period                        integer,
  product_status_enum                     product_status_type,
  product_status                          integer,
  min_reporting_stake                     numeric,
  active_incident_date                    integer,
  requires_whitelist                      boolean,
  is_user_whitelisted                     boolean
)
AS
$$
BEGIN
  IF(_product_key IS NULL) THEN
    _product_key := string_to_bytes32('');
  END IF;

  DROP TABLE IF EXISTS _get_cover_stats_result CASCADE;
  CREATE TEMPORARY TABLE _get_cover_stats_result
  (
    cover_key                               bytes32,
    cover_key_string                        text,
    product_key                             bytes32,
    product_key_string                      text,
    tvl                                     numeric,
    active_commitment                       numeric DEFAULT 0,
    available_for_underwriting              numeric,
    capacity                                numeric,
    coverage_lag                            numeric,
    policy_rate_floor                       integer,
    policy_rate_ceiling                     integer,
    reporter_commission                     integer,
    claim_platform_fee                      integer,
    reporting_period                        integer,
    product_status_enum                     product_status_type,
    product_status                          integer,
    min_reporting_stake                     numeric,
    active_incident_date                    integer,
    requires_whitelist                      boolean,
    is_user_whitelisted                     boolean
  ) ON COMMIT DROP;
  
  INSERT INTO _get_cover_stats_result
  (
    cover_key,
    cover_key_string,
    product_key,
    product_key_string,
    tvl,
    capacity,
    coverage_lag,
    policy_rate_floor,
    policy_rate_ceiling,
    reporter_commission,
    claim_platform_fee,
    product_status_enum,
    min_reporting_stake,
    active_incident_date,
    is_user_whitelisted
  )
  SELECT
    _cover_key,
    bytes32_to_string(_cover_key),
    _product_key,
    bytes32_to_string(_product_key),
    get_tvl_till_date(_chain_id, _cover_key, 'infinity'),
    get_cover_capacity_till(_chain_id, _cover_key, _product_key, 'infinity'),
    get_coverage_lag(_chain_id, _cover_key),
    get_policy_floor(_chain_id, _cover_key),
    get_policy_ceiling(_chain_id, _cover_key),
    get_reporter_commission(_chain_id),
    get_claim_platform_fee(_chain_id),
    get_active_product_status(_chain_id, _cover_key, _product_key),
    get_min_first_reporting_stake(_chain_id, _cover_key),
    get_active_incident_date(_chain_id, _cover_key, _product_key),
    check_if_user_whitelisted(_chain_id, _cover_key, _product_key, _account);
  
  UPDATE _get_cover_stats_result
  SET active_commitment = product_commitment_view.commitment
  FROM product_commitment_view
  WHERE product_commitment_view.chain_id = _chain_id
  AND product_commitment_view.cover_key = _cover_key
  AND product_commitment_view.product_key = _product_key;
  
  
  UPDATE _get_cover_stats_result
  SET requires_whitelist = 
  (
    SELECT cover.cover_created.requires_whitelist
    FROM cover.cover_created
    WHERE cover.cover_created.chain_id = _chain_id
    AND cover.cover_created.cover_key = _cover_key
  );
  
  UPDATE _get_cover_stats_result
  SET 
    available_for_underwriting = _get_cover_stats_result.capacity - _get_cover_stats_result.active_commitment,
    product_status = array_length(enum_range(NULL, _get_cover_stats_result.product_status_enum), 1) - 1;

  UPDATE _get_cover_stats_result
  SET reporting_period = 
  (
    SELECT config_cover_view.reporting_period
    FROM config_cover_view
    WHERE config_cover_view.chain_id = _chain_id
    AND config_cover_view.cover_key = _cover_key
    LIMIT 1
  );

  RETURN QUERY
  SELECT * FROM _get_cover_stats_result;
END
$$
LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION get_reassurance_till_date
(
  _date                                     TIMESTAMP WITH TIME ZONE
)
RETURNS numeric
IMMUTABLE
AS
$$
  DECLARE _added numeric;
  DECLARE _capitalized numeric;
BEGIN
  SELECT SUM(get_stablecoin_value(chain_id, amount))
  INTO _added
  FROM reassurance.reassurance_added
  WHERE to_timestamp(block_timestamp) <= _date;
  
  SELECT SUM(get_stablecoin_value(chain_id, amount))
  INTO _capitalized
  FROM reassurance.pool_capitalized
  WHERE to_timestamp(block_timestamp) <= _date;

  RETURN COALESCE(_added, 0) - COALESCE(_capitalized, 0);
END
$$
LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION get_reassurance_till_date
(
  _chain_id                                 uint256,
  _date                                     TIMESTAMP WITH TIME ZONE
)
RETURNS numeric
IMMUTABLE
AS
$$
  DECLARE _added                            numeric;
  DECLARE _capitalized                      numeric;
BEGIN
  SELECT SUM(get_stablecoin_value(chain_id, amount))
  INTO _added
  FROM reassurance.reassurance_added
  WHERE to_timestamp(block_timestamp) <= _date
  AND chain_id = _chain_id;
  
  SELECT SUM(get_stablecoin_value(chain_id, amount))
  INTO _capitalized
  FROM reassurance.pool_capitalized
  WHERE to_timestamp(block_timestamp) <= _date
  AND chain_id = _chain_id;

  RETURN COALESCE(_added, 0) - COALESCE(_capitalized, 0);
END
$$
LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION get_reassurance_till_date
(
  _chain_id                                 uint256,
  _cover_key                                bytes32,
  _date                                     TIMESTAMP WITH TIME ZONE
)
RETURNS numeric
IMMUTABLE
AS
$$
  DECLARE _added                            numeric;
  DECLARE _capitalized                      numeric;
BEGIN
  SELECT SUM(get_stablecoin_value(chain_id, amount))
  INTO _added
  FROM reassurance.reassurance_added
  WHERE to_timestamp(block_timestamp) <= _date
  AND chain_id = _chain_id
  AND cover_key = _cover_key;
  
  SELECT SUM(get_stablecoin_value(chain_id, amount))
  INTO _capitalized
  FROM reassurance.pool_capitalized
  WHERE to_timestamp(block_timestamp) <= _date
  AND chain_id = _chain_id
  AND cover_key = _cover_key;

  RETURN COALESCE(_added, 0) - COALESCE(_capitalized, 0);
END
$$
LANGUAGE plpgsql;




CREATE OR REPLACE FUNCTION get_commitment
(
  _chain_id                                   uint256,
  _cover_key                                  bytes32,
  _product_key                                bytes32
)
RETURNS numeric
STABLE
AS
$$
  DECLARE _commitment                         numeric;
  DECLARE _paid                               numeric;
  DECLARE _incident_date                      uint256;
  DECLARE _starts_from                        uint256 = EXTRACT(epoch FROM NOW() AT TIME ZONE 'UTC');
BEGIN
  _incident_date := get_active_incident_date(_chain_id, _cover_key, _product_key);
  
  IF(_product_key IS NULL) THEN
    _product_key := string_to_bytes32('');
  END IF;

  IF(_incident_date > 0) THEN
    _starts_from := _incident_date;
  END IF;

  SELECT SUM(get_stablecoin_value(chain_id, amount_to_cover)) AS commitment
  INTO _commitment
  FROM policy.cover_purchased  
  WHERE expires_on > _starts_from
  AND policy.cover_purchased.chain_id = _chain_id
  AND policy.cover_purchased.cover_key = _cover_key
  AND policy.cover_purchased.product_key = _product_key;

  SELECT SUM(wei_to_ether(cxtoken.claimed.amount))
  INTO _paid
  FROM cxtoken.claimed
  WHERE cxtoken.claimed.chain_id = _chain_id
  AND cxtoken.claimed.cover_key = _cover_key
  AND cxtoken.claimed.product_key = _product_key
  AND cxtoken.claimed.cx_token IN
  (
    SELECT factory.cx_token_deployed.cx_token
    FROM factory.cx_token_deployed
    WHERE expiry_date > EXTRACT(epoch FROM NOW() AT TIME ZONE 'UTC')
    AND factory.cx_token_deployed.chain_id = _chain_id
    AND factory.cx_token_deployed.cover_key = _cover_key
    AND factory.cx_token_deployed.product_key = _product_key
  );

  RETURN COALESCE(_commitment, 0) - COALESCE(_paid, 0);
END
$$
LANGUAGE plpgsql;

CREATE FUNCTION get_sum_commitment
(
  _chain_id                                   uint256,
  _cover_key                                  bytes32
)
RETURNS numeric
STABLE
AS
$$
BEGIN
  RETURN
    SUM(get_commitment(_chain_id, _cover_key, config_product_view.product_key))
  FROM config_product_view
  WHERE config_product_view.chain_id = _chain_id
  AND config_product_view.cover_key = _cover_key;
END
$$
LANGUAGE plpgsql;

CREATE FUNCTION get_product_summary(_account address DEFAULT '')
RETURNS TABLE
(
  chain_id                              numeric,
  cover_key                             bytes32,
  cover_key_string                      text,
  cover_info                            text,
  cover_info_details                    text,
  product_key                           bytes32,
  product_key_string                    text,
  product_info                          text,
  product_info_details                  text,
  product_status_enum                   product_status_type,
  product_status                        integer,
  floor                                 numeric,
  ceiling                               numeric,
  leverage                              numeric,
  capital_efficiency                    numeric,
  capacity                              numeric,
  commitment                            numeric,
  available_for_underwriting            numeric,
  utilization_ratio                     numeric,
  reassurance                           numeric,
  tvl                                   numeric,
  coverage_lag                          numeric,
  supports_products                     boolean,
  requires_whitelist                    boolean,
  min_reporting_stake                   numeric,
  active_incident_date                  integer,
  reporter_commission                   integer,
  reporting_period                      integer,
  claim_platform_fee                    integer,
  is_user_whitelisted                   boolean
)
AS
$$
BEGIN
  CREATE TEMPORARY TABLE _get_product_summary_result
  (
    chain_id                            numeric,
    cover_key                           bytes32,
    cover_key_string                    text,
    cover_info                          text,
    cover_info_details                  text,
    product_key                         bytes32,
    product_key_string                  text,
    product_info                        text,
    product_info_details                text,
    product_status_enum                 product_status_type,
    product_status                      integer,
    floor                               numeric DEFAULT(0),
    ceiling                             numeric DEFAULT(0),
    leverage                            numeric DEFAULT(0),
    capital_efficiency                  numeric DEFAULT(0),
    capacity                            numeric DEFAULT(0),
    commitment                          numeric DEFAULT(0),
    available_for_underwriting          numeric DEFAULT(0),
    utilization_ratio                   numeric,
    reassurance                         numeric DEFAULT(0),
    tvl                                 numeric DEFAULT(0),
    coverage_lag                        numeric DEFAULT(0),
    supports_products                   boolean DEFAULT(false),
    requires_whitelist                  boolean DEFAULT(false),
    min_reporting_stake                 numeric,
    active_incident_date                integer,
    reporter_commission                 integer,
    reporting_period                    integer,
    claim_platform_fee                  integer,
    is_user_whitelisted                 boolean
  ) ON COMMIT DROP;
  
  INSERT INTO _get_product_summary_result(chain_id, cover_key, cover_key_string, product_key, product_key_string, capital_efficiency)
  SELECT
    config_product_view.chain_id,
    config_product_view.cover_key,
    bytes32_to_string(config_product_view.cover_key),
    config_product_view.product_key,
    bytes32_to_string(config_product_view.product_key),
    config_product_view.capital_efficiency
  FROM config_product_view
  WHERE config_product_view.chain_id IN
  (
    SELECT DISTINCT core.transactions.chain_id
    FROM core.transactions
  );
  
  INSERT INTO _get_product_summary_result(chain_id, cover_key, cover_key_string, leverage, capital_efficiency)
  SELECT
    cover.cover_created.chain_id,
    cover.cover_created.cover_key,
    bytes32_to_string(cover.cover_created.cover_key),
    1 AS leverage,
    10000 AS capital_efficiency
  FROM cover.cover_created;

  UPDATE _get_product_summary_result
  SET supports_products           = is_diversified(_get_product_summary_result.chain_id, _get_product_summary_result.cover_key)
  WHERE _get_product_summary_result.product_key IS NULL;

  UPDATE _get_product_summary_result
  SET
    leverage                      = config_cover_view.leverage,
    floor                         = config_cover_view.policy_floor,
    ceiling                       = config_cover_view.policy_ceiling
  FROM config_cover_view
  WHERE config_cover_view.chain_id = _get_product_summary_result.chain_id
  AND config_cover_view.cover_key = _get_product_summary_result.cover_key;
  
  UPDATE _get_product_summary_result
  SET 
    capacity                      = get_cover_capacity_till(_get_product_summary_result.chain_id, _get_product_summary_result.cover_key, _get_product_summary_result.product_key, 'infinity'),
    commitment                    = CASE 
                                    WHEN _get_product_summary_result.supports_products 
                                    THEN get_sum_commitment(_get_product_summary_result.chain_id, _get_product_summary_result.cover_key)
                                    ELSE get_commitment(_get_product_summary_result.chain_id, _get_product_summary_result.cover_key, _get_product_summary_result.product_key)
                                    END,
    reporting_period              = get_reporting_period(_get_product_summary_result.chain_id, _get_product_summary_result.cover_key),
    requires_whitelist            = check_if_requires_whitelist(_get_product_summary_result.chain_id, _get_product_summary_result.cover_key),
    product_status_enum           = get_active_product_status(_get_product_summary_result.chain_id, _get_product_summary_result.cover_key,  _get_product_summary_result.product_key),
    active_incident_date          = get_active_incident_date(_get_product_summary_result.chain_id, _get_product_summary_result.cover_key,  _get_product_summary_result.product_key),
    min_reporting_stake           = get_min_first_reporting_stake(_get_product_summary_result.chain_id, _get_product_summary_result.cover_key),
    coverage_lag                  = get_coverage_lag(_get_product_summary_result.chain_id, _get_product_summary_result.cover_key),
    reporter_commission           = get_reporter_commission(_get_product_summary_result.chain_id),
    claim_platform_fee            = get_claim_platform_fee(_get_product_summary_result.chain_id),
    reassurance                   = get_reassurance_till_date(_get_product_summary_result.chain_id, _get_product_summary_result.cover_key, 'infinity'),
    is_user_whitelisted           = check_if_user_whitelisted(_get_product_summary_result.chain_id, _get_product_summary_result.cover_key, _get_product_summary_result.product_key, _account),
    tvl                           = get_tvl_till_date(_get_product_summary_result.chain_id, _get_product_summary_result.cover_key, 'infinity'),
    product_info                  = (SELECT p.product_info FROM get_product_info(_get_product_summary_result.chain_id, _get_product_summary_result.cover_key,  _get_product_summary_result.product_key) AS p),
    product_info_details          = (SELECT p.product_info_details FROM get_product_info(_get_product_summary_result.chain_id, _get_product_summary_result.cover_key,  _get_product_summary_result.product_key) AS p),
    cover_info                    = (SELECT c.cover_info FROM get_cover_info(_get_product_summary_result.chain_id, _get_product_summary_result.cover_key) AS c),
    cover_info_details            = (SELECT c.cover_info_details FROM get_cover_info(_get_product_summary_result.chain_id, _get_product_summary_result.cover_key) AS c);

  UPDATE _get_product_summary_result
  SET
    available_for_underwriting    = _get_product_summary_result.capacity - _get_product_summary_result.commitment,
    utilization_ratio             = CASE WHEN _get_product_summary_result.capacity = 0 THEN 0 ELSE _get_product_summary_result.commitment / _get_product_summary_result.capacity END,
    product_status                = array_length(enum_range(NULL, _get_product_summary_result.product_status_enum), 1) - 1;

  RETURN QUERY
  SELECT * FROM _get_product_summary_result;
END
$$
LANGUAGE plpgsql;

CREATE OR REPLACE VIEW cover_expiring_this_month_view
AS
SELECT
  cover_key,
  bytes32_to_string(cover_key) AS cover_key_string,
  product_key,
  bytes32_to_string(product_key) AS product_key_string,
  SUM(get_stablecoin_value(chain_id, amount_to_cover)) AS total_protection
FROM policy.cover_purchased
WHERE to_timestamp(expires_on) = 
(
  date_trunc('MONTH', NOW() AT TIME ZONE 'UTC') + INTERVAL '1 MONTH' * 
    CASE
      WHEN EXTRACT(DAY FROM NOW() AT TIME ZONE 'UTC') > 24
      THEN 2
      ELSE 1
    END
    - INTERVAL '1 second'
) AT TIME ZONE 'UTC'
GROUP BY cover_key, product_key;


CREATE OR REPLACE VIEW cover_premium_by_pool
AS
SELECT
  cover_key,
  bytes32_to_string(cover_key) AS cover_key_string,
  product_key,
  bytes32_to_string(product_key) AS product_key_string,
  SUM(get_stablecoin_value(chain_id, fee)) AS total_premium
FROM policy.cover_purchased
GROUP BY cover_key, product_key;

CREATE OR REPLACE VIEW cover_sold_by_pool_view
AS
SELECT
  cover_key,
  bytes32_to_string(cover_key) AS cover_key_string,
  product_key,
  bytes32_to_string(product_key) AS product_key_string,
  SUM(get_stablecoin_value(chain_id, amount_to_cover)) AS total_protection
FROM policy.cover_purchased
GROUP BY cover_key, product_key;

CREATE OR REPLACE VIEW protection_by_month_view
AS
WITH info
AS
(
  SELECT
    chain_id,
    expires_on,
    cover_duration AS duration,
    to_char(to_timestamp(expires_on), 'Mon-YY') AS expiry,
    SUM(get_stablecoin_value(chain_id, amount_to_cover)) AS protection,
    SUM(get_stablecoin_value(chain_id, fee)) AS income,
    to_timestamp(expires_on) < NOW() AS expired
  FROM policy.cover_purchased
  GROUP BY chain_id, expires_on, duration
  ORDER BY chain_id, expires_on DESC
),
summary
AS
(  
  SELECT
    chain_id,
    to_timestamp(expires_on) AS expires_on,
    expiry,
    duration,
    protection,
    income,
    expired,
    ((income * 12) / (protection * duration)) AS fee_rate
  FROM info
),
result
AS
(
  SELECT
    chain_id,
    expires_on,
    expiry,
    SUM(protection) AS protection,
    SUM(income) AS income,
    expired,
    AVG(fee_rate) AS fee_rate
  FROM summary
  GROUP BY chain_id, expires_on, expiry, expired
)
SELECT
  result.chain_id,
  config_blockchain_network_view.network_name,
  result.expires_on,
  result.expiry,
  result.protection,
  result.income,
  result.expired,
  result.fee_rate
FROM result
INNER JOIN config_blockchain_network_view
ON config_blockchain_network_view.chain_id = result.chain_id;

CREATE OR REPLACE VIEW expired_policies_view
AS
WITH summary
AS
(
  SELECT
    chain_id,
    cover_key,
    product_key,
    on_behalf_of,
    block_timestamp,
    expires_on,
    cx_token,
    get_incident_date_by_expiry_date
    (
      chain_id,
      cover_key,
      product_key,
      block_timestamp,
      expires_on
    )                                                   AS incident_date,
    get_stablecoin_value(chain_id, amount_to_cover)     AS amount_to_cover
  FROM policy.cover_purchased
  WHERE expires_on <= extract(epoch FROM NOW() AT TIME ZONE 'UTC')
)
SELECT
  chain_id,
  cover_key,
  bytes32_to_string(cover_key)            AS cover_key_string,
  product_key,
  bytes32_to_string(product_key)          AS product_key_string,
  cx_token,
  expires_on,
  on_behalf_of,
  SUM(amount_to_cover)                    AS amount,
  incident_date,
  get_product_status
  (
      chain_id,
      cover_key,
      product_key,
      incident_date
  )                                       AS product_status_enum,
  array_length(
    enum_range(
      NULL,  
      get_product_status
      (
          chain_id,
          cover_key,
          product_key,
          incident_date
      )
    ),
    1
  ) - 1                                         AS product_status,
  (get_cover_info(chain_id, cover_key)).*,
  (get_product_info(chain_id, cover_key, product_key)).*
FROM summary
GROUP BY
  chain_id,
  cover_key,
  product_key,
  on_behalf_of,
  cx_token,
  expires_on, 
  incident_date;

-- SELECT * FROM expired_policies_view
-- WHERE on_behalf_of = '0x201bcc0d375f10543e585fbb883b36c715c959b3'
-- AND chain_id = 84531

CREATE OR REPLACE VIEW my_policies_view
AS
WITH policy_txs
AS
(
  SELECT
    chain_id,
    cover_key,
    product_key,
    block_timestamp,
    cx_token,
    transaction_hash,
    on_behalf_of                                        AS account,
    get_stablecoin_value(chain_id, amount_to_cover)     AS cxtoken_amount,
    get_stablecoin_value(chain_id, fee)                 AS stablecoin_amount,
    'cover_purchased'                                   AS tx_type
  FROM policy.cover_purchased
  UNION ALL
  SELECT
    chain_id,
    cover_key,
    product_key,
    block_timestamp,
    cx_token,
    transaction_hash,
    account                                     AS account,
    wei_to_ether(amount)                        AS cxtoken_amount,
    wei_to_ether(claimed)                       AS stablecoin_amount,
    'claimed'                                   AS tx_type
  FROM cxtoken.claimed
)

SELECT
  policy_txs.chain_id,
  policy_txs.cover_key,
  policy_txs.product_key,
  policy_txs.block_timestamp,
  policy_txs.cx_token,
  policy_txs.transaction_hash,
  policy_txs.account,
  policy_txs.cxtoken_amount,
  policy_txs.stablecoin_amount,
  policy_txs.tx_type,
  bytes32_to_string(policy_txs.cover_key)       AS cover_key_string,
  bytes32_to_string(policy_txs.product_key)     AS product_key_string,
  'cxUSD'                                       AS token_symbol,
  factory.cx_token_deployed.token_name
FROM policy_txs
INNER JOIN factory.cx_token_deployed
ON factory.cx_token_deployed.chain_id           = policy_txs.chain_id
AND factory.cx_token_deployed.cover_key         = policy_txs.cover_key
AND factory.cx_token_deployed.product_key       = policy_txs.product_key
AND factory.cx_token_deployed.cx_token          = policy_txs.cx_token;

CREATE OR REPLACE VIEW ve_stats_view
AS
SELECT SUM(get_npm_value(amount)) AS total_vote_locked, AVG(duration_in_weeks) AS average_lock
FROM ve.vote_escrow_lock;

CREATE or replace FUNCTION get_gauge_pools()
RETURNS TABLE
(
  chain_id                                          numeric,
  key                                               bytes32,
  epoch_duration                                    uint256,
  pool_address                                      address,
  staking_token                                     address,
  name                                              text,
  info                                              text,
  platform_fee                                      numeric,
  token                                             address,
  lockup_period_in_blocks                           uint256,
  ratio                                             uint256,
  active                                            boolean,
  current_epoch                                     uint256,
  current_distribution                              numeric
)
AS
$$
  DECLARE _r                                        RECORD;
BEGIN
  DROP TABLE IF EXISTS _get_gauge_pools_result;
  CREATE TEMPORARY TABLE _get_gauge_pools_result
  (
    chain_id                                        numeric,
    key                                             bytes32,
    epoch_duration                                  uint256,
    pool_address                                    address,
    staking_token                                   address,
    name                                            text,
    info                                            text,
    platform_fee                                    numeric,
    token                                           address,
    lockup_period_in_blocks                         uint256,
    ratio                                           uint256,    
    active                                          boolean DEFAULT(true),
    current_epoch                                   uint256,
    current_distribution                            numeric
  ) ON COMMIT DROP;

  FOR _r IN
  (
    SELECT *
    FROM gauge_pool_lifecycle_view
    ORDER BY block_number::numeric
  )
  LOOP
    IF(_r.action = 'add') THEN
      INSERT INTO _get_gauge_pools_result
      SELECT
        liquidity_gauge_pool_set.chain_id,
        liquidity_gauge_pool_set.key,
        liquidity_gauge_pool_set.epoch_duration,
        liquidity_gauge_pool_set.address,
        liquidity_gauge_pool_set.staking_token,        
        liquidity_gauge_pool_set.name,
        liquidity_gauge_pool_set.info,
        liquidity_gauge_pool_set.platform_fee,
        liquidity_gauge_pool_set.staking_token,
        liquidity_gauge_pool_set.lockup_period_in_blocks,
        liquidity_gauge_pool_set.ve_boost_ratio
      FROM ve.liquidity_gauge_pool_set
      WHERE liquidity_gauge_pool_set.id = _r.id;
    END IF;
    
    IF(_r.action = 'edit') THEN
      UPDATE _get_gauge_pools_result
      SET 
        name = CASE WHEN COALESCE(liquidity_gauge_pool_set.name, '') = '' THEN _get_gauge_pools_result.name ELSE liquidity_gauge_pool_set.name END,
        info = CASE WHEN COALESCE(liquidity_gauge_pool_set.info, '') = '' THEN _get_gauge_pools_result.info ELSE liquidity_gauge_pool_set.info END,
        platform_fee = CASE WHEN COALESCE(liquidity_gauge_pool_set.platform_fee, 0) = 0 THEN _get_gauge_pools_result.platform_fee ELSE liquidity_gauge_pool_set.platform_fee END,
        lockup_period_in_blocks = CASE WHEN COALESCE(liquidity_gauge_pool_set.lockup_period_in_blocks, 0) = 0 THEN _get_gauge_pools_result.lockup_period_in_blocks ELSE liquidity_gauge_pool_set.lockup_period_in_blocks END,
        ratio = CASE WHEN COALESCE(liquidity_gauge_pool_set.ve_boost_ratio, 0) = 0 THEN _get_gauge_pools_result.ratio ELSE liquidity_gauge_pool_set.ve_boost_ratio END
      FROM ve.liquidity_gauge_pool_set AS liquidity_gauge_pool_set
      WHERE _get_gauge_pools_result.key = liquidity_gauge_pool_set.key
      AND _get_gauge_pools_result.chain_id = liquidity_gauge_pool_set.chain_id
      AND liquidity_gauge_pool_set.id = _r.id;
    END IF;
    
    IF(_r.action = 'deactivate') THEN
      UPDATE _get_gauge_pools_result
      SET active = false
      WHERE _get_gauge_pools_result.chain_id = _r.chain_id
      AND _get_gauge_pools_result.key = _r.key;      
    END IF;

    IF(_r.action = 'activate') THEN
      UPDATE _get_gauge_pools_result
      SET active = true
      WHERE _get_gauge_pools_result.chain_id = _r.chain_id
      AND _get_gauge_pools_result.key = _r.key;      
    END IF;

    IF(_r.action = 'delete') THEN
      DELETE FROM _get_gauge_pools_result
      WHERE _get_gauge_pools_result.chain_id = _r.chain_id
      AND _get_gauge_pools_result.key = _r.key;      
    END IF;
  END LOOP;
  
  --@todo: drop this when address bug of the `ve.liquidity_gauge_pool_set` is fixed
  UPDATE _get_gauge_pools_result
  SET pool_address = ve.liquidity_gauge_pool_added.pool
  FROM ve.liquidity_gauge_pool_added
  WHERE ve.liquidity_gauge_pool_added.chain_id = _get_gauge_pools_result.chain_id
  AND ve.liquidity_gauge_pool_added.key = _get_gauge_pools_result.key
  AND _get_gauge_pools_result.pool_address = '0x0000000000000000000000000000000000000000';
  
  UPDATE _get_gauge_pools_result
  SET
    current_epoch = ve.gauge_set.epoch,
    current_distribution = get_npm_value(ve.gauge_set.distribution)
  FROM ve.gauge_set
  WHERE ve.gauge_set.key = _get_gauge_pools_result.key
  AND ve.gauge_set.chain_id = _get_gauge_pools_result.chain_id
  AND ve.gauge_set.epoch = (SELECT MAX(epoch) FROM ve.gauge_set);
  

  -- @todo: The event EpochDurationUpdated hasn't been synchronized yet  
  -- UPDATE _get_gauge_pools_result
  -- SET epoch_duration =
  -- (
  --   SELECT current
  --   FROM ve.epoch_duration_updated
  --   WHERE ve.epoch_duration_updated.key = _get_gauge_pools_result.key
  --   AND ve.epoch_duration_updated.chain_id = _get_gauge_pools_result.chain_id    
  --   ORDER BY ve.epoch_duration_updated.block_timestamp DESC
  --   LIMIT 1
  -- );
  

  RETURN QUERY
  SELECT * FROM _get_gauge_pools_result;
END
$$
LANGUAGE plpgsql;


CREATE OR REPLACE VIEW ve.liquidity_gauge_pool_transactions
AS
SELECT
  ve.liquidity_gauge_deposited.chain_id,
  ve.liquidity_gauge_deposited.block_timestamp,
  ve.liquidity_gauge_deposited.transaction_hash,
  ve.liquidity_gauge_deposited.account,
  'Added' AS event,
  ve.liquidity_gauge_deposited.key,
  ve.liquidity_gauge_deposited.staking_token AS token,
  get_npm_value(ve.liquidity_gauge_deposited.amount) AS amount
FROM ve.liquidity_gauge_deposited
UNION ALL
SELECT
  ve.liquidity_gauge_withdrawn.chain_id,
  ve.liquidity_gauge_withdrawn.block_timestamp,
  ve.liquidity_gauge_withdrawn.transaction_hash,
  ve.liquidity_gauge_withdrawn.account,
  'Removed' AS event,
  ve.liquidity_gauge_withdrawn.key,
  ve.liquidity_gauge_withdrawn.staking_token AS token,
  get_npm_value(ve.liquidity_gauge_withdrawn.amount)
FROM ve.liquidity_gauge_withdrawn
UNION ALL
SELECT
  ve.liquidity_gauge_rewards_withdrawn.chain_id,
  ve.liquidity_gauge_rewards_withdrawn.block_timestamp,
  ve.liquidity_gauge_rewards_withdrawn.transaction_hash,
  ve.liquidity_gauge_rewards_withdrawn.account,
  'Get Reward' AS event,
  ve.liquidity_gauge_rewards_withdrawn.key,
  get_npm(ve.liquidity_gauge_rewards_withdrawn.chain_id) AS token,
  get_npm_value(ve.liquidity_gauge_rewards_withdrawn.rewards - ve.liquidity_gauge_rewards_withdrawn.platform_fee)
FROM ve.liquidity_gauge_rewards_withdrawn;





CREATE OR REPLACE FUNCTION get_user_milestones
(
  _account                        address
)
RETURNS TABLE
(
  total_policy_purchased          uint256,
  total_liquidity_added           uint256
)
STABLE
AS
$$ 
  DECLARE total_policy_purchased  uint256;
  DECLARE total_liquidity_added   uint256;
BEGIN
  SELECT
    SUM(get_stablecoin_value(chain_id, amount_to_cover))          INTO total_policy_purchased
  FROM policy.cover_purchased
  WHERE on_behalf_of              = _account;

  SELECT
    SUM(get_stablecoin_value(chain_id, liquidity_added))          INTO total_liquidity_added
  FROM vault.pods_issued
  WHERE account                   = _account;
  
  RETURN QUERY
  SELECT
    COALESCE(total_policy_purchased, 0::uint256),
    COALESCE(total_liquidity_added, 0::uint256);

END
$$
LANGUAGE plpgsql;

CREATE MATERIALIZED VIEW reassurance_transaction_view
AS
SELECT
  'Reassurance Added' AS description,  
  reassurance.reassurance_added.chain_id,
  reassurance.reassurance_added.cover_key,
  SUM(get_stablecoin_value(reassurance.reassurance_added.chain_id, reassurance.reassurance_added.amount)) AS total
FROM reassurance.reassurance_added
GROUP BY 
  reassurance.reassurance_added.chain_id,
  reassurance.reassurance_added.cover_key
UNION ALL
SELECT
  'Pool Capitalized' AS description,  
  reassurance.pool_capitalized.chain_id,
  reassurance.pool_capitalized.cover_key,
  SUM(get_stablecoin_value(reassurance.pool_capitalized.chain_id, reassurance.pool_capitalized.amount)) * -1
FROM reassurance.pool_capitalized
GROUP BY 
  reassurance.pool_capitalized.chain_id,
  reassurance.pool_capitalized.cover_key;

CREATE UNIQUE INDEX description_chain_id_cover_key_reassurance_transaction_view
ON reassurance_transaction_view(description, chain_id, cover_key);

CREATE INDEX chain_id_cover_key_reassurance_transaction_view_inx
ON reassurance_transaction_view(chain_id, cover_key);

CREATE FUNCTION core.refresh_reassurance_transaction_view_trigger()
RETURNS trigger
AS
$$
BEGIN
  REFRESH MATERIALIZED VIEW CONCURRENTLY reassurance_transaction_view;
  RETURN NEW;
END
$$
LANGUAGE plpgsql;


CREATE TRIGGER refresh_reassurance_transaction_view_trigger
BEFORE INSERT OR UPDATE ON core.transactions
FOR EACH STATEMENT
EXECUTE FUNCTION core.refresh_reassurance_transaction_view_trigger();

CREATE OR REPLACE VIEW cover_reassurance_view
AS
SELECT chain_id, cover_key, SUM(total) AS reassurance
FROM reassurance_transaction_view
GROUP BY chain_id, cover_key;

CREATE OR REPLACE VIEW top_accounts_by_liquidity_view
AS
WITH pool_liquidity
AS
(
  SELECT
    account,
    COUNT(*) AS transactions,
    SUM(get_stablecoin_value(chain_id, liquidity_added)) AS added,
    0 AS removed
  FROM vault.pods_issued
  GROUP BY account
  
  UNION ALL
  
  SELECT
    account,
    COUNT(*) AS transactions,
    0 AS added,
    SUM(get_stablecoin_value(chain_id, liquidity_released)) AS removed
  FROM vault.pods_redeemed
  GROUP BY account
)
SELECT 
  account,
  SUM(transactions) AS transactions,
  SUM(COALESCE(added) - COALESCE(removed)) AS liquidity
FROM pool_liquidity
GROUP BY account
ORDER BY liquidity DESC
LIMIT 10;

CREATE OR REPLACE VIEW total_value_locked_view
AS
SELECT sum(total) as total
FROM stablecoin_transactions_view;

CREATE OR REPLACE VIEW total_liquidity_added_view
AS
SELECT * FROM stablecoin_transactions_view
WHERE description = 'Liquidity Added';

CREATE OR REPLACE VIEW total_liquidity_removed_view
AS
SELECT * FROM stablecoin_transactions_view
WHERE description = 'Liquidity Removed';

CREATE OR REPLACE VIEW total_value_locked_by_chain_view
AS
SELECT chain_id, sum(total) as total
FROM stablecoin_transactions_view
GROUP by chain_id;

CREATE OR REPLACE VIEW commitment_by_chain_view
AS
SELECT chain_id, SUM(get_stablecoin_value(chain_id, amount_to_cover)) AS commitment
FROM policy.cover_purchased
WHERE expires_on > EXTRACT(epoch FROM NOW() AT TIME ZONE 'UTC')
GROUP BY chain_id;


CREATE OR REPLACE VIEW fee_earned_by_chain_view
AS
SELECT
  chain_id,
  SUM(get_stablecoin_value(chain_id, fee)) AS total_fee
FROM policy.cover_purchased
GROUP BY chain_id;

CREATE OR REPLACE VIEW incident_stakes_by_camp_view
AS
SELECT incident_stakes_view.activity AS camp,
  incident_stakes_view.chain_id,
  incident_stakes_view.cover_key,
  incident_stakes_view.product_key,
  incident_stakes_view.incident_date,
  sum(get_npm_value(incident_stakes_view.stake::numeric)) AS camp_total
  FROM incident_stakes_view
GROUP BY
  incident_stakes_view.activity,
  incident_stakes_view.chain_id,
  incident_stakes_view.cover_key,
  incident_stakes_view.product_key,
  incident_stakes_view.incident_date;

CREATE OR REPLACE VIEW total_coverage_by_chain_view
AS
SELECT chain_id, SUM(get_stablecoin_value(chain_id, amount_to_cover)) AS total_coverage
FROM policy.cover_purchased
GROUP BY chain_id;

CREATE OR REPLACE VIEW total_platform_fee_earned_view
AS
SELECT
  chain_id,
  cover_key,
  SUM(get_stablecoin_value(chain_id, platform_fee)) AS total_platform_fee
FROM policy.cover_purchased
GROUP BY chain_id, cover_key;



CREATE OR REPLACE VIEW capacity_view
AS
WITH chains
AS
(
	SELECT DISTINCT core.transactions.chain_id
	FROM core.transactions
),
unfiltered
AS
(
  SELECT chain_id, cover_key, product_key
  FROM config_product_view
  WHERE config_product_view.chain_id IN
  (
    SELECT chain_id FROM chains
  )
  UNION ALL
  SELECT  chain_id, cover_key, string_to_bytes32('') FROM config_cover_view
  WHERE config_cover_view.chain_id IN
  (
    SELECT chain_id FROM chains
  )
),
products
AS
(
  SELECT DISTINCT chain_id, cover_key, product_key
  FROM unfiltered
  WHERE cover_key IS NOT NULL
)
SELECT
  chain_id,
  cover_key,
  bytes32_to_string(cover_key) AS cover,
  is_diversified(chain_id, cover_key) AS diversified,
  product_key,
  bytes32_to_string(product_key) AS product,
  get_cover_capacity_till(chain_id, cover_key, product_key, 'infinity') AS capacity
FROM products;

CREATE OR REPLACE VIEW capacity_by_chain_view
AS
SELECT chain_id, sum(capacity) AS total_capacity
FROM capacity_view
GROUP BY chain_id;

CREATE OR REPLACE VIEW total_fee_earned_view
AS
SELECT * FROM stablecoin_transactions_view
WHERE description = 'Fee Earned';

CREATE OR REPLACE VIEW product_commitment_view
AS
SELECT
  chain_id,
  cover_key,
  product_key,
  get_commitment(chain_id, cover_key, product_key) AS commitment
FROM policy.cover_purchased
GROUP BY chain_id, cover_key, product_key;


CREATE OR REPLACE VIEW top_accounts_by_protection_view
AS
SELECT
  on_behalf_of,
  COUNT(*) AS policies,
  SUM(get_stablecoin_value(chain_id, amount_to_cover)) AS protection
FROM policy.cover_purchased
WHERE expires_on > extract(epoch FROM NOW() AT TIME ZONE 'UTC')
GROUP BY on_behalf_of
ORDER BY protection DESC
LIMIT 10;

 
CREATE OR REPLACE VIEW nft_user_points_view
AS
WITH policy_purchasers
AS
(
  SELECT
    on_behalf_of                                                        AS account,
    SUM(get_stablecoin_value(chain_id, amount_to_cover))                AS policy
  FROM policy.cover_purchased
  GROUP BY on_behalf_of
),
liquidity_providers
AS
(
  SELECT
    account,
    SUM(get_stablecoin_value(chain_id, liquidity_added))                AS liquidity
  FROM vault.pods_issued
  GROUP BY account
),
points
AS
(
  SELECT
    COALESCE(policy_purchasers.account, liquidity_providers.account)    AS account,
    COALESCE(policy_purchasers.policy, 0)                               AS policy,
    COALESCE(liquidity_providers.liquidity, 0)                          AS liquidity
  FROM policy_purchasers
  FULL OUTER JOIN liquidity_providers
  ON policy_purchasers.account = liquidity_providers.account
),
summary
AS
(
  SELECT
    account,
    policy,
    liquidity,
    FLOOR(policy * 0.00625 + liquidity * 0.0375)                        AS points
  FROM points
)
SELECT 
  account,
  policy,
  liquidity,
  points,
  CASE
    WHEN points >= 50000 THEN 7
    WHEN points >= 25000 THEN 6
    WHEN points >= 10000 THEN 5
    WHEN points >= 7500 THEN 4
    WHEN points >= 5000 THEN 3
    WHEN points >= 1000 THEN 2
    WHEN points >= 100 THEN 1
    WHEN points < 100 THEN 0
  END                                                                   AS level
FROM summary
WHERE points >= 100
ORDER BY points DESC;



ROLLBACK TRANSACTION;