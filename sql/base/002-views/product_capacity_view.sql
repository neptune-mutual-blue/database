DROP VIEW IF EXISTS product_capacity_view;

CREATE VIEW product_capacity_view
AS
WITH summary
AS
(
	SELECT
		config_product_view.chain_id,
		config_product_view.cover_key,
		config_product_view.product_key,
		config_product_view.capital_efficiency,
		config_cover_view.leverage,
		count_products(config_product_view.chain_id, config_product_view.cover_key) AS siblings
	FROM config_product_view
	INNER JOIN config_cover_view
	ON config_cover_view.chain_id = config_product_view.chain_id
	AND config_cover_view.cover_key = config_product_view.cover_key
	WHERE config_product_view.chain_id IN
	(
		SELECT DISTINCT core.transactions.chain_id
		FROM core.transactions
	)
)
SELECT
	summary.chain_id,
	summary.cover_key,
	summary.product_key,
	cover_capacity_view.capacity * summary.leverage *  summary.capital_efficiency / (10000 * summary.siblings) AS capacity
FROM summary
INNER JOIN cover_capacity_view
ON cover_capacity_view.chain_id = summary.chain_id
AND cover_capacity_view.cover_key = summary.cover_key;

