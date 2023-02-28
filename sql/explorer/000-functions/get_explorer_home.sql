-- @todo: ensure that the dynamic query doesn't result in an injection attack
 
DROP FUNCTION IF EXISTS get_explorer_home
(
  _sort_by                                        text,
  _sort_direction                                 text,
  _page_number                                    integer,
  _page_size                                      integer,
  _date_from                                      TIMESTAMP WITH TIME ZONE,
  _date_to                                        TIMESTAMP WITH TIME ZONE,
  _networks                                       numeric[],
  _contracts                                      text[],
  _cover_key_like                                 text,
  _event_name_like                                text,
  _coupon_code_like                               text
);

CREATE FUNCTION get_explorer_home
(
  _sort_by                                        text,
  _sort_direction                                 text,
  _page_number                                    integer,
  _page_size                                      integer,
  _date_from                                      TIMESTAMP WITH TIME ZONE,
  _date_to                                        TIMESTAMP WITH TIME ZONE,
  _networks                                       numeric[],
  _contracts                                      text[],
  _cover_key_like                                 text,
  _event_name_like                                text,
  _coupon_code_like                               text
)
RETURNS TABLE
(
  id                                              uuid,
  chain_id                                        uint256,
  date                                            TIMESTAMP WITH TIME ZONE,
  event_name                                      text,
  coupon_code                                     text,
  transaction_sender                              address,
  cover_key                                       text,
  product_key                                     text,
  transaction_stablecoin_amount                   uint256,
  transaction_npm_amount                          uint256,
  page_size                                       integer,
  page_number                                     integer,
  total_records                                   integer,
  total_pages                                     integer
)
STABLE
AS
$$
  DECLARE _total_records                          integer;
  DECLARE _total_pages                            integer;
  DECLARE _query                                  text;
BEGIN
  IF(COALESCE(_sort_direction, '') = '') THEN
    _sort_direction := 'ASC';
  END IF;
  
  IF(_networks IS NULL) THEN
    _networks := array_agg(DISTINCT core.transactions.chain_id) FROM core.transactions;
  END IF;

  IF NOT(_sort_by IN('chain_id', 'date', 'event_name', 'coupon_code', 'transaction_sender', 'cover_key', 'product_key')) THEN
    RAISE EXCEPTION 'Invalid sort_by value %', _sort_by;
  END IF;
  
  IF(_sort_by = 'date') THEN
    _sort_by := 'block_timestamp';
  END IF;
    
  IF NOT(_sort_direction IN('ASC', 'DESC')) THEN
    RAISE EXCEPTION 'Invalid sort_direction value %', _sort_direction;
  END IF;
  
  IF(_page_number < 1) THEN
    RAISE EXCEPTION 'Invalid page_number value %', _page_number;  
  END IF;
  
  IF(_page_size < 1) THEN
    RAISE EXCEPTION 'Invalid _page_size value %', _page_size;  
  END IF;
  
  
  _query := format('
  WITH result AS
  (
    SELECT * FROM core.transactions
    WHERE core.transactions.block_timestamp
      BETWEEN extract(epoch from COALESCE(%L, ''1-1-1990''::date))
      AND extract(epoch from COALESCE(%L, ''1-1-2990''::date))
    AND core.transactions.chain_id = ANY(%L)
    AND 
    (
        COALESCE(core.transactions.ck, '''') ILIKE ''%%%s%%''
        OR 
        COALESCE(core.transactions.pk, '''') ILIKE ''%%%s%%''
    )
    AND core.transactions.event_name ILIKE ''%%%s%%''
    AND COALESCE(core.transactions.coupon_code, '''') ILIKE ''%%%s%%''
  )
  SELECT COUNT(*) FROM result;', _date_from, _date_to, _networks, _cover_key_like, _cover_key_like, _event_name_like, _coupon_code_like);
  
  -- RAISE NOTICE '%', _query;

  EXECUTE _query
  INTO _total_records;
  
  
  _total_pages = 1; --+ COALESCE(_total_records / _page_size, 0);
  
   _query := format('
    SELECT
    core.transactions.id,
    core.transactions.chain_id,
    to_timestamp(core.transactions.block_timestamp)::TIMESTAMP WITH TIME ZONE AS date,
    core.transactions.event_name,
    CASE 
      WHEN core.transactions.coupon_code = ''0x0000000000000000000000000000000000000000000000000000000000000000''
      THEN NULL 
      ELSE core.transactions.coupon_code 
    END AS coupon_code,
    core.transactions.transaction_sender,
    core.transactions.ck AS cover_key,
    core.transactions.pk AS product_key,
    core.transactions.transaction_stablecoin_amount,
    core.transactions.transaction_npm_amount,
    %s AS page_size,
    %s AS page_number,
    %s AS toal_records,
    %s AS toal_pages
  FROM core.transactions
  WHERE core.transactions.block_timestamp
    BETWEEN extract(epoch from COALESCE(%L, ''1-1-1990''::date))
    AND extract(epoch from COALESCE(%L, ''1-1-2990''::date))
  AND core.transactions.chain_id = ANY(%L)
  AND 
  (
      COALESCE(core.transactions.ck, '''') ILIKE ''%%%s%%''
      OR 
      COALESCE(core.transactions.pk, '''') ILIKE ''%%%s%%''
  )
  AND core.transactions.event_name ILIKE ''%%%s%%''
  AND COALESCE(core.transactions.coupon_code, '''') ILIKE ''%%%s%%''
  ORDER BY %s %s
  LIMIT %s::integer
  OFFSET %s::integer * %s::integer  
  ', _page_size, _page_number, _total_records, _total_pages, _date_from, _date_to, _networks, _cover_key_like, _cover_key_like, _event_name_like, _coupon_code_like, _sort_by, _sort_direction, _page_size, _page_number - 1, _page_size);

  --RAISE NOTICE '%', _query;
  RETURN QUERY EXECUTE _query;
END
$$
LANGUAGE plpgsql;


-- SELECT * FROM get_explorer_home
-- (
--   'date', --_sort_by                                        text,
--   'DESC', --_sort_direction                                 text,
--   1, --_page_number                                    integer,
--   20000, --_page_size                                      integer,
--   NULL, --_date_from                                      TIMESTAMP WITH TIME ZONE,
--   '1-1-2099'::date, --_date_to                                        TIMESTAMP WITH TIME ZONE,
--   NULL, --_networks                                       numeric[],
--   NULL, --_contracts                                      text[],
--   '0x',-- _cover_key_like                                 text,
--   'Deploy', --_event_name_like                                text,
--   '' --_coupon_code_like                               text
-- );
