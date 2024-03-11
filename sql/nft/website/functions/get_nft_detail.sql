CREATE OR REPLACE FUNCTION get_nft_detail(_token_id uint256)
RETURNS TABLE
(
  token_id                                  uint256,
  token_role                                text,
  level                                     integer,
  siblings                                  integer,
  stage                                     text,
  token_owner                               text,
  name                                      text,
  nickname                                  text,
  family                                    text,
  views                                     uint256,
  want_to_mint                              uint256,
  description                               text,
  url                                       text,
  image                                     text,
  external_url                              text,
  date_published                            TIMESTAMP WITH TIME ZONE,
  soulbound                                 boolean,
  attributes                                jsonb,
  activities                                jsonb
)
AS
$$
BEGIN
  DROP TABLE IF EXISTS _get_nft_detail_details;
  
  CREATE TEMPORARY TABLE _get_nft_detail_details
  (
    token_id                                  uint256,
    token_role                                text,
    level                                     integer,
    siblings                                  integer,
    stage                                     text,
    token_owner                               text,
    name                                      text,
    nickname                                  text,
    family                                    text,
    views                                     uint256,
    want_to_mint                              uint256,
    description                               text,
    url                                       text,
    image                                     text,
    external_url                              text,
    date_published                            TIMESTAMP WITH TIME ZONE,
    soulbound                                 boolean,
    attributes                                jsonb,
    activities                                jsonb
  ) ON COMMIT DROP;
  
END
$$
LANGUAGE plpgsql;

-- SELECT * FROM get_nft_detail(121411);

-- select * from nfts limit 1
-- SELECT * FROM CHARACTERS

