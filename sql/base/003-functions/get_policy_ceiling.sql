DROP FUNCTION IF EXISTS get_policy_ceiling
(
  _chain_id uint256,
  _cover_key bytes32
) CASCADE;

CREATE FUNCTION get_policy_ceiling
(
  _chain_id uint256,
  _cover_key bytes32
)
RETURNS uint256
STABLE
AS 
$$ 
  DECLARE _ceiling uint256;
BEGIN
  SELECT policy.cover_policy_rate_set.ceiling
  INTO _ceiling
  FROM
  policy.cover_policy_rate_set
  WHERE policy.cover_policy_rate_set.chain_id = _chain_id
  AND policy.cover_policy_rate_set.cover_key = _cover_key
  ORDER BY policy.cover_policy_rate_set.block_timestamp DESC
  LIMIT 1;

  IF(_ceiling IS NOT NULL) THEN
    RETURN _ceiling;
  END IF;

  SELECT config_cover_view.policy_ceiling
  INTO _ceiling
  FROM config_cover_view
  WHERE config_cover_view.chain_id = _chain_id
  AND config_cover_view.cover_key = _cover_key;

  IF(_ceiling IS NOT NULL) THEN
    RETURN _ceiling;
  END IF;

	SELECT
    protocol.initialized.policy_ceiling INTO _ceiling
	FROM protocol.initialized
	WHERE protocol.initialized.chain_id = _chain_id;

  RETURN COALESCE(_ceiling, 0);
END 
$$
LANGUAGE plpgsql;

--SELECT get_policy_ceiling(42161, '0x62696e616e636500000000000000000000000000000000000000000000000000');

