CREATE OR REPLACE FUNCTION get_account_nft_info()
RETURNS TABLE
(
  account                                                   address,
  unlocked_level                                            numeric,
  minted_level                                              numeric,
  token_id                                                  uint256,
  nickname                                                  text,
  persona_info                                              jsonb
)
AS
$$
BEGIN
  DROP TABLE IF EXISTS _get_account_info_result;
  CREATE TEMPORARY TABLE _get_account_info_result
  (
    account                                                   address,
    unlocked_level                                            numeric,
    minted_level                                              numeric,
    token_id                                                  uint256,
    nickname                                                  text,
    persona_info                                              jsonb
  ) ON COMMIT DROP;

  INSERT INTO _get_account_info_result(account, unlocked_level)
  SELECT nft.merkle_root_update_details.account, MAX(level)
  FROM nft.merkle_root_update_details
  WHERE nft.merkle_root_update_details.active = true
  AND nft.merkle_root_update_details.family IS NOT NULL
  GROUP BY nft.merkle_root_update_details.account;
  
  UPDATE _get_account_info_result
  SET token_id = nft.soulbound_minted.token_id
  FROM nft.soulbound_minted
  WHERE _get_account_info_result.account = nft.soulbound_minted.account;
  
  UPDATE _get_account_info_result
  SET nickname = nfts.nickname
  FROM nfts
  WHERE _get_account_info_result.token_id = nfts.token_id;
  
  UPDATE _get_account_info_result
  SET minted_level =
  (
    SELECT MAX(level)
    FROM nft.minted_with_proof
    WHERE _get_account_info_result.account = nft.minted_with_proof.transaction_sender --@todo: change this to `account`
  );
  
  UPDATE _get_account_info_result
  SET persona_info =
  (
    SELECT jsonb_agg(jsonb_build_object('level', level, 'persona', persona))
    FROM nft.persona_set
    WHERE nft.persona_set.account = _get_account_info_result.account
  );

  RETURN QUERY
  SELECT * FROM _get_account_info_result;
END
$$
LANGUAGE plpgsql;
