DROP VIEW IF EXISTS total_value_locked_view;

CREATE VIEW total_value_locked_view
AS
SELECT sum(total) as total
FROM stablecoin_transactions_view;

