DROP VIEW IF EXISTS trending_nft_view;

CREATE VIEW trending_nft_view
AS
SELECT
  level,
  role,
  name,
  description,
  want_to_mint,
  start_index,
  CONCAT('https://nft.neptunemutual.net/images/', start_index + 1, '.png') AS image,
  siblings,
  rarity,
  stage
FROM characters
ORDER BY want_to_mint DESC
LIMIT 4;
