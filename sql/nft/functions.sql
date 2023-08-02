CREATE OR REPLACE FUNCTION add_nft(_metadata jsonb)
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

  WITH nft_attributes
  AS
  (
    SELECT id, jsonb_array_elements(attributes) AS values
    FROM nfts
    WHERE nfts.id = _id
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

  WITH nft_attributes
  AS
  (
    SELECT id, jsonb_array_elements(attributes) AS values
    FROM nfts
    WHERE nfts.id = _id
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
    
  RETURN _id;
END
$$
LANGUAGE plpgsql;



CREATE OR REPLACE FUNCTION get_owner(_token_id uint256)
RETURNS address
STABLE
AS
$$
  DECLARE _owner                         address;
BEGIN
  SELECT "to" INTO _owner
  FROM      transfer_single
  WHERE     transfer_single.id = _token_id
  ORDER BY  transfer_single.block_timestamp DESC
  LIMIT 1;

  IF(_owner IS NOT NULL) THEN
    RETURN _owner;
  END IF;
  
  SELECT "account" INTO _owner
  FROM      nft.soulbound_minted
  WHERE     nft.soulbound_minted.token_id = _token_id
  ORDER BY  nft.soulbound_minted.block_timestamp DESC
  LIMIT 1;

  RETURN _owner;
END
$$
LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION get_nft_role(_token_id uint256)
RETURNS address
STABLE
AS
$$
  DECLARE _nft_role                                           text;
BEGIN
  SELECT
    CASE
      WHEN nfts.family = 'Aquavallo'      THEN 'Guardian'
      WHEN nfts.family = 'Merman Serpent' THEN 'Beast'
      WHEN nfts.family = 'Gargantuworm'   THEN 'Beast'
      WHEN nfts.family = 'Delphinus'      THEN 'Guardian'
      WHEN nfts.family = 'Salacia'        THEN 'Guardian'
      WHEN nfts.family = 'Grim Wyvern'    THEN 'Beast'
      WHEN nfts.family = 'Neptune'        THEN 'Neptune'
      WHEN nfts.family = 'Sabersquatch'   THEN 'Beast'
    END                                                       INTO _nft_role
  FROM nfts
  WHERE nft.token_id = _token_id
  LIMIT 1;

  RETURN _nft_role;
END
$$
LANGUAGE plpgsql;
