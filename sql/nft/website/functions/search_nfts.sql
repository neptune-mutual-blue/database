CREATE OR REPLACE FUNCTION search_nfts
(
  _search                                         national character varying(128),
  _minted                                         boolean,
  _soulbound                                      boolean,
  _roles                                          text[],
  _props                                          jsonb,
  _page_number                                    integer,
  _page_size                                      integer
)
RETURNS TABLE
(
  nickname                                        text,
  family                                          text,
  category                                        text,
  token_id                                        uint256,
  views                                           uint256,
  want_to_mint                                    uint256,
  siblings                                        integer,
  page_size                                       integer,
  page_number                                     integer,
  total_records                                   integer,
  total_pages                                     integer  
)
AS
$$
  DECLARE _total_records                          integer;
  DECLARE _total_pages                            integer;
  DECLARE _query                                  text;
BEGIN
  IF(_page_number < 1) THEN
    RAISE EXCEPTION 'Invalid page_number value %', _page_number;  
  END IF;
  
  IF(_page_size NOT IN (10, 25, 50)) THEN
    RAISE EXCEPTION 'Invalid _page_size value %', _page_size;  
  END IF;

  DROP TABLE IF EXISTS _search_nfts_result;

  CREATE TEMPORARY TABLE _search_nfts_result
  (
    nickname                                        text,
    family                                          text,
    category                                        text,
    token_id                                        uint256,
    views                                           uint256,
    want_to_mint                                    uint256,
    siblings                                        integer,
    page_size                                       integer,
    page_number                                     integer,
    total_records                                   integer,
    total_pages                                     integer  
  ) ON COMMIT DROP;
  
   _query := format('
  WITH result
  AS
  (
    SELECT nfts.nickname, nfts.family, nfts.category, nfts.token_id, nfts.views, nfts.want_to_mint, get_sibling_count(nfts.category)
    FROM nfts
    WHERE 1 = 1
    AND (%1$L IS NULL OR attributes @> %1$L)
    AND CONCAT(nfts.family, nfts.description, nfts.token_id, nfts.attributes::text) ILIKE %s
  )
  SELECT COUNT(*) FROM result;', _props, quote_literal_ilike(_search));

  EXECUTE _query
  INTO _total_records;

  INSERT INTO _search_nfts_result(
    nickname,
    family,
    category,
    token_id,
    views,
    want_to_mint,
    siblings
  )
  SELECT
    nfts.nickname,
    nfts.family,
    nfts.category,
    nfts.token_id,
    nfts.views,
    nfts.want_to_mint,
    get_sibling_count(nfts.category)
  FROM nfts
  WHERE 1 = 1
  AND (_props     IS NULL OR attributes @> _props)
  AND CONCAT(nfts.family, nfts.description, nfts.token_id, nfts.attributes::text) ILIKE CONCAT('%', TRIM(_search), '%')
  AND (_soulbound IS NULL OR nfts.soulbound = _soulbound)
  AND (_minted    IS NULL OR _minted = (get_owner(nfts.token_id) IS NOT NULL))
  AND (array_length(_roles,1) IS NULL OR get_nft_role(nfts.token_id) = ANY(_roles))
  ORDER BY nfts.views DESC, nfts.nickname
  LIMIT _page_size
  OFFSET _page_size * (_page_number -1);

  UPDATE _search_nfts_result
  SET
    page_number   = _page_number,
    page_size     = _page_size,
    total_records = _total_records,
    total_pages   = COALESCE(CEILING(_total_records::numeric / _page_size), 0);

  RETURN QUERY
  SELECT * FROM _search_nfts_result;
END
$$
LANGUAGE plpgsql;

-- SELECT * FROM search_nfts
-- (
--   '',
--   NULL,
--   NULL,
--   array[]::text[],
--   '[{
--     "value": "Evolution",
--     "trait_type": "Type"
--   }]'::jsonb,
--   2,
--   10
-- );

