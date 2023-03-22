DROP VIEW IF EXISTS product_commitment_view;

CREATE VIEW product_commitment_view
AS
SELECT
  chain_id,
  cover_key,
  product_key,
  get_commitment(chain_id, cover_key, product_key) AS commitment
FROM policy.cover_purchased
GROUP BY chain_id, cover_key, product_key;

 