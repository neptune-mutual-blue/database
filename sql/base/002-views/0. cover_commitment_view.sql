DROP VIEW IF EXISTS cover_commitment_view;

CREATE VIEW cover_commitment_view
AS
SELECT chain_id, cover_key, SUM(amount_to_cover) AS commitment
FROM policy.cover_purchased
WHERE expires_on > EXTRACT(epoch FROM NOW() AT TIME ZONE 'UTC')
GROUP BY chain_id, cover_key;


