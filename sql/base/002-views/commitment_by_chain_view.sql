DROP VIEW IF EXISTS commitment_by_chain_view;

CREATE VIEW commitment_by_chain_view
AS
SELECT chain_id, SUM(amount_to_cover) AS commitment
FROM policy.cover_purchased
WHERE expires_on > extract(epoch from now() at time zone 'utc')
GROUP BY chain_id;

