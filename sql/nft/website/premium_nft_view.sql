DROP VIEW IF EXISTS premium_nft_view;

CREATE VIEW premium_nft_view
AS
SELECT
  level,
  role,
  name,
  description,
  start_index,
  CONCAT('https://nft.neptunemutual.net/images/', start_index + 1, '.png') AS image,
  CONCAT('https://nft.neptunemutual.net/thumbnails/', start_index + 1, '.webp') AS thumbnail,
  CONCAT('https://nft.neptunemutual.net/covers/', start_index + 1, '.webp') AS cover,
  siblings,
  rarity,
  stage
FROM characters
WHERE siblings <= 100
AND siblings > 0;

