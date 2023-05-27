DROP FUNCTION IF EXISTS nft.update_merkle_root_details
(
  _id                                                       uuid,
  _transaction_hash                                         text,
  _info                                                     text,
  _leaves                                                   jsonb
);

CREATE FUNCTION nft.update_merkle_root_details
(
  _id                                                       uuid,
  _transaction_hash                                         text,
  _info                                                     text,
  _leaves                                                   jsonb
)
RETURNS void
AS
$$
BEGIN  
  UPDATE nft.merkle_root_update_details
  SET active = false;

  INSERT INTO nft.merkle_root_updates(id, updated_on, info, transaction_hash)
  SELECT _id, extract(epoch FROM NOW() AT TIME ZONE 'UTC'), _info, _transaction_hash;
  
  INSERT INTO nft.merkle_root_update_details(id, account, policy, liquidity, points, eligible_level, level, family, persona)
  SELECT _id, * FROM jsonb_to_recordset((SELECT jsonb_agg(t) AS leaves FROM get_nft_merkle_tree(true) AS t))
  AS (account address, policy uint256, liquidity uint256, points uint256, eligible_level uint8, level uint8, family text, persona uint8);
END
$$
LANGUAGE plpgsql;


--SELECT * FROM nft.update_merkle_root_details('2588fd26-7017-4fb9-b2b1-1b37a03e3603', 'test', (SELECT jsonb_agg(t) AS leaves FROM get_nft_merkle_tree(true) AS t))


