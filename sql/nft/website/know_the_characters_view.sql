DROP VIEW IF EXISTS know_the_characters_view;

CREATE VIEW know_the_characters_view
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
FROM characters;
