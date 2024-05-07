CREATE OR REPLACE FUNCTION get_gauge_pool_locked_balance(_chain_id uint256, _pool_address address)
RETURNS numeric
AS
$$
DECLARE
  total_deposit     numeric;
  total_withdrawal  numeric;
BEGIN
  SELECT COALESCE(SUM(ve.liquidity_gauge_deposited.amount), 0) INTO total_deposit
  FROM ve.liquidity_gauge_deposited
  WHERE 1 = 1
  AND ve.liquidity_gauge_deposited.address  = _pool_address
  AND ve.liquidity_gauge_deposited.chain_id = _chain_id;

  SELECT COALESCE(SUM(ve.liquidity_gauge_withdrawn.amount), 0) INTO total_withdrawal
  FROM ve.liquidity_gauge_withdrawn
  WHERE 1 = 1
  AND ve.liquidity_gauge_withdrawn.address  = _pool_address
  AND ve.liquidity_gauge_withdrawn.chain_id = _chain_id;

  RETURN total_deposit - total_withdrawal;
END
$$
LANGUAGE plpgsql;

ALTER FUNCTION get_gauge_pool_locked_balance(_chain_id uint256, _pool_address address) OWNER TO writeuser;

-- SELECT get_gauge_pool_locked_balance(42161, '0xe78b4f044ef559e79103e9d31d734c60932d0fe2');
