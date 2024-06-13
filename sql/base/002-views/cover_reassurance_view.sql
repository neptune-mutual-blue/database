CREATE OR REPLACE VIEW cover_reassurance_view
AS
SELECT chain_id, cover_key, SUM(total) AS reassurance
FROM reassurance_transaction_view
GROUP BY chain_id, cover_key;

ALTER VIEW cover_reassurance_view OWNER TO writeuser;
