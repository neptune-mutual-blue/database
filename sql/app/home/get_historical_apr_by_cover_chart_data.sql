DROP FUNCTION IF EXISTS get_historical_apr_by_cover_chart_data();

CREATE OR REPLACE FUNCTION get_historical_apr_by_cover_chart_data()
RETURNS TABLE
(
  chain_id                                  uint256,
  network_name                              text,
  cover_key                                 bytes32,
  cover_key_string                          text,
  start_date                                date,
  end_date                                  date,
  duration                                  integer,
  period_name                               text,
  start_balance                             numeric,
  end_balance                               numeric,
  policy_fee_earned                         numeric,
  apr                                       numeric
)
AS
$$
BEGIN
  CREATE TEMPORARY TABLE _get_historical_apr_chart_data_result
  (
    chain_id                                  uint256,
    network_name                              text,
    cover_key                                 bytes32,
    cover_key_string                          text,
    start_date                                date,
    end_date                                  date,
    duration                                  integer,
    period_name                               text,
    start_balance                             numeric,
    end_balance                               numeric,
    policy_fee_earned                         numeric,
    apr                                       NUMERIC DEFAULT(0)
  ) ON COMMIT DROP;
  
  
  INSERT INTO _get_historical_apr_chart_data_result(chain_id, cover_key, start_date)
  WITH dates
  AS
  (
    SELECT date_trunc('month',generate_series((SELECT to_timestamp(MIN(block_timestamp))::date FROM core.transactions), now(), '1 month'))
  )
  SELECT DISTINCT core.transactions.chain_id, core.transactions.ck, dates.*
  FROM core.transactions
  CROSS JOIN dates
  WHERE core.transactions.ck IS NOT NULL;  
  
  UPDATE _get_historical_apr_chart_data_result
  SET
    cover_key_string  = bytes32_to_string(_get_historical_apr_chart_data_result.cover_key),
    end_date          = (_get_historical_apr_chart_data_result.start_date + '1 month'::interval - '1 day'::interval),
    period_name       = to_char(_get_historical_apr_chart_data_result.start_date, 'Mon-YY'),
    start_balance     = get_tvl_till_date(_get_historical_apr_chart_data_result.chain_id, _get_historical_apr_chart_data_result.cover_key, _get_historical_apr_chart_data_result.start_date);
  
  UPDATE _get_historical_apr_chart_data_result
  SET end_date = NOW()
  WHERE _get_historical_apr_chart_data_result.end_date > NOW();

  UPDATE _get_historical_apr_chart_data_result
  SET
    policy_fee_earned = sum_cover_purchased_during(_get_historical_apr_chart_data_result.chain_id, _get_historical_apr_chart_data_result.cover_key, _get_historical_apr_chart_data_result.start_date, _get_historical_apr_chart_data_result.end_date),
    duration = _get_historical_apr_chart_data_result.end_date - _get_historical_apr_chart_data_result.start_date,
    end_balance       = get_tvl_till_date(_get_historical_apr_chart_data_result.chain_id, _get_historical_apr_chart_data_result.cover_key, _get_historical_apr_chart_data_result.end_date);
  
  UPDATE _get_historical_apr_chart_data_result
  SET apr = (_get_historical_apr_chart_data_result.policy_fee_earned * 365) / (average(_get_historical_apr_chart_data_result.start_balance, _get_historical_apr_chart_data_result.end_balance) * _get_historical_apr_chart_data_result.duration)
  WHERE _get_historical_apr_chart_data_result.start_balance > 0;
  
  UPDATE _get_historical_apr_chart_data_result
  SET network_name = config_blockchain_network_view.nick_name
  FROM config_blockchain_network_view
  WHERE config_blockchain_network_view.chain_id = _get_historical_apr_chart_data_result.chain_id;

  RETURN QUERY
  SELECT * FROM _get_historical_apr_chart_data_result
  ORDER BY 2, 1;
END
$$
LANGUAGE plpgsql;

-- SELECT * FROM get_historical_apr_by_cover_chart_data() ORDER BY APR DESC;




