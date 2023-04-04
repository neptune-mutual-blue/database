DROP VIEW IF EXISTS votes_view;

CREATE VIEW votes_view
AS
WITH vote_txs
AS
(
  SELECT
    chain_id,
    cover_key,
    product_key,
    incident_date,
    block_timestamp,
    transaction_hash,
    witness,
    stake,
    'attested'                                AS tx_type
  FROM consensus.attested
  UNION ALL
  SELECT
    chain_id,
    cover_key,
    product_key,
    incident_date,
    block_timestamp,
    transaction_hash,
    witness,
    stake,
    'refuted'                                 AS tx_type
  FROM consensus.refuted
)
SELECT
  *,
  bytes32_to_string(cover_key)                AS cover_key_string,
  bytes32_to_string(product_key)              AS product_key_string
FROM vote_txs;
