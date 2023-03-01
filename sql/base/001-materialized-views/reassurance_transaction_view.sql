DROP MATERIALIZED VIEW IF EXISTS reassurance_transaction_view CASCADE;

CREATE MATERIALIZED VIEW reassurance_transaction_view
AS
SELECT
  'Reassurance Added' AS description,  
  reassurance.reassurance_added.chain_id,
  reassurance.reassurance_added.cover_key,
  SUM(reassurance.reassurance_added.amount) AS total
FROM reassurance.reassurance_added
GROUP BY 
  reassurance.reassurance_added.chain_id,
  reassurance.reassurance_added.cover_key
UNION ALL
SELECT
  'Pool Capitalized' AS description,  
  reassurance.pool_capitalized.chain_id,
  reassurance.pool_capitalized.cover_key,
  SUM(reassurance.pool_capitalized.amount) * -1
FROM reassurance.pool_capitalized
GROUP BY 
  reassurance.pool_capitalized.chain_id,
  reassurance.pool_capitalized.cover_key;

CREATE UNIQUE INDEX description_chain_id_cover_key_reassurance_transaction_view
ON reassurance_transaction_view(description, chain_id, cover_key);

CREATE INDEX chain_id_cover_key_reassurance_transaction_view_inx
ON reassurance_transaction_view(chain_id, cover_key);


DROP FUNCTION IF EXISTS core.refresh_reassurance_transaction_view_trigger() CASCADE;

CREATE FUNCTION core.refresh_reassurance_transaction_view_trigger()
RETURNS trigger
AS
$$
BEGIN
  REFRESH MATERIALIZED VIEW CONCURRENTLY reassurance_transaction_view;
END
$$
LANGUAGE plpgsql;


CREATE TRIGGER refresh_reassurance_transaction_view_trigger
BEFORE INSERT OR UPDATE ON core.transactions
FOR EACH STATEMENT
EXECUTE FUNCTION core.refresh_reassurance_transaction_view_trigger();