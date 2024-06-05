DROP FUNCTION IF EXISTS get_votes_function(
  _chain_id                                   uint256,
  _cover_key                                  bytes32,
  _product_key                                bytes32,
  _incident_date                              uint256
) CASCADE;

CREATE FUNCTION get_votes_function(
  _chain_id                                   uint256,
  _cover_key                                  bytes32,
  _product_key                                bytes32,
  _incident_date                              uint256
)
RETURNS TABLE
AS
RETURN
(
  SELECT
    chain_id,
    cover_key,
    product_key,
    incident_date,
    block_timestamp,
    transaction_hash,
    transaction_sender,
    witness,
    stake,
    'attested' AS tx_type
  FROM consensus.attested
  WHERE chain_id = _chain_id AND cover_key = _cover_key AND product_key = _product_key AND incident_date = _incident_date
  UNION ALL
  SELECT
    chain_id,
    cover_key,
    product_key,
    incident_date,
    block_timestamp,
    transaction_hash,
    transaction_sender,
    witness,
    stake,
    'refuted' AS tx_type
  FROM consensus.refuted
  WHERE chain_id = _chain_id AND cover_key = _cover_key AND product_key = _product_key AND incident_date = _incident_date
);