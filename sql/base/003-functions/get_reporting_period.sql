DROP FUNCTION IF EXISTS get_reporting_period(_chain_id uint256, _cover_key bytes32);

CREATE FUNCTION get_reporting_period(_chain_id uint256, _cover_key bytes32)
RETURNS uint256
STABLE
AS
$$
BEGIN
  RETURN reporting_period
  FROM config_cover_view
  WHERE config_cover_view.chain_id = _chain_id
  AND config_cover_view.cover_key = _cover_key;
END
$$
LANGUAGE plpgsql;

--SELECT * FROM get_reporting_period(1, string_to_bytes32('popular-defi-apps'));
