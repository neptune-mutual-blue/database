CREATE OR REPLACE FUNCTION get_incident_date_by_expiry_date
(
  _chain_id                 uint256,
  _cover_key                bytes32,
  _product_key              bytes32,
  _block_timestamp          uint256,
  _expires_on               uint256
)
RETURNS uint256 
STABLE
AS
$$ 
BEGIN
  RETURN incident_date
  FROM consensus.reported
  WHERE chain_id            = _chain_id
  AND cover_key             = _cover_key
  AND product_key           = _product_key
  AND incident_date
  BETWEEN _block_timestamp AND _expires_on
  ORDER BY incident_date DESC
  LIMIT 1;
END
$$
LANGUAGE plpgsql;