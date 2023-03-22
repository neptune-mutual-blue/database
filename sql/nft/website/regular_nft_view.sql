DROP VIEW IF EXISTS regular_nft_view;

CREATE VIEW regular_nft_view
AS
SELECT
  level,
  role,
  name,
  description,
  start_index,
  CONCAT('https://nft.neptunemutual.net/images/', start_index + 1, '.png') AS image,
  siblings,
  rarity,
  stage
FROM characters
WHERE COALESCE(level, 99) <= 4;
