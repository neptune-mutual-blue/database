DROP FUNCTION IF EXISTS get_coverage_lag(_chain_id uint256, _cover_key bytes32) CASCADE;

CREATE FUNCTION get_coverage_lag(_chain_id uint256, _cover_key bytes32)
RETURNS uint256
STABLE
AS
$$
  DECLARE _lag                      uint256;
BEGIN
  SELECT policy.coverage_lag_set."window"
  INTO _lag
  FROM policy.coverage_lag_set
  WHERE policy.coverage_lag_set.chain_id = _chain_id
  AND policy.coverage_lag_set.cover_key = _cover_key
  ORDER BY policy.coverage_lag_set.block_timestamp DESC
  LIMIT 1;

  IF(_lag IS NOT NULL) THEN
    RETURN _lag;
  END IF;
  
  SELECT config_cover_view.coverage_lag
  INTO _lag
  FROM config_cover_view
  WHERE config_cover_view.chain_id = _chain_id
  AND config_cover_view.cover_key = _cover_key;
  
  IF(_lag IS NOT NULL) THEN
    RETURN _lag;
  END IF;
    
  RETURN EXTRACT(epoch FROM INTERVAL '1 days');
END
$$
LANGUAGE plpgsql;

-- SELECT get_coverage_lag(42161, '0x62696e616e636500000000000000000000000000000000000000000000000000');

