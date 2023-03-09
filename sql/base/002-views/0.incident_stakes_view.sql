DROP VIEW IF EXISTS incident_stakes_view CASCADE;

CREATE VIEW incident_stakes_view
AS
SELECT
  'Attestation' AS activity,
  consensus.attested.chain_id,
  consensus.attested.cover_key,
  consensus.attested.product_key,
  consensus.attested.incident_date,  
  consensus.attested.witness,
  consensus.attested.stake
FROM consensus.attested
UNION ALL
SELECT
  'Refutation' AS activity,
  consensus.refuted.chain_id,
  consensus.refuted.cover_key,
  consensus.refuted.product_key,
  consensus.refuted.incident_date,  
  consensus.refuted.witness,
  consensus.refuted.stake
FROM consensus.refuted;


