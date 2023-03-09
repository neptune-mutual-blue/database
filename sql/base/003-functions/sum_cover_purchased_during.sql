CREATE OR REPLACE FUNCTION sum_cover_purchased_during
(
  _start                                      TIMESTAMP WITH TIME ZONE,
  _end                                        TIMESTAMP WITH TIME ZONE
)
RETURNS uint256
STABLE
AS
$$
  DECLARE _result numeric;
BEGIN
  SELECT
    SUM(policy.cover_purchased.fee)
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
RETURNS uint256
STABLE
AS
$$
  DECLARE _result numeric;
BEGIN
  SELECT
    SUM(policy.cover_purchased.fee)
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
