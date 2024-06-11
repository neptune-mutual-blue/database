CREATE OR REPLACE FUNCTION get_historical_apr_chart_data()
RETURNS TABLE
(
  chain_id                                    uint256,
  network_name                                text,
  start_date                                  TIMESTAMP WITH TIME ZONE,
  end_date                                    TIMESTAMP WITH TIME ZONE,
  duration                                    integer,
  period_name                                 text,
  start_balance                               numeric,
  policy_fee_earned                           numeric,
  apr                                         numeric
)
AS
$$
BEGIN
  CREATE TEMPORARY TABLE _get_historical_apr_chart_data_result
  (
    chain_id                                  uint256,
    network_name                              text,
    start_date                                TIMESTAMP WITH TIME ZONE,
    end_date                                  TIMESTAMP WITH TIME ZONE,
    duration                                  integer,
    period_name                               text,
    start_balance                             numeric,
    policy_fee_earned                         numeric,
    apr                                       NUMERIC DEFAULT(0)
  ) ON COMMIT DROP;


  INSERT INTO _get_historical_apr_chart_data_result(chain_id, start_date)
  WITH dates
  AS
  (
    SELECT date_trunc('month', generate_series((SELECT to_timestamp(MIN(block_timestamp))::date FROM core.transactions), NOW() AT TIME ZONE 'UTC', '1 month'))
  )
  SELECT DISTINCT
    core.transactions.chain_id,
    dates.*
  FROM core.transactions
  CROSS JOIN dates;


  UPDATE _get_historical_apr_chart_data_result
  SET
    end_date          = (_get_historical_apr_chart_data_result.start_date + '1 month'::interval - '1 millisecond'::interval),
    period_name       = to_char(_get_historical_apr_chart_data_result.start_date, 'Mon-YY'),
    start_balance     = get_tvl_till_date(_get_historical_apr_chart_data_result.chain_id, _get_historical_apr_chart_data_result.start_date);

  UPDATE _get_historical_apr_chart_data_result
  SET end_date        = NOW()
  WHERE _get_historical_apr_chart_data_result.end_date > NOW();

  UPDATE _get_historical_apr_chart_data_result
  SET
    policy_fee_earned = sum_cover_fee_earned_during(_get_historical_apr_chart_data_result.chain_id, _get_historical_apr_chart_data_result.start_date, _get_historical_apr_chart_data_result.end_date),
    duration          = EXTRACT(DAY FROM (_get_historical_apr_chart_data_result.end_date - _get_historical_apr_chart_data_result.start_date))::integer;

  UPDATE _get_historical_apr_chart_data_result
  SET apr             = (_get_historical_apr_chart_data_result.policy_fee_earned * 365) / (_get_historical_apr_chart_data_result.start_balance * _get_historical_apr_chart_data_result.duration)
  WHERE _get_historical_apr_chart_data_result.start_balance > 0;

  UPDATE _get_historical_apr_chart_data_result
  SET network_name    = config_blockchain_network_view.nick_name
  FROM config_blockchain_network_view
  WHERE config_blockchain_network_view.chain_id = _get_historical_apr_chart_data_result.chain_id;

  RETURN QUERY
  SELECT * FROM _get_historical_apr_chart_data_result
  ORDER BY 2, 1;
END
$$
LANGUAGE plpgsql;

ALTER FUNCTION get_historical_apr_chart_data OWNER TO writeuser;

-- SELECT * FROM get_historical_apr_chart_data();
