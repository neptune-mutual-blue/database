DROP VIEW IF EXISTS nft_detail_view;

CREATE VIEW nft_detail_view
AS
SELECT
  nfts.token_id,
  characters.role,
  characters.level,
  characters.siblings,
  characters.stage,
  get_owner(nfts.token_id) AS token_owner,
  nfts.name,
  nfts.category,
  nfts.nickname,
  nfts.family,
  nfts.views,
  nfts.want_to_mint,
  nfts.description,
  nfts.url,
  CONCAT('https://nft.neptunemutual.net/images/', nfts.token_id + 1, '.png') AS image,
  CONCAT('https://nft.neptunemutual.net/thumbnails/', nfts.token_id + 1, '.webp') AS thumbnail,
  CONCAT('https://nft.neptunemutual.net/covers/', nfts.token_id + 1, '.webp') AS cover,
  nfts.external_url,
  nfts.date_published,
  nfts.soulbound,
  nfts.attributes,
  jsonb_agg(nft_activity_view) as activities
FROM nfts
INNER JOIN characters
ON characters.name = nfts.family
LEFT OUTER JOIN nft_activity_view
ON nft_activity_view.token_id = nfts.token_id
GROUP BY
  nfts.token_id, 
  characters.role,
  characters.level,
  characters.siblings,
  characters.stage,
  token_owner,
  nfts.name,
  nfts.category,
  nfts.nickname,
  nfts.family,
  nfts.views,
  nfts.want_to_mint,
  nfts.description,
  nfts.url,
  nfts.image,
  nfts.external_url,
  nfts.date_published,
  nfts.soulbound,
  nfts.attributes;
