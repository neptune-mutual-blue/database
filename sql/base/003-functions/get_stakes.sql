DROP FUNCTION IF EXISTS get_stakes
(
  _chain_id                                               uint256,
  _cover_key                                              bytes32,
  _product_key                                            bytes32,
  _incident_date                                          uint256
) CASCADE;

CREATE FUNCTION get_stakes
(
  _chain_id                                               uint256,
  _cover_key                                              bytes32,
  _product_key                                            bytes32,
  _incident_date                                          uint256
)
RETURNS TABLE
(
  yes                                                     uint256,
  no                                                      uint256
)
STABLE
AS
$$
  DECLARE _yes                                            uint256;
  DECLARE _no                                             uint256;
BEGIN
  IF(_product_key IS NULL) THEN
    _product_key = string_to_bytes32('');
  END IF;

  SELECT camp_total INTO _yes
  FROM incident_stakes_by_camp_view
  WHERE incident_stakes_by_camp_view.camp = 'Attestation'
  AND incident_stakes_by_camp_view.chain_id = _chain_id
  AND incident_stakes_by_camp_view.cover_key = _cover_key
  AND incident_stakes_by_camp_view.product_key = _product_key
  AND incident_stakes_by_camp_view.incident_date = _incident_date;

  SELECT camp_total INTO _no
  FROM incident_stakes_by_camp_view
  WHERE incident_stakes_by_camp_view.camp != 'Attestation'
  AND incident_stakes_by_camp_view.chain_id = _chain_id
  AND incident_stakes_by_camp_view.cover_key = _cover_key
  AND incident_stakes_by_camp_view.product_key = _product_key
  AND incident_stakes_by_camp_view.incident_date = _incident_date;

  RETURN QUERY
  SELECT COALESCE(_yes, 0::uint256), COALESCE(_no, 0::uint256);
END
$$
LANGUAGE plpgsql;


--SELECT * FROM get_stakes(43113, string_to_bytes32('huobi'), NULL, 1676619751);


