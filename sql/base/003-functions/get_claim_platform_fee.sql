CREATE OR REPLACE FUNCTION get_claim_platform_fee(_chain_id uint256)
RETURNS numeric
STABLE
AS
$$
  DECLARE _fee                        uint256;
BEGIN
  SELECT protocol.initialized.claim_platform_fee
  INTO _fee
  FROM protocol.initialized
  WHERE protocol.initialized.chain_id = _chain_id;
  
  RETURN COALESCE(_fee, 0);
END
$$
LANGUAGE plpgsql;

--SELECT get_claim_platform_fee(42161);

