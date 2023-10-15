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

CREATE OR REPLACE FUNCTION get_nft_name_info(_token_ids uint256[])
RETURNS jsonb
AS
$$
BEGIN
  RETURN
  (
    WITH intermediate
    AS
    (
      SELECT nfts.name, nfts.token_id
      FROM nfts
      WHERE token_id = ANY(_token_ids)
    )
    SELECT jsonb_agg(intermediate) FROM intermediate
  );
END
$$
LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION get_owner(_token_id uint256)
RETURNS jsonb
AS
$$
BEGIN
  RETURN
  (
    WITH intermediate
    AS
    (
      SELECT
        receiver AS owner,
        chain_id AS chain_id
      FROM      nft.neptune_legends_transfer
      WHERE     token_id = _token_id
      ORDER BY  block_timestamp DESC
      LIMIT 1
    )
    SELECT jsonb_agg(intermediate) FROM intermediate
  );
END
$$
LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION get_nft_role(_token_id uint256)
RETURNS text
STABLE
AS
$$
BEGIN
  RETURN
    CASE
      WHEN nfts.family IN('Aquavallo', 'Delphinus', 'Salacia') THEN 'Guardian'
      WHEN nfts.family IN('Merman Serpent', 'Gargantuworm', 'Grim Wyvern', 'Sabersquatch') THEN 'Beast'
      WHEN nfts.family = 'Neptune' THEN 'Neptune'
    END
  FROM nfts
  WHERE nfts.token_id = _token_id;
END
$$
LANGUAGE plpgsql;
