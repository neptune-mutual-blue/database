DROP FUNCTION IF EXISTS get_commitment
(
  _chain_id                                   uint256,
  _cover_key                                  bytes32,
  _product_key                                bytes32
) CASCADE;

CREATE FUNCTION get_commitment
(
  _chain_id                                   uint256,
  _cover_key                                  bytes32,
  _product_key                                bytes32
)
RETURNS uint256
STABLE
AS
$$
  DECLARE _commmitment                        uint256;
  DECLARE _paid                               uint256;
  DECLARE _incident_date                      uint256;
  DECLARE _starts_from                        uint256 = EXTRACT(epoch FROM NOW() AT TIME ZONE 'UTC');
BEGIN
  _incident_date := get_active_incident_date(_chain_id, _cover_key, _product_key);
  
  IF(_incident_date > 0) THEN
    _starts_from := _incident_date;
  END IF;
  
  RAISE NOTICE '%', _INCIDENT_DATE;

  SELECT SUM(amount_to_cover) AS commitment
  INTO _commmitment
  FROM policy.cover_purchased  
  WHERE expires_on > _starts_from
  AND policy.cover_purchased.chain_id = _chain_id
  AND policy.cover_purchased.cover_key = _cover_key
  AND policy.cover_purchased.product_key = _product_key;

  SELECT SUM(cxtoken_to_stablecoin_units(_chain_id, cxtoken.claimed.amount))
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

  RETURN COALESCE(_commmitment, 0) - COALESCE(_paid, 0);
END
$$
LANGUAGE plpgsql;

--SELECT * FROM get_commitment(43113,'0x6465666900000000000000000000000000000000000000000000000000000000', '0x73757368692d7632000000000000000000000000000000000000000000000000');



