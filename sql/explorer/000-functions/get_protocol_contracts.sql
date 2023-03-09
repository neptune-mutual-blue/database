DROP FUNCTION IF EXISTS get_protocol_contracts();

CREATE FUNCTION get_protocol_contracts()
RETURNS TABLE
(
  chain_id                                          uint256,
  namespace                                         text,
  contract_name                                     text,
  contract_address                                  text,
  added_on                                          integer,
  transaction_hash                                  text
)
AS
$$
  DECLARE _r                                        RECORD;
BEGIN
  DROP TABLE IF EXISTS _get_protocol_contracts_result;

  CREATE TEMPORARY TABLE _get_protocol_contracts_result
  (
    chain_id                                          uint256,
    namespace                                         text,
    contract_name                                     text,
    contract_address                                  text,
    added_on                                          integer,
    transaction_hash                                  text
  ) ON COMMIT DROP;

  INSERT INTO _get_protocol_contracts_result(chain_id, namespace, contract_address, added_on, transaction_hash)
  SELECT
    protocol.contract_added.chain_id,
    protocol.contract_added.namespace,
    protocol.contract_added.contract_address,
    protocol.contract_added.block_timestamp,
    protocol.contract_added.transaction_hash
  FROM protocol.contract_added;
  
  
  FOR _r IN
  (
    SELECT * FROM protocol.contract_upgraded 
    ORDER BY protocol.contract_upgraded.block_timestamp ASC
  )
  LOOP
    UPDATE _get_protocol_contracts_result
    SET
      contract_address = _r.current,
      added_on = _r.block_timestamp,
      transaction_hash = _r.transaction_hash
    FROM _r
    WHERE _r.chain_id = _get_protocol_contracts_result.chain_id
    AND _r.namespace = _get_protocol_contracts_result.namespace;
  END LOOP;
  

  UPDATE _get_protocol_contracts_result
  SET contract_name = config_contract_namespace_view.contract_name
  FROM config_contract_namespace_view
  WHERE config_contract_namespace_view.namespace = _get_protocol_contracts_result.namespace;

  RETURN QUERY
  SELECT * FROM _get_protocol_contracts_result;
END
$$
LANGUAGE plpgsql;

