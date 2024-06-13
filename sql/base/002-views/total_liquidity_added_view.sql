CREATE OR REPLACE VIEW total_liquidity_added_view
AS
SELECT * FROM stablecoin_transactions_view
WHERE description = 'Liquidity Added';

ALTER VIEW total_liquidity_added_view OWNER TO writeuser;
