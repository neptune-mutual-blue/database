DROP VIEW IF EXISTS total_liquidity_removed_view;

CREATE VIEW total_liquidity_removed_view
AS
SELECT * FROM stablecoin_transactions_view
WHERE description = 'Liquidity Removed';

