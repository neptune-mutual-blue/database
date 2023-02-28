DROP FUNCTION IF EXISTS get_product_summary();

CREATE FUNCTION get_product_summary()
RETURNS TABLE
(
	chain_id 						numeric,
	cover_key 						text,
	product_key						text,
	floor							numeric,
	ceiling							numeric,
	leverage							numeric,
	capital_efficiency				numeric,
	capacity	 						numeric,
	commitment 						numeric,
  utilization_ratio       numeric,
	reassurance 						numeric
)
AS
$$
BEGIN
	CREATE TEMPORARY TABLE _get_product_summary_result
	(
		chain_id 						numeric,
		cover_key 						text,
		product_key						text,
		floor							numeric DEFAULT(0),
		ceiling							numeric DEFAULT(0),
		leverage							numeric DEFAULT(0),
		capital_efficiency				numeric DEFAULT(0),
		capacity	 						numeric DEFAULT(0),
		commitment 						numeric DEFAULT(0),
    utilization_ratio       numeric,
		reassurance 						numeric DEFAULT(0)
	) ON COMMIT DROP;
	
	INSERT INTO _get_product_summary_result(chain_id, cover_key, product_key, capital_efficiency)
	SELECT
		config_product_view.chain_id,
		config_product_view.cover_key,
		config_product_view.product_key,
		config_product_view.capital_efficiency
	FROM config_product_view
	WHERE config_product_view.chain_id IN
	(
		SELECT DISTINCT core.transactions.chain_id
		FROM core.transactions
	);
	
	UPDATE _get_product_summary_result
	SET leverage = config_cover_view.leverage
	FROM config_cover_view
	WHERE config_cover_view.chain_id = _get_product_summary_result.chain_id
	AND config_cover_view.cover_key = _get_product_summary_result.cover_key;

	INSERT INTO _get_product_summary_result(chain_id, cover_key, leverage, capital_efficiency)
	SELECT
		cover.cover_created.chain_id,
		cover.cover_created.cover_key,
		1 AS leverage,
		100 AS capital_efficiency
	FROM cover.cover_created;
	
	UPDATE _get_product_summary_result
	SET
		floor = config_cover_view.policy_floor,
		ceiling = config_cover_view.policy_ceiling
	FROM config_cover_view
	WHERE config_cover_view.chain_id = _get_product_summary_result.chain_id
	AND config_cover_view.cover_key = _get_product_summary_result.cover_key;
	
	
	UPDATE _get_product_summary_result
	SET capacity = cover_capacity_view.capacity
	FROM cover_capacity_view
	WHERE cover_capacity_view.chain_id = _get_product_summary_result.chain_id
	AND cover_capacity_view.cover_key = _get_product_summary_result.cover_key
	AND _get_product_summary_result.product_key IS NULL;
	
	UPDATE _get_product_summary_result
	SET capacity = product_capacity_view.capacity
	FROM product_capacity_view
	WHERE product_capacity_view.chain_id = _get_product_summary_result.chain_id
	AND product_capacity_view.cover_key = _get_product_summary_result.cover_key
	AND product_capacity_view.product_key = _get_product_summary_result.product_key;

	UPDATE _get_product_summary_result
	SET commitment = product_commitment_view.commitment
	FROM product_commitment_view
	WHERE product_commitment_view.chain_id = _get_product_summary_result.chain_id
	AND product_commitment_view.cover_key = _get_product_summary_result.cover_key
	AND product_commitment_view.product_key = _get_product_summary_result.product_key;

	UPDATE _get_product_summary_result
	SET commitment = product_commitment_view.commitment
	FROM product_commitment_view
	WHERE product_commitment_view.chain_id = _get_product_summary_result.chain_id
	AND product_commitment_view.cover_key = _get_product_summary_result.cover_key
	AND product_commitment_view.product_key = '0x0000000000000000000000000000000000000000000000000000000000000000'
	AND _get_product_summary_result.product_key IS NULL;
	
	
	UPDATE _get_product_summary_result
	SET commitment = cover_commitment_view.commitment
	FROM cover_commitment_view
	WHERE cover_commitment_view.chain_id = _get_product_summary_result.chain_id
	AND cover_commitment_view.cover_key = _get_product_summary_result.cover_key
	AND _get_product_summary_result.product_key IS NULL;
	
	UPDATE _get_product_summary_result
	SET reassurance = cover_reassurance_view.reassurance
	FROM cover_reassurance_view
	WHERE cover_reassurance_view.chain_id = _get_product_summary_result.chain_id
	AND cover_reassurance_view.cover_key = _get_product_summary_result.cover_key;
  
  UPDATE _get_product_summary_result
  SET utilization_ratio = _get_product_summary_result.commitment / _get_product_summary_result.capacity;

	RETURN QUERY
	SELECT * FROM _get_product_summary_result;
END
$$
LANGUAGE plpgsql;


