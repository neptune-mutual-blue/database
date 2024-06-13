CREATE OR REPLACE FUNCTION get_incidents()
RETURNS TABLE
(
  chain_id                                                        uint256,
  cover_key                                                       bytes32,
  product_key                                                     bytes32,
  incident_date                                                   uint256,
  report_resolution_timestamp                                     uint256,
  reporter                                                        address,
  reporter_stake                                                  uint256,
  report_info                                                     text,
  report_timestamp                                                integer,
  report_transaction_hash                                         text,
  disputer                                                        address,
  disputer_stake                                                  uint256,
  dispute_info                                                    text,
  dispute_timestamp                                               integer,
  dispute_transaction_hash                                        text,
  resolved                                                        boolean,
  resolution_transaction_hash                                     text,
  resolution_decision                                             boolean,
  resolution_timestamp                                            integer,
  resolution_deadline                                             uint256,
  emergency_resolved                                              boolean,
  finalized                                                       boolean,
  finalize_transaction_hash                                       text,
  claim_begins_from                                               uint256,
  claim_expires_at                                                uint256,
  attestation_count                                               integer,
  refutation_count                                                integer,
  total_attestation_stake                                         uint256,
  total_refutation_stake                                          uint256
)
AS
$$
BEGIN
  CREATE TEMPORARY TABLE _get_incidents_result
  (
    chain_id                                                      uint256,
    cover_key                                                     bytes32,
    product_key                                                   bytes32,
    incident_date                                                 uint256,
    report_resolution_timestamp                                   uint256,
    reporter                                                      address,
    reporter_stake                                                uint256 NOT NULL DEFAULT(0),
    report_info                                                   text,
    report_timestamp                                              integer,
    report_transaction_hash                                       text,
    disputer                                                      address,
    disputer_stake                                                uint256 NOT NULL DEFAULT(0),
    dispute_info                                                  text,
    dispute_timestamp                                             integer,
    dispute_transaction_hash                                      text,
    resolved                                                      boolean NOT NULL DEFAULT(FALSE),
    resolution_transaction_hash                                   text,
    resolution_decision                                           boolean,
    resolution_timestamp                                          integer,
    resolution_deadline                                           uint256,
    emergency_resolved                                            boolean NOT NULL DEFAULT(FALSE),
    finalized                                                     boolean NOT NULL DEFAULT(FALSE),
    finalize_transaction_hash                                     text,
    claim_begins_from                                             uint256,
    claim_expires_at                                              uint256,
    attestation_count                                             integer,
    refutation_count                                              integer,
    total_attestation_stake                                       uint256 NOT NULL DEFAULT(0),
    total_refutation_stake                                        uint256 NOT NULL DEFAULT(0)
  ) ON COMMIT DROP;

  INSERT INTO _get_incidents_result
  (
    chain_id,
    cover_key,
    product_key,
    incident_date,
    reporter,
    reporter_stake,
    report_info,
    report_timestamp,
    report_resolution_timestamp,
    report_transaction_hash
  )
  SELECT
    consensus.reported.chain_id,
    consensus.reported.cover_key,
    consensus.reported.product_key,
    consensus.reported.incident_date,
    consensus.reported.reporter,
    get_npm_value(consensus.reported.initial_stake),
    consensus.reported.info,
    consensus.reported.block_timestamp,
    consensus.reported.resolution_timestamp,
    consensus.reported.transaction_hash
  FROM consensus.reported;

  UPDATE _get_incidents_result
  SET
    disputer                                                      = consensus.disputed.reporter,
    disputer_stake                                                = get_npm_value(consensus.disputed.initial_stake),
    dispute_info                                                  = consensus.disputed.info,
    dispute_timestamp                                             = consensus.disputed.block_timestamp,
    dispute_transaction_hash                                      = consensus.disputed.transaction_hash
  FROM consensus.disputed
  WHERE 1 = 1
  AND consensus.disputed.chain_id                                 = _get_incidents_result.chain_id
  AND consensus.disputed.cover_key                                = _get_incidents_result.cover_key
  AND consensus.disputed.product_key                              = _get_incidents_result.product_key
  AND consensus.disputed.incident_date                            = _get_incidents_result.incident_date;

  UPDATE _get_incidents_result
  SET
    (total_attestation_stake, attestation_count)  = (
      SELECT get_npm_value(COALESCE(SUM(stake), 0)), COUNT(*)
      FROM consensus.attested
      WHERE 1 = 1
      AND consensus.attested.chain_id                             = _get_incidents_result.chain_id
      AND consensus.attested.cover_key                            = _get_incidents_result.cover_key
      AND consensus.attested.product_key                          = _get_incidents_result.product_key
      AND consensus.attested.incident_date                        = _get_incidents_result.incident_date
    ),
    (total_refutation_stake, refutation_count)   = (
      SELECT get_npm_value(COALESCE(SUM(stake), 0)), COUNT(*)
      FROM consensus.refuted
      WHERE 1 = 1
      AND consensus.refuted.chain_id                              = _get_incidents_result.chain_id
      AND consensus.refuted.cover_key                             = _get_incidents_result.cover_key
      AND consensus.refuted.product_key                           = _get_incidents_result.product_key
      AND consensus.refuted.incident_date                         = _get_incidents_result.incident_date
    );

  WITH finalization
  AS
  (
    SELECT
      consensus.finalized.chain_id,
      consensus.finalized.cover_key,
      consensus.finalized.product_key,
      consensus.finalized.incident_date,
      consensus.finalized.transaction_hash
    FROM consensus.finalized
    ORDER BY consensus.finalized.block_timestamp DESC
    LIMIT 1
  )
  UPDATE _get_incidents_result
  SET
    finalized = TRUE,
    finalize_transaction_hash = finalization.transaction_hash
  FROM finalization
  WHERE 1 = 1
  AND finalization.chain_id                                       = _get_incidents_result.chain_id
  AND finalization.cover_key                                      = _get_incidents_result.cover_key
  AND finalization.product_key                                    = _get_incidents_result.product_key
  AND finalization.incident_date                                  = _get_incidents_result.incident_date;

  WITH latest_resolution
  AS
  (
    SELECT
      consensus.resolved.chain_id,
      consensus.resolved.cover_key,
      consensus.resolved.product_key,
      consensus.resolved.incident_date,
      consensus.resolved.emergency,
      consensus.resolved.decision,
      consensus.resolved.transaction_hash,
      consensus.resolved.block_timestamp,
      consensus.resolved.resolution_deadline,
      consensus.resolved.claim_begins_from,
      consensus.resolved.claim_expires_at
    FROM consensus.resolved
    ORDER BY consensus.resolved.block_timestamp DESC
    LIMIT 1
  )
  UPDATE _get_incidents_result
  SET
    resolved                                                      = TRUE,
    emergency_resolved                                            = latest_resolution.emergency,
    resolution_decision                                           = latest_resolution.decision,
    resolution_transaction_hash                                   = latest_resolution.transaction_hash,
    resolution_timestamp                                          = latest_resolution.block_timestamp,
    resolution_deadline                                           = latest_resolution.resolution_deadline,
    claim_begins_from                                             = latest_resolution.claim_begins_from,
    claim_expires_at                                              = latest_resolution.claim_expires_at
  FROM latest_resolution
  WHERE 1 = 1
  AND latest_resolution.chain_id                                  = _get_incidents_result.chain_id
  AND latest_resolution.cover_key                                 = _get_incidents_result.cover_key
  AND latest_resolution.product_key                               = _get_incidents_result.product_key
  AND latest_resolution.incident_date                             = _get_incidents_result.incident_date;

  RETURN QUERY
  SELECT * FROM _get_incidents_result
  ORDER BY incident_date DESC;
END
$$
LANGUAGE plpgsql;

-- SELECT * FROM get_incidents();

ALTER FUNCTION get_incidents OWNER TO writeuser;
