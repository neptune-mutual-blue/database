CREATE OR REPLACE FUNCTION get_product_summary()
RETURNS TABLE
(
  chain_id                              numeric,
  cover_key                             bytes32,
  cover_key_string                      text,
  cover_info                            text,
  cover_info_details                    text,
  product_key                           bytes32,
  product_key_string                    text,
  product_info                          text,
  product_info_details                  text,
  product_status_enum                   product_status_type,
  product_status                        integer,
  floor                                 numeric,
  ceiling                               numeric,
  leverage                              numeric,
  capital_efficiency                    numeric,
  capacity                              numeric,
  commitment                            numeric,
  available_for_underwriting            numeric,
  utilization_ratio                     numeric,
  reassurance                           numeric,
  tvl                                   numeric,
  coverage_lag                          numeric,
  supports_products                     boolean,
  requires_whitelist                    boolean,
  min_reporting_stake                   numeric,
  active_incident_date                  integer,
  reporter_commission                   integer,
  reporting_period                      integer,
  claim_platform_fee                    integer
)
AS
$$
BEGIN
  CREATE TEMPORARY TABLE _get_product_summary_result
  (
    chain_id                          numeric,
    cover_key                         bytes32,
    cover_key_string                  text,
    cover_info                        text,
    cover_info_details                text,
    product_key                       bytes32,
    product_key_string                text,
    product_info                      text,
    product_info_details              text,
    product_status_enum               product_status_type,
    product_status                    integer,
    floor                             numeric DEFAULT(0),
    ceiling                           numeric DEFAULT(0),
    leverage                          numeric DEFAULT(0),
    capital_efficiency                numeric DEFAULT(0),
    capacity                          numeric DEFAULT(0),
    commitment                        numeric DEFAULT(0),
    available_for_underwriting        numeric DEFAULT(0),
    utilization_ratio                 numeric,
    reassurance                       numeric DEFAULT(0),
    tvl                               numeric DEFAULT(0),
    coverage_lag                      numeric DEFAULT(0),
    supports_products                 boolean DEFAULT(false),
    requires_whitelist                boolean DEFAULT(false),
    min_reporting_stake               numeric,
    active_incident_date              integer,
    reporter_commission               integer,
    reporting_period                  integer,
    claim_platform_fee                integer
  ) ON COMMIT DROP;
  
  INSERT INTO _get_product_summary_result
  (
    chain_id,
    cover_key,
    cover_key_string,
    product_key,
    product_key_string,
    capital_efficiency
  )
  SELECT
    config_product_view.chain_id,
    config_product_view.cover_key,
    bytes32_to_string(config_product_view.cover_key),
    config_product_view.product_key,
    bytes32_to_string(config_product_view.product_key),
    config_product_view.capital_efficiency
  FROM config_product_view
  WHERE config_product_view.chain_id IN
  (
    SELECT DISTINCT core.transactions.chain_id
    FROM core.transactions
  );

  UPDATE _get_product_summary_result
  SET requires_whitelist = 
  (
    SELECT cover.cover_created.requires_whitelist
    FROM cover.cover_created
    WHERE cover.cover_created.chain_id = _get_product_summary_result.chain_id
    AND cover.cover_created.cover_key = _get_product_summary_result.cover_key
  );

  UPDATE _get_product_summary_result
  SET reporting_period = 
  (
    SELECT config_cover_view.reporting_period
    FROM config_cover_view
    WHERE config_cover_view.chain_id = _get_product_summary_result.chain_id
    AND config_cover_view.cover_key = _get_product_summary_result.cover_key
    LIMIT 1
  );
  
  UPDATE _get_product_summary_result
  SET leverage = config_cover_view.leverage
  FROM config_cover_view
  WHERE config_cover_view.chain_id = _get_product_summary_result.chain_id
  AND config_cover_view.cover_key = _get_product_summary_result.cover_key;
  
  INSERT INTO _get_product_summary_result(chain_id, cover_key, cover_key_string, leverage, capital_efficiency)
  SELECT
    cover.cover_created.chain_id,
    cover.cover_created.cover_key,
    bytes32_to_string(cover.cover_created.cover_key),
    1 AS leverage,
    100 AS capital_efficiency
  FROM cover.cover_created;

  UPDATE _get_product_summary_result
  SET product_key = string_to_bytes32('')
  WHERE _get_product_summary_result.product_key IS NULL;

  UPDATE _get_product_summary_result
  SET
    floor = config_cover_view.policy_floor,
    ceiling = config_cover_view.policy_ceiling
  FROM config_cover_view
  WHERE config_cover_view.chain_id = _get_product_summary_result.chain_id
  AND config_cover_view.cover_key = _get_product_summary_result.cover_key;

  UPDATE _get_product_summary_result
  SET product_status_enum = get_active_product_status(_get_product_summary_result.chain_id, _get_product_summary_result.cover_key,  _get_product_summary_result.product_key);

  UPDATE _get_product_summary_result
  SET active_incident_date = get_active_incident_date(_get_product_summary_result.chain_id, _get_product_summary_result.cover_key,  _get_product_summary_result.product_key);

  UPDATE _get_product_summary_result
  SET min_reporting_stake = get_min_first_reporting_stake(_get_product_summary_result.chain_id, _get_product_summary_result.cover_key);

  UPDATE _get_product_summary_result
  SET coverage_lag = get_coverage_lag(_get_product_summary_result.chain_id, _get_product_summary_result.cover_key);

  UPDATE _get_product_summary_result
  SET reporter_commission = get_reporter_commission(_get_product_summary_result.chain_id);

  UPDATE _get_product_summary_result
  SET claim_platform_fee = get_claim_platform_fee(_get_product_summary_result.chain_id);

  UPDATE _get_product_summary_result
  SET capacity = capacity_view.capacity
  FROM capacity_view
  WHERE capacity_view.chain_id = _get_product_summary_result.chain_id
  AND capacity_view.cover_key = _get_product_summary_result.cover_key
  AND capacity_view.product_key = _get_product_summary_result.product_key;

  UPDATE _get_product_summary_result
  SET commitment = product_commitment_view.commitment
  FROM product_commitment_view
  WHERE product_commitment_view.chain_id = _get_product_summary_result.chain_id
  AND product_commitment_view.cover_key = _get_product_summary_result.cover_key
  AND product_commitment_view.product_key = _get_product_summary_result.product_key;

  UPDATE _get_product_summary_result
  SET commitment = cover_commitment_view.commitment
  FROM cover_commitment_view
  WHERE cover_commitment_view.chain_id = _get_product_summary_result.chain_id
  AND cover_commitment_view.cover_key = _get_product_summary_result.cover_key
  AND _get_product_summary_result.product_key = string_to_bytes32('');

  UPDATE _get_product_summary_result
  SET commitment = cover_commitment_view.commitment
  FROM cover_commitment_view
  WHERE cover_commitment_view.chain_id = _get_product_summary_result.chain_id
  AND cover_commitment_view.cover_key = _get_product_summary_result.cover_key
  AND _get_product_summary_result.product_key IS NULL;

  UPDATE _get_product_summary_result
  SET 
    available_for_underwriting = _get_product_summary_result.capacity - _get_product_summary_result.commitment,
    product_status = array_length(enum_range(NULL, _get_product_summary_result.product_status_enum), 1) - 1;
  
  UPDATE _get_product_summary_result
  SET reassurance = get_reassurance_till_date(_get_product_summary_result.chain_id, _get_product_summary_result.cover_key, 'infinity');
  
  UPDATE _get_product_summary_result
  SET tvl = get_tvl_till_date(_get_product_summary_result.chain_id, _get_product_summary_result.cover_key, 'infinity');
  
  UPDATE _get_product_summary_result
  SET utilization_ratio = _get_product_summary_result.commitment / _get_product_summary_result.capacity;

  UPDATE _get_product_summary_result
  SET cover_info = cover.cover_created.info
  FROM cover.cover_created
  WHERE cover.cover_created.cover_key = _get_product_summary_result.cover_key
  AND cover.cover_created.chain_id = _get_product_summary_result.chain_id;

  UPDATE _get_product_summary_result
  SET product_info = cover.product_created.info
  FROM cover.product_created
  WHERE cover.product_created.cover_key = _get_product_summary_result.cover_key
  AND cover.product_created.product_key = _get_product_summary_result.product_key
  AND cover.product_created.chain_id = _get_product_summary_result.chain_id;
 
  UPDATE _get_product_summary_result
  SET product_info_details = config_known_ipfs_hashes_view.ipfs_details
  FROM config_known_ipfs_hashes_view
  WHERE config_known_ipfs_hashes_view.ipfs_hash = _get_product_summary_result.product_info;

  UPDATE _get_product_summary_result
  SET cover_info_details = config_known_ipfs_hashes_view.ipfs_details
  FROM config_known_ipfs_hashes_view
  WHERE config_known_ipfs_hashes_view.ipfs_hash = _get_product_summary_result.cover_info;

  UPDATE _get_product_summary_result
  SET product_key = NULL
  WHERE _get_product_summary_result.product_key = string_to_bytes32('');
  
  UPDATE _get_product_summary_result
  SET supports_products = is_diversified(_get_product_summary_result.chain_id, _get_product_summary_result.cover_key)
  WHERE _get_product_summary_result.product_key IS NULL;

  RETURN QUERY
  SELECT * FROM _get_product_summary_result;
END
$$
LANGUAGE plpgsql;

--SELECT * FROM get_product_summary()
