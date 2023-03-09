DROP FUNCTION IF EXISTS get_capacity_chart_data() CASCADE;

CREATE OR REPLACE FUNCTION get_capacity_chart_data()
RETURNS TABLE
(
  till                          TIMESTAMP WITH TIME ZONE,
  amount                        uint256
)
AS
$$
BEGIN
  DROP TABLE IF EXISTS _get_total_capacity_chart_data_result;

  CREATE TEMPORARY TABLE _get_total_capacity_chart_data_result
  (
    till                          TIMESTAMP WITH TIME ZONE,
    amount                        uint256
  ) ON COMMIT DROP;
  
  INSERT INTO _get_total_capacity_chart_data_result(till)
  SELECT DISTINCT ((to_timestamp(block_timestamp) AT TIME ZONE 'UTC')::date + interval '1 day - 1 sec')::TIMESTAMP WITH TIME ZONE AT TIME ZONE 'UTC'
  FROM core.transactions
  WHERE core.transactions.event_name IN ('CoverPurchased', 'PodsIssued', 'PodsRedeemed', 'Claimed', 'PoolCapitalized');

  UPDATE _get_total_capacity_chart_data_result
  SET amount = get_total_capacity_by_date(_get_total_capacity_chart_data_result.till);

  RETURN QUERY
  SELECT * FROM _get_total_capacity_chart_data_result
  ORDER BY 1 ASC;
END
$$
LANGUAGE plpgsql;


-- SELECT  *
-- FROM get_capacity_chart_data();
