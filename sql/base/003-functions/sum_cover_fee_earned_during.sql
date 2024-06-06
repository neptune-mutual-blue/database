CREATE OR REPLACE FUNCTION sum_cover_fee_earned_during
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
  WHERE 1 = 1
  AND (_chain_id IS NULL OR policy.cover_purchased.chain_id = _chain_id)
  AND (_cover_key IS NULL OR policy.cover_purchased.cover_key = _cover_key)
  AND to_timestamp(policy.cover_purchased.block_timestamp)
  BETWEEN _start AND _end;

  RETURN COALESCE(_result, 0);
END
$$
LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION sum_cover_fee_earned_during
(
  _chain_id                                   uint256,
  _start                                      TIMESTAMP WITH TIME ZONE,
  _end                                        TIMESTAMP WITH TIME ZONE
)
RETURNS numeric
STABLE
AS
$$
BEGIN
  RETURN sum_cover_fee_earned_during(_chain_id, NULL, _start, _end);
END
$$
LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION sum_cover_fee_earned_during
(
  _start                                      TIMESTAMP WITH TIME ZONE,
  _end                                        TIMESTAMP WITH TIME ZONE
)
RETURNS numeric
STABLE
AS
$$
BEGIN
  RETURN sum_cover_fee_earned_during(NULL, NULL, _start, _end);
END
$$
LANGUAGE plpgsql;


ALTER FUNCTION sum_cover_fee_earned_during(TIMESTAMP WITH TIME ZONE, TIMESTAMP WITH TIME ZONE) OWNER TO writeuser;
ALTER FUNCTION sum_cover_fee_earned_during(uint256, TIMESTAMP WITH TIME ZONE, TIMESTAMP WITH TIME ZONE) OWNER TO writeuser;
ALTER FUNCTION sum_cover_fee_earned_during(uint256, bytes32, TIMESTAMP WITH TIME ZONE, TIMESTAMP WITH TIME ZONE) OWNER TO writeuser;
