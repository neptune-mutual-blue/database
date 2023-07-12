DROP FUNCTION IF EXISTS get_min_first_reporting_stake(_chain_id uint256, _cover_key bytes32);

CREATE FUNCTION get_min_first_reporting_stake(_chain_id uint256, _cover_key bytes32)
RETURNS uint256
STABLE
AS
$$
  DECLARE _min_stake                            uint256;
BEGIN
  SELECT get_npm_value(consensus.first_reporting_stake_set.current)
  INTO _min_stake
  FROM consensus.first_reporting_stake_set
  WHERE consensus.first_reporting_stake_set.chain_id = _chain_id
  AND consensus.first_reporting_stake_set.cover_key = _cover_key
  ORDER BY consensus.first_reporting_stake_set.block_timestamp DESC
  LIMIT 1;

  IF(_min_stake IS NOT NULL) THEN
    RETURN _min_stake;
  END IF;

  SELECT get_npm_value(consensus.first_reporting_stake_set.current)
  INTO _min_stake
  FROM consensus.first_reporting_stake_set
  WHERE consensus.first_reporting_stake_set.chain_id = _chain_id
  AND consensus.first_reporting_stake_set.cover_key = string_to_bytes32('')
  ORDER BY consensus.first_reporting_stake_set.block_timestamp DESC
  LIMIT 1;

  IF(_min_stake IS NOT NULL) THEN
    RETURN _min_stake;
  END IF;

  SELECT get_npm_value(config_cover_view.minimum_first_reporting_stake)
  INTO _min_stake
  FROM config_cover_view
  WHERE config_cover_view.chain_id = _chain_id
  AND config_cover_view.cover_key = _cover_key;

  IF(_min_stake IS NOT NULL) THEN
    RETURN _min_stake;
  END IF;

  SELECT get_npm_value(protocol.initialized.first_reporting_stake)
  INTO _min_stake
  FROM protocol.initialized
  WHERE protocol.initialized.chain_id = _chain_id;
  
  RETURN COALESCE(_min_stake, 0);
END
$$
LANGUAGE plpgsql;


--SELECT get_min_first_reporting_stake(84531, '0x62696e616e636500000000000000000000000000000000000000000000000000');
