CREATE OR REPLACE FUNCTION get_datewise_liquidity_summary()
RETURNS TABLE
(
  id                                                        bigint,
  date                                                      TIMESTAMP WITH TIME ZONE,
  total_liquidity                                           numeric,
  total_capacity                                            numeric,
  total_covered                                             numeric,
  total_cover_fee                                           numeric,
  total_purchase_count                                      numeric  
)
SECURITY DEFINER
AS
$$
  DECLARE _start                                            TIMESTAMP WITH TIME ZONE;
  DECLARE _end                                              TIMESTAMP WITH TIME ZONE;
BEGIN
  CREATE UNLOGGED TABLE IF NOT EXISTS public.datewise_liquidity_summary
  (
    id                                                      BIGSERIAL,
    chain_id                                                uint256,
    date                                                    TIMESTAMP WITH TIME ZONE,
    total_liquidity                                         numeric,
    total_capacity                                          numeric,
    total_covered                                           numeric,
    total_cover_fee                                         numeric,
    total_purchase_count                                    numeric  
  );

  ALTER TABLE public.datewise_liquidity_summary OWNER TO writeuser;

  CREATE INDEX IF NOT EXISTS datewise_liquidity_summary_date_inx
  ON public.datewise_liquidity_summary(date);

  -- The final cache row is inevitably stale as its execution might have occurred prior to the end of the day.
  WITH stale_data
  AS
  (
    SELECT public.datewise_liquidity_summary.chain_id, MAX(public.datewise_liquidity_summary.date) AS date
    FROM public.datewise_liquidity_summary
    GROUP BY public.datewise_liquidity_summary.chain_id
  )
  DELETE FROM public.datewise_liquidity_summary
  WHERE (public.datewise_liquidity_summary.chain_id, public.datewise_liquidity_summary.date) IN
  (
    SELECT * FROM stale_data
  );

  WITH date_ranges
  AS
  (
    SELECT
      min(block_timestamp) AS min,
      max(block_timestamp) AS max
    FROM core.transactions
  )
  SELECT to_timestamp(min), to_timestamp(max)
  INTO _start, _end
  FROM date_ranges;


  SELECT COALESCE(summary.max_date, _start)
  INTO _start
  FROM
  (
    SELECT MAX(datewise_liquidity_summary.date) AS max_date
    FROM datewise_liquidity_summary
  ) AS summary;

  RAISE NOTICE 'Start date: %. End date: %', _start, _end;

  WITH chains
  AS
  (
    SELECT DISTINCT core.transactions.chain_id
    FROM core.transactions
  ),
  dates
  AS
  (
    SELECT date_trunc('day', dates)::date + interval '1 day' - interval '1 second' AS date
    FROM generate_series(_start, _end, INTERVAL '1 days') AS dates
  ),
  chainwise
  AS
  (
    SELECT DISTINCT chains.chain_id, dates.date
    FROM chains
    CROSS JOIN dates
  )
  INSERT INTO public.datewise_liquidity_summary(chain_id, date)
  SELECT chainwise.chain_id, chainwise.date
  FROM chainwise
  LEFT JOIN public.datewise_liquidity_summary
  ON chainwise.chain_id = public.datewise_liquidity_summary.chain_id
  AND chainwise.date = public.datewise_liquidity_summary.date
  WHERE public.datewise_liquidity_summary.chain_id IS NULL;

  UPDATE public.datewise_liquidity_summary
  SET total_liquidity = get_tvl_till_date(public.datewise_liquidity_summary.chain_id, public.datewise_liquidity_summary.date)
  WHERE public.datewise_liquidity_summary.total_liquidity IS NULL;

  UPDATE public.datewise_liquidity_summary
  SET total_capacity = get_total_capacity_by_date(public.datewise_liquidity_summary.chain_id, public.datewise_liquidity_summary.date)
  WHERE public.datewise_liquidity_summary.total_capacity IS NULL;

  UPDATE public.datewise_liquidity_summary
  SET total_covered = get_total_covered_till_date(public.datewise_liquidity_summary.chain_id, public.datewise_liquidity_summary.date)
  WHERE public.datewise_liquidity_summary.total_covered IS NULL;

  UPDATE public.datewise_liquidity_summary
  SET total_cover_fee = sum_cover_fee_earned_during(public.datewise_liquidity_summary.chain_id, '-infinity', public.datewise_liquidity_summary.date)
  WHERE public.datewise_liquidity_summary.total_cover_fee IS NULL;

  UPDATE public.datewise_liquidity_summary
  SET total_purchase_count = count_cover_purchase_during(public.datewise_liquidity_summary.chain_id, '-infinity', public.datewise_liquidity_summary.date)
  WHERE public.datewise_liquidity_summary.total_purchase_count IS NULL;

  RETURN QUERY
  SELECT
    row_number() OVER(ORDER BY public.datewise_liquidity_summary.date) AS id,
    public.datewise_liquidity_summary.date,
    SUM(public.datewise_liquidity_summary.total_liquidity) AS total_liquidity,
    SUM(public.datewise_liquidity_summary.total_capacity) AS total_capacity,
    SUM(public.datewise_liquidity_summary.total_covered) AS total_covered,
    SUM(public.datewise_liquidity_summary.total_cover_fee) AS total_cover_fee,
    SUM(public.datewise_liquidity_summary.total_purchase_count) AS total_purchase_count
  FROM public.datewise_liquidity_summary
  GROUP BY public.datewise_liquidity_summary.date;
END
$$
LANGUAGE plpgsql;

ALTER FUNCTION get_datewise_liquidity_summary() OWNER TO writeuser;
ALTER TABLE core.transactions owner to writeuser;
ALTER TABLE IF EXISTS public.datewise_liquidity_summary owner to writeuser;

-- SELECT * FROM get_datewise_liquidity_summary();

