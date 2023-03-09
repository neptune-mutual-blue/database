DROP VIEW IF EXISTS commitment_by_chain_view;

CREATE VIEW commitment_by_chain_view
AS
SELECT chain_id, SUM(amount_to_cover) AS commitment
FROM policy.cover_purchased
WHERE expires_on > EXTRACT(epoch FROM NOW() AT TIME ZONE 'UTC')
GROUP BY chain_id;

