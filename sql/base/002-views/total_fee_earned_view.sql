CREATE OR REPLACE VIEW total_fee_earned_view
AS
SELECT * FROM stablecoin_transactions_view
WHERE description = 'Fee Earned';

ALTER VIEW total_fee_earned_view OWNER TO writeuser;
