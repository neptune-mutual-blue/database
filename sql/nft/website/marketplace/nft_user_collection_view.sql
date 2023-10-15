CREATE OR REPLACE VIEW nft_user_collection_view
AS
SELECT
  token_id,
  name,
  nickname,
  family,
  soulbound,
  attributes,
  get_owner(token_id) AS token_owner
FROM nfts
WHERE get_owner(token_id) IS NOT NULL;
