DROP FUNCTION get_apy_by_cover();

CREATE OR REPLACE FUNCTION get_apy_by_cover()
RETURNS TABLE
(
  chain_id                                    uint256,
  cover_key                                   bytes32,
  tvl_last_12_months                          numeric,
  apy_last_12_months                          numeric,
  total_income_last_12_months                 numeric,
  tvl_last_month                              numeric,
  apy_last_month                              numeric,
  total_income_last_month                     numeric,
  tvl_last_3_months                           numeric,
  apy_last_3_months                           numeric,
  total_income_last_3_months                  numeric,
  tvl_last_6_months                           numeric,
  apy_last_6_months                           numeric,
  total_income_last_6_months                  numeric,
  max_apy                                     numeric
)
AS
$$
BEGIN
  CREATE TEMPORARY TABLE _get_apy_by_cover_result
  (
    chain_id                                  uint256,
    cover_key                                 bytes32,
    tvl_last_12_months                        numeric,
    apy_last_12_months                        numeric DEFAULT(0),
    total_income_last_12_months               numeric,
    tvl_last_month                            numeric,
    apy_last_month                            numeric DEFAULT(0),
    total_income_last_month                   numeric,
    tvl_last_3_months                         numeric,
    apy_last_3_months                         numeric DEFAULT(0),
    total_income_last_3_months                numeric,
    tvl_last_6_months                         numeric,
    apy_last_6_months                         numeric DEFAULT(0),
    total_income_last_6_months                numeric,
    max_apy                                   numeric
  ) ON COMMIT DROP;

  INSERT INTO _get_apy_by_cover_result(chain_id, cover_key)
  SELECT DISTINCT core.transactions.chain_id, core.transactions.ck
  FROM core.transactions
  WHERE core.transactions.ck IS NOT NULL;

  UPDATE _get_apy_by_cover_result
  SET
    tvl_last_12_months          = get_tvl_till_date(_get_apy_by_cover_result.chain_id, _get_apy_by_cover_result.cover_key, now() - 12 * '1 month'::interval),
    total_income_last_12_months = sum_cover_purchased_during(_get_apy_by_cover_result.chain_id, _get_apy_by_cover_result.cover_key, now() - 12 * '1 month'::interval, now()),
    tvl_last_6_months           = get_tvl_till_date(_get_apy_by_cover_result.chain_id, _get_apy_by_cover_result.cover_key, now() - 6 * '1 month'::interval),
    total_income_last_6_months  = sum_cover_purchased_during(_get_apy_by_cover_result.chain_id, _get_apy_by_cover_result.cover_key, now() - 6 * '1 month'::interval, now()),
    tvl_last_3_months           = get_tvl_till_date(_get_apy_by_cover_result.chain_id, _get_apy_by_cover_result.cover_key, now() - 3 * '1 month'::interval),
    total_income_last_3_months  = sum_cover_purchased_during(_get_apy_by_cover_result.chain_id, _get_apy_by_cover_result.cover_key, now() - 3 * '1 month'::interval, now()),
    tvl_last_month              = get_tvl_till_date(_get_apy_by_cover_result.chain_id, _get_apy_by_cover_result.cover_key, now() - 1 * '1 month'::interval),
    total_income_last_month     = sum_cover_purchased_during(_get_apy_by_cover_result.chain_id, _get_apy_by_cover_result.cover_key, now() - 1 * '1 month'::interval, now());

  UPDATE _get_apy_by_cover_result
  SET
    apy_last_12_months = CASE WHEN _get_apy_by_cover_result.tvl_last_12_months > 0 THEN _get_apy_by_cover_result.total_income_last_12_months / _get_apy_by_cover_result.tvl_last_12_months ELSE 0 END,
    apy_last_6_months  = CASE WHEN _get_apy_by_cover_result.tvl_last_6_months > 0  THEN _get_apy_by_cover_result.total_income_last_6_months  / _get_apy_by_cover_result.tvl_last_6_months  ELSE 0 END,
    apy_last_3_months  = CASE WHEN _get_apy_by_cover_result.tvl_last_3_months > 0  THEN _get_apy_by_cover_result.total_income_last_3_months  / _get_apy_by_cover_result.tvl_last_3_months  ELSE 0 END,
    apy_last_month     = CASE WHEN _get_apy_by_cover_result.tvl_last_month > 0     THEN _get_apy_by_cover_result.total_income_last_month     / _get_apy_by_cover_result.tvl_last_month     ELSE 0 END;

    -- Calculate APY values using the formulas and find the maximum value
  UPDATE _get_apy_by_cover_result
  SET
    max_apy = GREATEST(_get_apy_by_cover_result.apy_last_12_months, _get_apy_by_cover_result.apy_last_6_months, _get_apy_by_cover_result.apy_last_3_months, _get_apy_by_cover_result.apy_last_month);
    
  RETURN QUERY
  SELECT * FROM _get_apy_by_cover_result;
END
$$
LANGUAGE plpgsql;

-- SELECT * FROM get_apy_by_cover();
