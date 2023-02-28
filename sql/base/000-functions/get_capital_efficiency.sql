DROP FUNCTION IF EXISTS get_capital_efficiency
(
  _chain_id                               numeric,
  _cover_key                              text
) CASCADE;

CREATE FUNCTION get_capital_efficiency
(
  _chain_id                               numeric,
  _cover_key                              text
)
RETURNS TABLE
(
  leverage_factor                         numeric,
  average_capital_efficiency              numeric
)
STABLE AS
$$
  DECLARE _leverage_factor                numeric;
  DECLARE _average_capital_efficiency     numeric;
BEGIN
  SELECT leverage INTO _leverage_factor
  FROM config_cover_view
  WHERE chain_id = _chain_id
  AND cover_key = _cover_key;
  
  SELECT AVG(capital_efficiency) INTO _average_capital_efficiency
  FROM config_product_view
  WHERE chain_id = _chain_id
  AND cover_key = _cover_key;

  RETURN QUERY
  SELECT _leverage_factor, _average_capital_efficiency;
END
$$
LANGUAGE plpgsql;


DROP FUNCTION IF EXISTS get_capital_efficiency
(
  _chain_id                               numeric,
  _cover_key                              text,
  _product_key                            text
);

CREATE FUNCTION get_capital_efficiency
(
  _chain_id                               numeric,
  _cover_key                              text,
  _product_key                            text
)
RETURNS TABLE
(
  leverage_factor                         numeric,
  capital_efficiency                      numeric
)
STABLE AS
$$
  DECLARE _leverage_factor                numeric;
  DECLARE _capital_efficiency             numeric;
BEGIN
  SELECT config_cover_view.leverage INTO _leverage_factor
  FROM config_cover_view
  WHERE chain_id = _chain_id
  AND cover_key = _cover_key;
  
  SELECT config_product_view.capital_efficiency INTO _capital_efficiency
  FROM config_product_view
  WHERE chain_id = _chain_id
  AND cover_key = _cover_key
  AND product_key = _product_key;

  RETURN QUERY
  SELECT COALESCE(_leverage_factor, 0), COALESCE(_capital_efficiency, 0);
END
$$
LANGUAGE plpgsql;
