CREATE OR REPLACE VIEW reassurance_transaction_view
AS
SELECT
  'Reassurance Added' AS description,  
  reassurance.reassurance_added.chain_id,
  reassurance.reassurance_added.cover_key,
  SUM(get_stablecoin_value(reassurance.reassurance_added.chain_id, reassurance.reassurance_added.amount)) AS total
FROM reassurance.reassurance_added
GROUP BY 
  reassurance.reassurance_added.chain_id,
  reassurance.reassurance_added.cover_key
UNION ALL
SELECT
  'Pool Capitalized' AS description,  
  reassurance.pool_capitalized.chain_id,
  reassurance.pool_capitalized.cover_key,
  SUM(get_stablecoin_value(reassurance.pool_capitalized.chain_id, reassurance.pool_capitalized.amount)) * -1
FROM reassurance.pool_capitalized
GROUP BY 
  reassurance.pool_capitalized.chain_id,
  reassurance.pool_capitalized.cover_key;

ALTER VIEW reassurance_transaction_view OWNER TO writeuser;
