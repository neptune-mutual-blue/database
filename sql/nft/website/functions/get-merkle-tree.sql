DROP FUNCTION IF EXISTS get_nft_merkle_tree(_live boolean);

CREATE FUNCTION get_nft_merkle_tree(_live boolean)
RETURNS TABLE
(
  id                                                                  uuid,
  account                                                             address,
  policy                                                              uint256,
  liquidity                                                           uint256,
  points                                                              uint256,
  eligible_level                                                      uint8,
  level                                                               uint8,
  family                                                              text,
  persona                                                             uint8
)
AS
$$
  DECLARE _r                                                          RECORD;
BEGIN
  DROP TABLE IF EXISTS _get_nft_merkle_tree_result;
  CREATE TEMPORARY TABLE _get_nft_merkle_tree_result
  (
    id                                                                uuid,
    account                                                           address,
    policy                                                            uint256,
    liquidity                                                         uint256,
    points                                                            uint256,
    eligible_level                                                    uint8,
    level                                                             uint8,    
    family                                                            text,
    persona                                                           uint8
  ) ON COMMIT DROP;
  
  IF(_live = false) THEN
    RETURN QUERY
    SELECT
      nft.merkle_root_update_details.id,
      nft.merkle_root_update_details.account,
      nft.merkle_root_update_details.policy,
      nft.merkle_root_update_details.liquidity,
      nft.merkle_root_update_details.points,
      nft.merkle_root_update_details.eligible_level,
      nft.merkle_root_update_details.level,
      nft.merkle_root_update_details.family,
      nft.merkle_root_update_details.persona
    FROM nft.merkle_root_update_details
    WHERE active = true;
    
    RETURN;
  END IF;
  
  FOR _r IN
  (
    SELECT * FROM nft_user_points_view
  ) LOOP
    FOR i IN 1.._r.level
    LOOP
      INSERT INTO _get_nft_merkle_tree_result(account, policy, liquidity, points, eligible_level, level)
      SELECT _r.account, _r.policy, _r.liquidity, _r.points, _r.level, i;    
    END LOOP;
  END LOOP;
  
  UPDATE _get_nft_merkle_tree_result
  SET persona = nft.persona_set.persona
  FROM nft.persona_set
  WHERE nft.persona_set.account = _get_nft_merkle_tree_result.account
  AND nft.persona_set.level = _get_nft_merkle_tree_result.level;
  
  UPDATE _get_nft_merkle_tree_result
  SET family = characters.name
  FROM characters
  WHERE _get_nft_merkle_tree_result.level = characters.level
  AND characters.role =
  CASE _get_nft_merkle_tree_result.persona 
    WHEN 1 THEN 'Guardian' 
    WHEN 2 THEN 'Beast' 
    ELSE NULL
  END;
  

  RETURN QUERY
  SELECT * FROM _get_nft_merkle_tree_result
  ORDER BY account, level;
END
$$
LANGUAGE plpgsql;


SELECT * FROM get_nft_merkle_tree(true);

