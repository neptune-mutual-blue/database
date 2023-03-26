DROP VIEW IF EXISTS minting_level_view;

CREATE VIEW minting_level_view
AS
SELECT
  characters.name,
  characters.role,
  characters.description,
  characters.level,
  CONCAT('https://nft.neptunemutual.net/images/', start_index + 1, '.png') AS image,
  CONCAT('https://nft.neptunemutual.net/thumbnails/', start_index + 1, '.webp') AS thumbnail,
  CONCAT('https://nft.neptunemutual.net/covers/', start_index + 1, '.webp') AS cover,
  characters.stage,
  characters.siblings
FROM characters
WHERE level IS NOT NULL;

