CREATE OR REPLACE FUNCTION get_npm(_chain_id numeric)
RETURNS text
STABLE
AS
$$
BEGIN
  RETURN npm_address
  FROM config_blockchain_network_view
  WHERE config_blockchain_network_view.chain_id = _chain_id;
END
$$
LANGUAGE plpgsql;