DROP VIEW IF EXISTS toal_value_locked_view;

CREATE VIEW toal_value_locked_view
AS
SELECT sum(total) as total
FROM stablecoin_transactions_view;

