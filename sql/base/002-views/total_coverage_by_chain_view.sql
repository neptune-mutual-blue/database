DROP VIEW IF EXISTS total_coverage_by_chain_view;

CREATE VIEW total_coverage_by_chain_view
AS
SELECT chain_id, SUM(get_stablecoin_value(chain_id, amount_to_cover)) AS total_coverage
FROM policy.cover_purchased
GROUP BY chain_id;

