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
    
  RETURN _id;
END
$$
LANGUAGE plpgsql;



CREATE OR REPLACE FUNCTION get_owner(_token_id uint256)
RETURNS address
STABLE
AS
$$
BEGIN
  RETURN "to"
  FROM transfer_single
  WHERE transfer_single.id = _token_id
  ORDER BY transfer_single.block_timestamp DESC
  LIMIT 1;
END
$$
LANGUAGE plpgsql;

