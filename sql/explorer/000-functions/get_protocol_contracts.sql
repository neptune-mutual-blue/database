CREATE OR REPLACE FUNCTION get_protocol_contracts()
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
    CASE
      WHEN protocol.contract_added.namespace ILIKE '0x%'
      THEN bytes32_to_string(protocol.contract_added.namespace)
      ELSE protocol.contract_added.namespace
    END,
    protocol.contract_added.contract_address,
    protocol.contract_added.block_timestamp,
    protocol.contract_added.transaction_hash
  FROM protocol.contract_added;

  INSERT INTO _get_protocol_contracts_result(chain_id, namespace, contract_name, contract_address, added_on, transaction_hash)
  SELECT
    cover.cover_initialized.chain_id,
    'cns:cover:sc',
    'Stablecoin',
    cover.cover_initialized.stablecoin,
    cover.cover_initialized.block_timestamp,
    cover.cover_initialized.transaction_hash
  FROM cover.cover_initialized;

  INSERT INTO _get_protocol_contracts_result(chain_id, namespace, contract_name, contract_address)
  SELECT
    config_blockchain_network_view.chain_id,
    null,
    'Store',
    config_blockchain_network_view.store_address
  FROM config_blockchain_network_view;

  INSERT INTO _get_protocol_contracts_result(chain_id, namespace, contract_name, contract_address)
  SELECT
    config_blockchain_network_view.chain_id,
    'cns:core',
    'Protocol',
    config_blockchain_network_view.protocol_address
  FROM config_blockchain_network_view;

  INSERT INTO _get_protocol_contracts_result(chain_id, namespace, contract_name, contract_address)
  SELECT
    config_blockchain_network_view.chain_id,
    'cns:core:npm:instance',
    'NPM',
    config_blockchain_network_view.npm_address
  FROM config_blockchain_network_view;

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

-- SELECT * FROM get_protocol_contracts();
