CREATE OR REPLACE FUNCTION get_policy_floor
(
  _chain_id uint256,
  _cover_key bytes32
)
RETURNS numeric
STABLE
AS 
$$ 
  DECLARE _floor numeric;
BEGIN
  SELECT policy.cover_policy_rate_set.floor
  INTO _floor
  FROM
  policy.cover_policy_rate_set
  WHERE policy.cover_policy_rate_set.chain_id = _chain_id
  AND policy.cover_policy_rate_set.cover_key = _cover_key
  ORDER BY policy.cover_policy_rate_set.block_timestamp DESC
  LIMIT 1;

  IF(_floor IS NOT NULL) THEN
    RETURN _floor;
  END IF;

  SELECT config_cover_view.policy_floor
  INTO _floor
  FROM config_cover_view
  WHERE config_cover_view.chain_id = _chain_id
  AND config_cover_view.cover_key = _cover_key;

  IF(_floor IS NOT NULL) THEN
    RETURN _floor;
  END IF;

	SELECT
    protocol.initialized.policy_floor INTO _floor
	FROM protocol.initialized
	WHERE protocol.initialized.chain_id = _chain_id;

  RETURN COALESCE(_floor, 0);
END 
$$
LANGUAGE plpgsql;