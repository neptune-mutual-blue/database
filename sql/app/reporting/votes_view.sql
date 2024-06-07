CREATE OR REPLACE VIEW votes_view
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
    'Attested'                                    AS tx_type
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
    'Refuted'                                     AS tx_type
  FROM consensus.refuted
)
SELECT
  vote_txs.chain_id,
  vote_txs.cover_key,
  vote_txs.product_key,
  vote_txs.incident_date,
  vote_txs.block_timestamp,
  vote_txs.transaction_hash,
  vote_txs.witness,
  get_npm_value(vote_txs.stake)                   AS stake,
  vote_txs.tx_type,
  bytes32_to_string(vote_txs.cover_key)           AS cover_key_string,
  bytes32_to_string(vote_txs.product_key)         AS product_key_string
FROM vote_txs;

ALTER VIEW votes_view OWNER TO writeuser;
