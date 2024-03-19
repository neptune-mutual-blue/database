CREATE OR REPLACE FUNCTION get_reporter_commission(_chain_id uint256)
RETURNS numeric
STABLE
AS
$$
  DECLARE _commission                      numeric;
BEGIN
  SELECT consensus.reporter_commission_set.current
  INTO _commission
  FROM consensus.reporter_commission_set
  WHERE consensus.reporter_commission_set.chain_id = _chain_id
  ORDER BY consensus.reporter_commission_set.block_timestamp DESC
  LIMIT 1;

  IF(_commission IS NOT NULL) THEN
    RETURN _commission;
  END IF;
  
  SELECT protocol.initialized.governance_reporter_commission
  INTO _commission
  FROM protocol.initialized
  WHERE protocol.initialized.chain_id = _chain_id;
  
  RETURN COALESCE(_commission, 0);
END
$$
LANGUAGE plpgsql;

--SELECT get_reporter_commission(42161);

