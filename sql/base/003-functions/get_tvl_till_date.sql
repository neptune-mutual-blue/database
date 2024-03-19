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