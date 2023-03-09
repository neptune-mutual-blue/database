DROP FUNCTION IF EXISTS get_cover_capacity_till
(
  _chain_id                                           uint256,
  _cover_key                                          bytes32,
  _till                                               TIMESTAMP WITH TIME ZONE
) CASCADE;

DROP FUNCTION IF EXISTS get_cover_capacity_till
(
  _chain_id                                           uint256,
  _cover_key                                          bytes32,
  _product_key                                        bytes32,
  _till                                               TIMESTAMP WITH TIME ZONE
) CASCADE;

CREATE FUNCTION get_cover_capacity_till
(
  _chain_id                                           uint256,
  _cover_key                                          bytes32,
  _product_key                                        bytes32,
  _till                                               TIMESTAMP WITH TIME ZONE
)
RETURNS uint256
STABLE
AS
$$
  DECLARE _stablecoin_balance                         uint256;
  DECLARE _leverage                                   uint256;
  DECLARE _capital_efficiency                         numeric;
  DECLARE _average_capital_efficiency                 numeric;
  DECLARE _capacity                                   uint256;
  DECLARE _siblings                                   integer;
  DECLARE _multliplier                                integer = 10000;
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
    _capital_efficiency := _multliplier;
  END IF;


  IF(_product_key = string_to_bytes32('')) THEN
    _capacity := (_stablecoin_balance * _leverage * _average_capital_efficiency) / _multliplier;
    RETURN _capacity;
  END IF;
  
  _capacity := (_stablecoin_balance * _leverage * _capital_efficiency) / (_siblings * _multliplier);
  RETURN _capacity;
END
$$
LANGUAGE plpgsql;

--SELECT * FROM get_cover_capacity_till(43113, '0x62696e616e636500000000000000000000000000000000000000000000000000', 'infinity');
