DROP VIEW IF EXISTS total_fee_earned_view;

CREATE VIEW total_fee_earned_view
AS
SELECT * FROM stablecoin_transactions_view
WHERE description = 'Fee Earned';

