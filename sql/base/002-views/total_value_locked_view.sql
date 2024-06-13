CREATE OR REPLACE VIEW total_value_locked_view
AS
SELECT sum(total) as total
FROM stablecoin_transactions_view;

ALTER VIEW total_value_locked_view OWNER TO writeuser;
