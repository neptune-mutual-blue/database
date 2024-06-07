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
  WHERE 1 = 1
  AND (_chain_id IS NULL OR core.transactions.chain_id = _chain_id)
  AND (_cover_key IS NULL OR core.transactions.ck = _cover_key)
  AND core.transactions.event_name IN ('CoverPurchased', 'PodsIssued', 'PodsRedeemed', 'Claimed', 'PoolCapitalized')
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
  RETURN get_tvl_till_date(_chain_id, NULL, _date);
END
$$
LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION get_tvl_till_date
(
  _date                                     TIMESTAMP WITH TIME ZONE
)
RETURNS numeric
STABLE
AS
$$
  DECLARE _result numeric;
BEGIN
  RETURN get_tvl_till_date(NULL, NULL, _date);
END
$$
LANGUAGE plpgsql;

ALTER FUNCTION get_tvl_till_date( _date TIMESTAMP WITH TIME ZONE) OWNER TO writeuser;
ALTER FUNCTION get_tvl_till_date( _chain_id uint256, _date TIMESTAMP WITH TIME ZONE) OWNER TO writeuser;
ALTER FUNCTION get_tvl_till_date( _chain_id uint256, _cover_key bytes32, _date TIMESTAMP WITH TIME ZONE) OWNER TO writeuser;

-- SELECT * FROM get_tvl_till_date(NOW());
