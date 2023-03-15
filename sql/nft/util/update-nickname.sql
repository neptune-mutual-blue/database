WITH nft_attributes
AS
(
  SELECT id, jsonb_array_elements(attributes) AS values
  FROM nfts
),
nicknames
AS
(
  SELECT id, values->>'value' AS nickname
  FROM nft_attributes 
  WHERE values->>'trait_type' = 'Nickname'
)
UPDATE nfts
SET nickname = nicknames.nickname
FROM nicknames
WHERE nfts.id = nicknames.id;

