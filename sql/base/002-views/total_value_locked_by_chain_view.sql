CREATE OR REPLACE VIEW total_value_locked_by_chain_view
AS
SELECT chain_id, sum(total) as total
FROM stablecoin_transactions_view
GROUP by chain_id;

ALTER VIEW total_value_locked_by_chain_view OWNER TO writeuser;
