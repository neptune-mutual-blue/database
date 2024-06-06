CREATE OR REPLACE FUNCTION count_cover_purchase_during
(
  _chain_id                                   uint256,
  _cover_key                                  bytes32,
  _product_key                                bytes32,
  _start                                      TIMESTAMP WITH TIME ZONE,
  _end                                        TIMESTAMP WITH TIME ZONE
)
RETURNS numeric
STABLE
AS
$$
  DECLARE _result numeric;
BEGIN
  SELECT COUNT(*)
  INTO _result
  FROM policy.cover_purchased
  WHERE 1 = 1
  AND (_chain_id IS NULL OR policy.cover_purchased.chain_id = _chain_id)
  AND (_cover_key IS NULL OR policy.cover_purchased.cover_key = _cover_key)
  AND (_product_key IS NULL OR policy.cover_purchased.product_key = _product_key)
  AND to_timestamp(policy.cover_purchased.block_timestamp) BETWEEN _start AND _end;

  RETURN COALESCE(_result, 0);
END
$$
LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION count_cover_purchase_during
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
BEGIN
  RETURN count_cover_purchase_during(_chain_id, _cover_key, NULL, _start, _end);
END
$$
LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION count_cover_purchase_during
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
  RETURN count_cover_purchase_during(_chain_id, NULL, NULL, _start, _end);
END
$$
LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION count_cover_purchase_during
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
  RETURN count_cover_purchase_during(NULL, NULL, NULL, _start, _end);
END
$$
LANGUAGE plpgsql;


ALTER FUNCTION count_cover_purchase_during(TIMESTAMP WITH TIME ZONE, TIMESTAMP WITH TIME ZONE) OWNER TO writeuser;
ALTER FUNCTION count_cover_purchase_during(uint256, TIMESTAMP WITH TIME ZONE, TIMESTAMP WITH TIME ZONE) OWNER TO writeuser;
ALTER FUNCTION count_cover_purchase_during(uint256, bytes32, TIMESTAMP WITH TIME ZONE, TIMESTAMP WITH TIME ZONE) OWNER TO writeuser;
ALTER FUNCTION count_cover_purchase_during(uint256, bytes32, bytes32, TIMESTAMP WITH TIME ZONE, TIMESTAMP WITH TIME ZONE) OWNER TO writeuser;
