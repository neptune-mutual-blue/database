CREATE OR REPLACE FUNCTION get_magic_square_campaign_2_result
(
  _account                                          address
)
RETURNS TABLE
(
  result                                            boolean,
  covered_amount                                    uint256,
  nft_id                                            uint256
)
AS
$$
  /*
  Requirement:
  ------------------------------------------------------------
  policy
    - should be purchased after 12 jan 2024
    - for 3 months
    - covered amount is greater than 50 USDC

  nft
    - soulbound token should be purchased after 12 jan 2024

  (
    for both cases
    chain
      - should be 56
  )
  */
  DECLARE _CHAIN_ID CONSTANT                        uint256 = 56;
  DECLARE _MIN_COVER_AMOUNT_REQUIRED CONSTANT       uint256 = get_stablecoin_value(_chain_id, 50);
  DECLARE _PURCHASE_AFTER CONSTANT                  TIMESTAMP WITH TIME ZONE = '12 Jan, 2024' AT TIME ZONE 'UTC';
  DECLARE _MIN_POLICY_PURCHASE_DURATION CONSTANT    uint256 = 3;
  DECLARE _result                                   boolean = true;
  DECLARE _covered_amount                           uint256;
  DECLARE _nft_id                                   uint256;
BEGIN
  SELECT SUM(amount_to_cover) INTO _covered_amount
  FROM policy.cover_purchased
  WHERE policy.cover_purchased.on_behalf_of ILIKE _account
  AND policy.cover_purchased.chain_id = _CHAIN_ID
  AND policy.cover_purchased.block_timestamp >= EXTRACT(EPOCH FROM _PURCHASE_AFTER)
  AND policy.cover_purchased.cover_duration = _MIN_POLICY_PURCHASE_DURATION;

  SELECT token_id INTO _nft_id
  FROM nft.soulbound_minted
  WHERE nft.soulbound_minted.account ILIKE _account
  AND nft.soulbound_minted.block_timestamp >= EXTRACT(EPOCH FROM _PURCHASE_AFTER)
  LIMIT 1;
  
  IF(COALESCE(_covered_amount, 0) < _MIN_COVER_AMOUNT_REQUIRED) THEN
    _result := false;
  END IF;

  IF(COALESCE(_nft_id, 0) = 0) THEN
    _result := false;
  END IF;

  RETURN QUERY
  SELECT _result, _covered_amount, _nft_id;
END
$$
LANGUAGE plpgsql;