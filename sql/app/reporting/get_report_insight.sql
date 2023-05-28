DROP FUNCTION IF EXISTS get_report_insight
(
  _chain_id                                       uint256,
  _cover_key                                      bytes32,
  _product_key                                    bytes32,
  _incident_date                                  uint256
);

CREATE FUNCTION get_report_insight
(
  _chain_id                                       uint256,
  _cover_key                                      bytes32,
  _product_key                                    bytes32,
  _incident_date                                  uint256
)
RETURNS TABLE
(
  chain_id                                        uint256,
  cover_key                                       bytes32,
  product_key                                     bytes32,
  incident_date                                   uint256,
  report_resolution_timestamp                     uint256,
  report_transaction                              address,
  report_timestamp                                uint256,
  reporter                                        address,
  report_info                                     text,
  reporter_stake                                  uint256,
  dispute_transaction                             address,
  dispute_timestamp                               uint256,
  disputer                                        address,
  dispute_info                                    text,
  disputer_stake                                  uint256,
  total_attestation                               uint256,
  attestation_count                               integer,
  total_refutation                                uint256,
  refutation_count                                integer,
  resolved                                        boolean,
  resolution_transaction                          text,
  resolution_timestamp                            uint256,
  resolution_decision                             boolean,
  resolution_deadline                             uint256,
  emergency_resolved                              boolean,
  emergency_resolution_transaction                text,
  emergency_resolution_timestamp                  uint256,
  emergency_resolution_decision                   boolean,
  emergency_resolution_deadline                   uint256,
  finalized                                       boolean,
  status_enum                                     product_status_type,
  status                                          smallint,
  claim_begins_from                               uint256,
  claim_expires_at                                uint256
)
AS
$$
  DECLARE _total_attestation                      uint256;
  DECLARE _attestation_count                      integer;
  DECLARE _total_refutation                       uint256;
  DECLARE _refutation_count                       integer;
BEGIN
  DROP TABLE IF EXISTS _get_report_insight_result;
  
  CREATE TEMPORARY TABLE _get_report_insight_result
  (
    chain_id                                        uint256,
    cover_key                                       bytes32,
    product_key                                     bytes32,
    incident_date                                   uint256,
    report_resolution_timestamp                     uint256,
    report_transaction                              address,
    report_timestamp                                uint256,
    reporter                                        address,
    report_info                                     text,
    reporter_stake                                  uint256,
    dispute_transaction                             address,
    dispute_timestamp                               uint256,
    disputer                                        address,
    dispute_info                                    text,
    disputer_stake                                  uint256,
    total_attestation                               uint256,
    attestation_count                               integer,
    total_refutation                                uint256,
    refutation_count                                integer,
    resolved                                        boolean,
    resolution_transaction                          text,
    resolution_timestamp                            uint256,
    resolution_decision                             boolean,
    resolution_deadline                             uint256,
    emergency_resolved                              boolean,
    emergency_resolution_transaction                text,
    emergency_resolution_timestamp                  uint256,
    emergency_resolution_decision                   boolean,
    emergency_resolution_deadline                   uint256,
    finalized                                       boolean,
    status_enum                                     product_status_type,
    status                                          smallint,
    claim_begins_from                               uint256,
    claim_expires_at                                uint256
  ) ON COMMIT DROP;

  INSERT INTO _get_report_insight_result(chain_id, cover_key, product_key, incident_date, report_resolution_timestamp, report_transaction, report_timestamp, reporter, report_info, reporter_stake, status_enum)
  SELECT
    consensus.reported.chain_id,
    consensus.reported.cover_key,
    consensus.reported.product_key,
    consensus.reported.incident_date,
    consensus.reported.resolution_timestamp,
    consensus.reported.transaction_hash,
    consensus.reported.block_timestamp,
    consensus.reported.reporter,
    consensus.reported.info,
    consensus.reported.initial_stake,
    get_product_status(_chain_id, _cover_key, _product_key, _incident_date)
  FROM consensus.reported
  WHERE consensus.reported.chain_id     = _chain_id
  AND consensus.reported.cover_key      = _cover_key
  AND consensus.reported.product_key    = _product_key
  AND consensus.reported.incident_date  = _incident_date;

  UPDATE _get_report_insight_result
  SET
    dispute_transaction   = consensus.disputed.transaction_hash,
    dispute_timestamp     = consensus.disputed.block_timestamp,
    disputer              = consensus.disputed.reporter,
    dispute_info          = consensus.disputed.info,
    disputer_stake        = consensus.disputed.initial_stake
  FROM consensus.disputed
  WHERE consensus.disputed.chain_id     = _get_report_insight_result.chain_id
  AND consensus.disputed.cover_key      = _get_report_insight_result.cover_key
  AND consensus.disputed.product_key    = _get_report_insight_result.product_key
  AND consensus.disputed.incident_date  = _get_report_insight_result.incident_date;
  
  SELECT COUNT(*), SUM(consensus.attested.stake)
  INTO _attestation_count, _total_attestation
  FROM consensus.attested
  WHERE consensus.attested.chain_id     = _chain_id
  AND consensus.attested.cover_key      = _cover_key
  AND consensus.attested.product_key    = _product_key
  AND consensus.attested.incident_date  = _incident_date;

  SELECT COUNT(*), SUM(consensus.refuted.stake)
  INTO _refutation_count, _total_refutation
  FROM consensus.refuted
  WHERE consensus.refuted.chain_id      = _chain_id
  AND consensus.refuted.cover_key       = _cover_key
  AND consensus.refuted.product_key     = _product_key
  AND consensus.refuted.incident_date   = _incident_date;

  UPDATE _get_report_insight_result
  SET
    total_attestation   = _total_attestation,
    attestation_count   = _attestation_count,
    total_refutation    = _total_refutation,
    refutation_count    = _refutation_count,
    status              = array_length(enum_range(NULL, _get_report_insight_result.status_enum), 1) - 1;


  WITH resolution
  AS
  (
    SELECT
      consensus.resolved.chain_id,
      consensus.resolved.cover_key,
      consensus.resolved.product_key,
      consensus.resolved.incident_date,
      true                                    AS resolved,
      consensus.resolved.transaction_hash     AS resolution_transaction,
      consensus.resolved.block_timestamp      AS resolution_timestamp,
      consensus.resolved.decision             AS resolution_decision, 
      consensus.resolved.resolution_deadline,
      consensus.resolved.claim_begins_from,
      consensus.resolved.claim_expires_at
    FROM consensus.resolved
    WHERE consensus.resolved.chain_id     = _chain_id
    AND consensus.resolved.cover_key      = _cover_key
    AND consensus.resolved.product_key    = _product_key
    AND consensus.resolved.incident_date  = _incident_date
  )
  UPDATE _get_report_insight_result
  SET
    resolved                              = resolution.resolved,
    resolution_transaction                = resolution.resolution_transaction,
    resolution_timestamp                  = resolution.resolution_timestamp,
    resolution_decision                   = resolution.resolution_decision,
    resolution_deadline                   = resolution.resolution_deadline,
    claim_begins_from                     = resolution.claim_begins_from,
    claim_expires_at                      = resolution.claim_expires_at
  FROM resolution
  WHERE resolution.chain_id               = _get_report_insight_result.chain_id
  AND resolution.cover_key                = _get_report_insight_result.cover_key
  AND resolution.product_key              = _get_report_insight_result.product_key
  AND resolution.incident_date            = _get_report_insight_result.incident_date;



  WITH emergency_resolution
  AS
  (
    SELECT
      consensus.resolved.chain_id,
      consensus.resolved.cover_key,
      consensus.resolved.product_key,
      consensus.resolved.incident_date,
      true AS resolved,
      consensus.resolved.transaction_hash     AS resolution_transaction,
      consensus.resolved.block_timestamp      AS resolution_timestamp,
      consensus.resolved.decision             AS resolution_decision, 
      consensus.resolved.resolution_deadline,
      consensus.resolved.claim_begins_from,
      consensus.resolved.claim_expires_at
    FROM consensus.resolved
    WHERE consensus.resolved.chain_id     = _chain_id
    AND consensus.resolved.cover_key      = _cover_key
    AND consensus.resolved.product_key    = _product_key
    AND consensus.resolved.incident_date  = _incident_date
    AND consensus.resolved.emergency      = true
    ORDER BY consensus.resolved.block_timestamp DESC
  )
  UPDATE _get_report_insight_result
  SET
    emergency_resolved                    = emergency_resolution.resolved,
    emergency_resolution_transaction      = emergency_resolution.resolution_transaction,
    emergency_resolution_timestamp        = emergency_resolution.resolution_timestamp,
    emergency_resolution_decision         = emergency_resolution.resolution_decision,
    emergency_resolution_deadline         = emergency_resolution.resolution_deadline,
    claim_begins_from                     = emergency_resolution.claim_begins_from,
    claim_expires_at                      = emergency_resolution.claim_expires_at
  FROM emergency_resolution
  WHERE emergency_resolution.chain_id     = _get_report_insight_result.chain_id
  AND emergency_resolution.cover_key      = _get_report_insight_result.cover_key
  AND emergency_resolution.product_key    = _get_report_insight_result.product_key
  AND emergency_resolution.incident_date  = _get_report_insight_result.incident_date;

  UPDATE _get_report_insight_result
  SET finalized = true
  WHERE EXISTS
  (
    SELECT 1
    FROM consensus.finalized
    WHERE consensus.finalized.chain_id    = _chain_id
    AND consensus.finalized.cover_key     = _cover_key
    AND consensus.finalized.product_key   = _product_key
    AND consensus.finalized.incident_date = _incident_date
  );


  RETURN QUERY
  SELECT * FROM _get_report_insight_result;
END
$$
LANGUAGE plpgsql;


-- WITH resolved
-- AS
-- (
--   SELECT chain_id, cover_key, product_key, incident_date FROM consensus.resolved WHERE emergency ORDER BY chain_id, cover_key, product_key, incident_date DESC LIMIT 1
-- )

-- SELECT * FROM get_report_insight
-- (
--   (SELECT chain_id FROM resolved),
--   (SELECT cover_key FROM resolved),
--   (SELECT product_key FROM resolved),
--   (SELECT incident_date FROM resolved)
-- );

