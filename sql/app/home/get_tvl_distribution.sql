DROP FUNCTION IF EXISTS get_tvl_distribution();

CREATE FUNCTION get_tvl_distribution()
RETURNS TABLE
(
  chain_id                                            numeric,
  covered                                             numeric,
  commitment                                          numeric,
  cover_fee_earned                                    numeric,
  total_value_locked                                  numeric,
  capacity                                            numeric
)
AS
$$
BEGIN
  DROP TABLE IF EXISTS _get_tvl_distribution_result;
  CREATE TEMPORARY TABLE _get_tvl_distribution_result
  (
    chain_id                                            numeric,
    covered                                             numeric,
    commitment                                          numeric,
    cover_fee_earned                                    numeric,
    total_value_locked                                  numeric,
    capacity                                            numeric
  ) ON COMMIT DROP;
  
  INSERT INTO _get_tvl_distribution_result(chain_id, capacity)
  SELECT capacity_by_chain_view.chain_id, capacity_by_chain_view.total_capacity
  FROM capacity_by_chain_view;
  
  UPDATE _get_tvl_distribution_result
  SET commitment = commitment_by_chain_view.commitment
  FROM commitment_by_chain_view
  WHERE _get_tvl_distribution_result.chain_id = commitment_by_chain_view.chain_id;
  
  UPDATE _get_tvl_distribution_result
  SET covered = total_coverage_by_chain_view.total_coverage
  FROM total_coverage_by_chain_view
  WHERE _get_tvl_distribution_result.chain_id = total_coverage_by_chain_view.chain_id;
  
  UPDATE _get_tvl_distribution_result
  SET cover_fee_earned = fee_earned_by_chain_view.total_fee
  FROM fee_earned_by_chain_view
  WHERE _get_tvl_distribution_result.chain_id = fee_earned_by_chain_view.chain_id;
  
  UPDATE _get_tvl_distribution_result
  SET total_value_locked = total_value_locked_by_chain_view.total
  FROM total_value_locked_by_chain_view
  WHERE _get_tvl_distribution_result.chain_id = total_value_locked_by_chain_view.chain_id;
  
    
  RETURN QUERY
  SELECT * FROM _get_tvl_distribution_result;
END
$$
LANGUAGE plpgsql;

