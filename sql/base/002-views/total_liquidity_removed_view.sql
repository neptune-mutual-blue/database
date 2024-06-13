CREATE OR REPLACE VIEW total_liquidity_removed_view
AS
SELECT * FROM stablecoin_transactions_view
WHERE description = 'Liquidity Removed';

ALTER VIEW total_liquidity_removed_view OWNER TO writeuser;
