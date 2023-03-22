DROP VIEW IF EXISTS most_viewed_nft_view;

CREATE VIEW most_viewed_nft_view
AS
SELECT
  level,
  role,
  name,
  description,
  views,
  start_index,
  CONCAT('https://nft.neptunemutual.net/images/', start_index + 1, '.png') AS image,
  siblings,
  rarity,
  stage
FROM characters
ORDER BY views DESC
LIMIT 4;
