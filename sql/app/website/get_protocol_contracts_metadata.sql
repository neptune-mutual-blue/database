DROP FUNCTION IF EXISTS get_protocol_contracts_metadata(_chain_id uint256) CASCADE;

CREATE FUNCTION get_protocol_contracts_metadata(_chain_id uint256)
RETURNS TABLE
(
  chain_id                              uint256,
  network                               text,
  contracts                             jsonb,
  pods                                  jsonb,
  cx_tokens                             jsonb,
  cover_keys                            text[]
)
AS
$$
BEGIN
  DROP TABLE IF EXISTS _get_protocol_contracts_metadata_result CASCADE;
  CREATE TEMPORARY TABLE _get_protocol_contracts_metadata_result
  (
    chain_id                              uint256,
    network                               text,
    contracts                             jsonb,
    pods                                  jsonb,
    cx_tokens                             jsonb,
    cover_keys                            text[]
  ) ON COMMIT DROP;
  
  INSERT INTO _get_protocol_contracts_metadata_result(chain_id, contracts)
  SELECT all_contracts.chain_id, jsonb_agg(json_build_object('key', all_contracts.contract_name, 'value', all_contracts.contract_address))
  FROM get_protocol_contracts() AS all_contracts
  WHERE all_contracts.namespace NOT IN ('cns:cover:vault')
  AND all_contracts.chain_id = _chain_id
  GROUP BY all_contracts.chain_id;
  
  WITH all_pods
  AS
  (
    SELECT
      factory.vault_deployed.chain_id,
      jsonb_agg(json_build_object('key', factory.vault_deployed.cover_key, 'value', factory.vault_deployed.vault)) AS pods
    FROM factory.vault_deployed
    GROUP BY factory.vault_deployed.chain_id
  )
  UPDATE _get_protocol_contracts_metadata_result
  SET pods = all_pods.pods
  FROM all_pods
  WHERE all_pods.chain_id = _get_protocol_contracts_metadata_result.chain_id;
  
  
  WITH all_cx_tokens
  AS
  (
    SELECT
      factory.cx_token_deployed.chain_id,
      jsonb_agg
      (
        json_build_object(
          'coverKey',
          factory.cx_token_deployed.cover_key,
          'expiry',
          factory.cx_token_deployed.expiry_date,
          'productKey',
          factory.cx_token_deployed.product_key,
          'value',
          factory.cx_token_deployed.cx_token
        )
      ) AS cx_tokens
    FROM factory.cx_token_deployed
    GROUP BY factory.cx_token_deployed.chain_id
  )
  UPDATE _get_protocol_contracts_metadata_result
  SET cx_tokens = all_cx_tokens.cx_tokens
  FROM all_cx_tokens
  WHERE all_cx_tokens.chain_id = _get_protocol_contracts_metadata_result.chain_id;

  UPDATE _get_protocol_contracts_metadata_result
  SET cover_keys =
  (
    SELECT ARRAY_AGG(DISTINCT factory.cx_token_deployed.cover_key)
    FROM factory.cx_token_deployed
  );

  UPDATE _get_protocol_contracts_metadata_result
  SET network = config_blockchain_network_view.network_name
  FROM config_blockchain_network_view
  WHERE config_blockchain_network_view.chain_id = _get_protocol_contracts_metadata_result.chain_id;
  
  UPDATE _get_protocol_contracts_metadata_result
  SET cx_tokens = '[]'::jsonb
  WHERE _get_protocol_contracts_metadata_result.cx_tokens IS NULL;
  
  UPDATE _get_protocol_contracts_metadata_result
  SET cover_keys = '{}'
  WHERE _get_protocol_contracts_metadata_result.cover_keys IS NULL;

  RETURN QUERY
  SELECT * FROM _get_protocol_contracts_metadata_result;
END
$$
LANGUAGE plpgsql;

--SELECT * FROM get_protocol_contracts_metadata(1);


select * from get_protocol_contracts_metadata(84531)

