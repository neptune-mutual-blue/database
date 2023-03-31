DROP FUNCTION IF EXISTS get_product_status
(
  _chain_id                                         uint256,
  _cover_key                                        bytes32,
  _product_key                                      bytes32,
  _incident_date                                    uint256
);


CREATE FUNCTION get_product_status
(
  _chain_id                                         uint256,
  _cover_key                                        bytes32,
  _product_key                                      bytes32,
  _incident_date                                    uint256
)
RETURNS product_status_type
STABLE
AS
$$
  DECLARE _resolution_decision                      boolean;
  DECLARE _status                                   product_status_type = 'Normal'; 
BEGIN
  IF(_product_key IS NULL) THEN
    _product_key := string_to_bytes32('');  
  END IF;

  IF(_incident_date = 0) THEN
    RETURN _status;
  END IF;

  _status := 'IncidentHappened';

  IF EXISTS
  (
    SELECT *
    FROM get_stakes(_chain_id, _cover_key, _product_key, _incident_date)
    WHERE no > yes
  ) THEN
    _status := 'FalseReporting';  
  END IF;
  
  SELECT
    consensus.resolved.decision
  INTO
    _resolution_decision
  FROM consensus.resolved
  WHERE consensus.resolved.chain_id = _chain_id
  AND consensus.resolved.cover_key = _cover_key
  AND consensus.resolved.product_key = _product_key
  AND consensus.resolved.incident_date = _incident_date
  ORDER BY consensus.resolved.emergency DESC, consensus.resolved.block_timestamp DESC
  LIMIT 1;
  
  IF(_resolution_decision = true) THEN
    _status := 'Claimable';
  ELSIF(_resolution_decision = false) THEN
    _status := 'FalseReporting';
  END IF;
  
  RETURN _status;
END
$$
LANGUAGE plpgsql;


DROP FUNCTION IF EXISTS get_active_product_status
(
  _chain_id                                         uint256,
  _cover_key                                        bytes32,
  _product_key                                      bytes32
);

CREATE FUNCTION get_active_product_status
(
  _chain_id                                         uint256,
  _cover_key                                        bytes32,
  _product_key                                      bytes32
)
RETURNS product_status_type
STABLE
AS
$$
  DECLARE _incident_date                            uint256;
BEGIN
  _incident_date := COALESCE(get_active_incident_date(_chain_id, _cover_key, _product_key), 0);
  RETURN get_product_status(_chain_id, _cover_key, _product_key, _incident_date);
END
$$
LANGUAGE plpgsql;

--SELECT * FROM get_active_product_status(43113, string_to_bytes32('huobi'), NULL);
