DROP VIEW IF EXISTS capacity_by_chain_view;

CREATE VIEW capacity_by_chain_view
AS
SELECT chain_id, sum(capacity) AS total_capacity
FROM capacity_view
GROUP BY chain_id;
