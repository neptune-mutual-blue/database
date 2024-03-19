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
  DECLARE _added numeric;
  DECLARE _capitalized numeric;
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
  DECLARE _added numeric;
  DECLARE _capitalized numeric;
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

-- SELECT * FROM get_reassurance_till_date(NOW());

