DROP FUNCTION IF EXISTS get_product_summary(_account address);

CREATE FUNCTION get_product_summary(_account address DEFAULT '')
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
  claim_platform_fee                    integer,
  is_user_whitelisted                   boolean
)
AS
$$
BEGIN
  CREATE TEMPORARY TABLE _get_product_summary_result
  (
    chain_id                            numeric,
    cover_key                           bytes32,
    cover_key_string                    text,
    cover_info                          text,
    cover_info_details                  text,
    product_key                         bytes32,
    product_key_string                  text,
    product_info                        text,
    product_info_details                text,
    product_status_enum                 product_status_type,
    product_status                      integer,
    floor                               numeric DEFAULT(0),
    ceiling                             numeric DEFAULT(0),
    leverage                            numeric DEFAULT(0),
    capital_efficiency                  numeric DEFAULT(0),
    capacity                            numeric DEFAULT(0),
    commitment                          numeric DEFAULT(0),
    available_for_underwriting          numeric DEFAULT(0),
    utilization_ratio                   numeric,
    reassurance                         numeric DEFAULT(0),
    tvl                                 numeric DEFAULT(0),
    coverage_lag                        numeric DEFAULT(0),
    supports_products                   boolean DEFAULT(false),
    requires_whitelist                  boolean DEFAULT(false),
    min_reporting_stake                 numeric,
    active_incident_date                integer,
    reporter_commission                 integer,
    reporting_period                    integer,
    claim_platform_fee                  integer,
    is_user_whitelisted                 boolean
  ) ON COMMIT DROP;
  
  INSERT INTO _get_product_summary_result(chain_id, cover_key, cover_key_string, product_key, product_key_string, capital_efficiency)
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
  
  INSERT INTO _get_product_summary_result(chain_id, cover_key, cover_key_string, leverage, capital_efficiency)
  SELECT
    cover.cover_created.chain_id,
    cover.cover_created.cover_key,
    bytes32_to_string(cover.cover_created.cover_key),
    1 AS leverage,
    10000 AS capital_efficiency
  FROM cover.cover_created;

  UPDATE _get_product_summary_result
  SET supports_products           = is_diversified(_get_product_summary_result.chain_id, _get_product_summary_result.cover_key)
  WHERE _get_product_summary_result.product_key IS NULL;

  UPDATE _get_product_summary_result
  SET
    leverage                      = config_cover_view.leverage,
    floor                         = config_cover_view.policy_floor,
    ceiling                       = config_cover_view.policy_ceiling
  FROM config_cover_view
  WHERE config_cover_view.chain_id = _get_product_summary_result.chain_id
  AND config_cover_view.cover_key = _get_product_summary_result.cover_key;
  
  UPDATE _get_product_summary_result
  SET 
    capacity                      = get_cover_capacity_till(_get_product_summary_result.chain_id, _get_product_summary_result.cover_key, _get_product_summary_result.product_key, 'infinity'),
    commitment                    = CASE 
                                    WHEN _get_product_summary_result.supports_products 
                                    THEN get_sum_commitment(_get_product_summary_result.chain_id, _get_product_summary_result.cover_key)
                                    ELSE get_commitment(_get_product_summary_result.chain_id, _get_product_summary_result.cover_key, _get_product_summary_result.product_key)
                                    END,
    reporting_period              = get_reporting_period(_get_product_summary_result.chain_id, _get_product_summary_result.cover_key),
    requires_whitelist            = check_if_requires_whitelist(_get_product_summary_result.chain_id, _get_product_summary_result.cover_key),
    product_status_enum           = get_active_product_status(_get_product_summary_result.chain_id, _get_product_summary_result.cover_key,  _get_product_summary_result.product_key),
    active_incident_date          = get_active_incident_date(_get_product_summary_result.chain_id, _get_product_summary_result.cover_key,  _get_product_summary_result.product_key),
    min_reporting_stake           = get_min_first_reporting_stake(_get_product_summary_result.chain_id, _get_product_summary_result.cover_key),
    coverage_lag                  = get_coverage_lag(_get_product_summary_result.chain_id, _get_product_summary_result.cover_key),
    reporter_commission           = get_reporter_commission(_get_product_summary_result.chain_id),
    claim_platform_fee            = get_claim_platform_fee(_get_product_summary_result.chain_id),
    reassurance                   = get_reassurance_till_date(_get_product_summary_result.chain_id, _get_product_summary_result.cover_key, 'infinity'),
    is_user_whitelisted           = check_if_user_whitelisted(_get_product_summary_result.chain_id, _get_product_summary_result.cover_key, _get_product_summary_result.product_key, _account),
    tvl                           = get_tvl_till_date(_get_product_summary_result.chain_id, _get_product_summary_result.cover_key, 'infinity'),
    product_info                  = (SELECT p.product_info FROM get_product_info(_get_product_summary_result.chain_id, _get_product_summary_result.cover_key,  _get_product_summary_result.product_key) AS p),
    product_info_details          = (SELECT p.product_info_details FROM get_product_info(_get_product_summary_result.chain_id, _get_product_summary_result.cover_key,  _get_product_summary_result.product_key) AS p),
    cover_info                    = (SELECT c.cover_info FROM get_cover_info(_get_product_summary_result.chain_id, _get_product_summary_result.cover_key) AS c),
    cover_info_details            = (SELECT c.cover_info_details FROM get_cover_info(_get_product_summary_result.chain_id, _get_product_summary_result.cover_key) AS c);

  UPDATE _get_product_summary_result
  SET
    available_for_underwriting    = _get_product_summary_result.capacity - _get_product_summary_result.commitment,
    utilization_ratio             = CASE WHEN _get_product_summary_result.capacity = 0 THEN 0 ELSE _get_product_summary_result.commitment / _get_product_summary_result.capacity END,
    product_status                = array_length(enum_range(NULL, _get_product_summary_result.product_status_enum), 1) - 1;

  RETURN QUERY
  SELECT * FROM _get_product_summary_result;
END
$$
LANGUAGE plpgsql;

--SELECT * FROM get_product_summary();


