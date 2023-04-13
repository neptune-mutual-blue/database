DROP FUNCTION IF EXISTS get_active_incident_date
(
  _chain_id                                   uint256,
  _cover_key                                  bytes32,
  _product_key                                bytes32
) CASCADE;

CREATE FUNCTION get_active_incident_date
(
  _chain_id                                   uint256,
  _cover_key                                  bytes32,
  _product_key                                bytes32
)
RETURNS uint256
STABLE
AS
$$
  DECLARE _incident_date                      uint256;
  DECLARE _finalized                          bool;
BEGIN
  IF(_product_key IS NULL) THEN
    _product_key := string_to_bytes32('');
  END IF;

  SELECT COALESCE(MAX(consensus.reported.incident_date), 0)
  INTO _incident_date
  FROM consensus.reported
  WHERE consensus.reported.chain_id = _chain_id
  AND consensus.reported.cover_key = _cover_key
  AND consensus.reported.product_key = _product_key;

  IF NOT EXISTS
  (
    SELECT * 
    FROM consensus.finalized
    WHERE consensus.finalized.chain_id = _chain_id
    AND consensus.finalized.cover_key = _cover_key
    AND consensus.finalized.product_key = _product_key
    AND consensus.finalized.incident_date = _incident_date
  ) THEN
    RETURN _incident_date;
  END IF;

  RETURN 0;
END
$$
LANGUAGE plpgsql;

--SELECT * FROM get_active_incident_date(84531, string_to_bytes32('coinbase'), string_to_bytes32(''));
--SELECT * FROM get_active_incident_date(84531, string_to_bytes32('defi'), string_to_bytes32('lido-v1'));

