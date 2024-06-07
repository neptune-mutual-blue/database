CREATE OR REPLACE FUNCTION get_total_covered_till_date
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
  SELECT SUM(get_stablecoin_value(chain_id, amount_to_cover))
  INTO _result
  FROM policy.cover_purchased
  WHERE 1 = 1 
  AND (_chain_id IS NULL OR chain_id = _chain_id)
  AND (_cover_key IS NULL OR cover_key = _cover_key)
  AND to_timestamp(block_timestamp) <= _date;

  RETURN COALESCE(_result, 0);
END
$$
LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION get_total_covered_till_date
(
  _chain_id                                 uint256,
  _date                                     TIMESTAMP WITH TIME ZONE
)
RETURNS numeric
STABLE
AS
$$
BEGIN
  RETURN get_total_covered_till_date(_chain_id, NULL, _date);
END
$$
LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION get_total_covered_till_date
(
  _date                                     TIMESTAMP WITH TIME ZONE
)
RETURNS numeric
STABLE
AS
$$
BEGIN
  RETURN get_total_covered_till_date(NULL, NULL, _date);
END
$$
LANGUAGE plpgsql;

ALTER FUNCTION get_total_covered_till_date(TIMESTAMP WITH TIME ZONE) OWNER TO writeuser;
ALTER FUNCTION get_total_covered_till_date(uint256, TIMESTAMP WITH TIME ZONE) OWNER TO writeuser;
ALTER FUNCTION get_total_covered_till_date(uint256, bytes32, TIMESTAMP WITH TIME ZONE) OWNER TO writeuser;

-- SELECT * FROM get_total_covered_till_date('2021-01-01'::TIMESTAMP WITH TIME ZONE);
-- SELECT * FROM get_total_covered_till_date(1, '0x1234'::bytes32, '2021-01-01'::TIMESTAMP WITH TIME ZONE);
-- SELECT * FROM get_total_covered_till_date(1, '2021-01-01'::TIMESTAMP WITH TIME ZONE);
