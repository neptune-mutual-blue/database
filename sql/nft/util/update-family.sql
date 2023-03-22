WITH nft_attributes
AS
(
  SELECT id, jsonb_array_elements(attributes) AS values
  FROM nfts
),
families
AS
(
  SELECT id, values->>'value' AS family
  FROM nft_attributes 
  WHERE values->>'trait_type' = 'Family'
)
UPDATE nfts
SET family = families.family
FROM families
WHERE nfts.id = families.id;

