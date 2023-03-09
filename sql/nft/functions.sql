DROP FUNCTION IF EXISTS add_nft(_metadata jsonb) CASCADE;

CREATE FUNCTION add_nft(_metadata jsonb)
RETURNS uuid
AS
$$
  DECLARE _id                         uuid;
BEGIN
  SELECT nfts.id INTO _id
  FROM nfts
  WHERE nfts.token_id = (_metadata->'edition')::uint256;
  
  IF(_id IS NOT NULL) THEN
    RETURN _id;
  END IF;
  
  INSERT INTO nfts
  (
    token_id,
    name,
    description,
    url,
    image,
    external_url,
    date_published,
    soulbound,
    attributes,
    properties
  )
  SELECT
    (_metadata->>'edition')::uint256,
    (_metadata->>'name')::text,
    (_metadata->>'description')::text,
    (_metadata->>'url')::text,
    (_metadata->>'image')::text,
    (_metadata->>'external_url')::text,
    (_metadata->>'date')::uint256,
    (_metadata->'properties'->'info'->>'soulbound')::boolean,
    _metadata->'attributes',
    _metadata->'properties'
  RETURNING id INTO _id;
    
  RETURN _id;
END
$$
LANGUAGE plpgsql;

SELECT add_nft('{
  "name": "Delphinus #100001",
  "description": "The stellar dolphin guardian empowered by the heavens",
  "image": "https://nft.neptunemutual.net/images/100001.png",
  "external_url": "https://neptunemutual.com/nft/100001/",
  "url": "https://nft.neptunemutual.net/metadata/100001.json",
  "edition": 100001,
  "date": 1677960792143,
  "attributes": [
    {
      "trait_type": "Background",
      "value": "The Atlantic Tides"
    },
    {
      "trait_type": "Guardian",
      "value": "Deep Purple Delphinus"
    },
    {
      "trait_type": "Tail",
      "value": "Tidal Wave Tail"
    },
    {
      "trait_type": "Flippers",
      "value": "Reef Guardian Flippers"
    },
    {
      "trait_type": "Armor",
      "value": "Medieval Armor"
    },
    {
      "trait_type": "Helm",
      "value": "Crystal Sunburst Helm"
    },
    {
      "trait_type": "Type",
      "value": "Selection"
    },
    {
      "trait_type": "Nickname",
      "value": "Sumptuous Radiation"
    },
    {
      "trait_type": "Family",
      "value": "Delphinus"
    },
    {
      "trait_type": "Siblings",
      "value": 1000
    },
    {
      "trait_type": "Rarity",
      "value": 5,
      "max_value": 10
    },
    {
      "trait_type": "Level",
      "value": 1,
      "max_value": 7
    }
  ],
  "properties": {
    "info": {
      "value": 100001,
      "class": "emphasis",
      "url": "https://neptunemutual.com/nft/100001/",
      "soulbound": false
    }
  },
  "uid": "delphinus-806"
}'::jsonb);
