DROP VIEW IF EXISTS total_liquidity_added_view;

CREATE VIEW total_liquidity_added_view
AS
SELECT * FROM stablecoin_transactions_view
WHERE description = 'Liquidity Added';
