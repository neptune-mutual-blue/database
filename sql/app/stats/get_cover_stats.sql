DROP FUNCTION IF EXISTS get_cover_stats
(
  _chain_id                               uint256,
  _cover_key                              bytes32,
  _product_key                            bytes32,
  _account                                address
) CASCADE;

CREATE FUNCTION get_cover_stats
(
  _chain_id                               uint256,
  _cover_key                              bytes32,
  _product_key                            bytes32,
  _account                                address
)
RETURNS TABLE
(
  cover_key                               bytes32,
  cover_key_string                        text,
  product_key                             bytes32,
  product_key_string                      text,
  tvl                                     numeric,
  active_commitment                       numeric,
  available_for_underwriting              numeric,
  capacity                                numeric,
  coverage_lag                            numeric,
  policy_rate_floor                       integer,
  policy_rate_ceiling                     integer,
  reporter_commission                     integer,
  claim_platform_fee                      integer,
  reporting_period                        integer,
  product_status_enum                     product_status_type,
  product_status                          integer,
  min_reporting_stake                     numeric,
  active_incident_date                    integer,
  requires_whitelist                      boolean,
  is_user_whitelisted                     boolean
)
AS
$$
BEGIN
  IF(_product_key IS NULL) THEN
    _product_key := string_to_bytes32('');
  END IF;

  DROP TABLE IF EXISTS _get_cover_stats_result CASCADE;
  CREATE TEMPORARY TABLE _get_cover_stats_result
  (
    cover_key                               bytes32,
    cover_key_string                        text,
    product_key                             bytes32,
    product_key_string                      text,
    tvl                                     numeric,
    active_commitment                       numeric DEFAULT 0,
    available_for_underwriting              numeric,
    capacity                                numeric,
    coverage_lag                            numeric,
    policy_rate_floor                       integer,
    policy_rate_ceiling                     integer,
    reporter_commission                     integer,
    claim_platform_fee                      integer,
    reporting_period                        integer,
    product_status_enum                     product_status_type,
    product_status                          integer,
    min_reporting_stake                     numeric,
    active_incident_date                    integer,
    requires_whitelist                      boolean,
    is_user_whitelisted                     boolean
  ) ON COMMIT DROP;
  
  INSERT INTO _get_cover_stats_result
  (
    cover_key,
    cover_key_string,
    product_key,
    product_key_string,
    tvl,
    capacity,
    coverage_lag,
    policy_rate_floor,
    policy_rate_ceiling,
    reporter_commission,
    claim_platform_fee,
    product_status_enum,
    min_reporting_stake,
    active_incident_date,
    is_user_whitelisted
  )
  SELECT
    _cover_key,
    bytes32_to_string(_cover_key),
    _product_key,
    bytes32_to_string(_product_key),
    get_tvl_till_date(_chain_id, _cover_key, 'infinity'),
    get_cover_capacity_till(_chain_id, _cover_key, _product_key, 'infinity'),
    get_coverage_lag(_chain_id, _cover_key),
    get_policy_floor(_chain_id, _cover_key),
    get_policy_ceiling(_chain_id, _cover_key),
    get_reporter_commission(_chain_id),
    get_claim_platform_fee(_chain_id),
    get_active_product_status(_chain_id, _cover_key, _product_key),
    get_min_first_reporting_stake(_chain_id, _cover_key),
    get_active_incident_date(_chain_id, _cover_key, _product_key),
    check_if_user_whitelisted(_chain_id, _cover_key, _product_key, _account);
  
  UPDATE _get_cover_stats_result
  SET active_commitment = product_commitment_view.commitment
  FROM product_commitment_view
  WHERE product_commitment_view.chain_id = _chain_id
  AND product_commitment_view.cover_key = _cover_key
  AND product_commitment_view.product_key = _product_key;
  
  
  UPDATE _get_cover_stats_result
  SET requires_whitelist = 
  (
    SELECT cover.cover_created.requires_whitelist
    FROM cover.cover_created
    WHERE cover.cover_created.chain_id = _chain_id
    AND cover.cover_created.cover_key = _cover_key
  );
  
  UPDATE _get_cover_stats_result
  SET 
    available_for_underwriting = _get_cover_stats_result.capacity - _get_cover_stats_result.active_commitment,
    product_status = array_length(enum_range(NULL, _get_cover_stats_result.product_status_enum), 1) - 1;

  UPDATE _get_cover_stats_result
  SET reporting_period = 
  (
    SELECT config_cover_view.reporting_period
    FROM config_cover_view
    WHERE config_cover_view.chain_id = _chain_id
    AND config_cover_view.cover_key = _cover_key
    LIMIT 1
  );

  RETURN QUERY
  SELECT * FROM _get_cover_stats_result;
END
$$
LANGUAGE plpgsql;

--SELECT * FROM get_cover_stats(43113,'0x7072696d65000000000000000000000000000000000000000000000000000000', '0x0000000000000000000000000000000000000000000000000000000000000000', '0x0000000000000000000000000000000000000001');
