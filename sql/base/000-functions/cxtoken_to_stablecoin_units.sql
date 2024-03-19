CREATE OR REPLACE FUNCTION cxtoken_to_stablecoin_units
(
  _chain_id                                         uint256,
  _amount_in_cxtoken                                uint256
)
RETURNS numeric
STABLE
AS
$$
  DECLARE _precision                                integer;
BEGIN
  SELECT config_blockchain_network_view.stablecoin_decimals
  INTO _precision
  FROM config_blockchain_network_view
  WHERE config_blockchain_network_view.chain_id = _chain_id;
  
  RETURN (_amount_in_cxtoken / POWER(10, 18)) * POWER(10, _precision);
END
$$
LANGUAGE plpgsql;


/********************************************/

DROP FUNCTION IF EXISTS cxtoken.claimed_amounts_trigger() CASCADE;

CREATE FUNCTION cxtoken.claimed_amounts_trigger()
RETURNS trigger
AS
$$
BEGIN
  NEW.transaction_stablecoin_amount = cxtoken_to_stablecoin_units(NEW.chain_id, NEW.amount);
  RETURN NEW;
END
$$
LANGUAGE plpgsql;

CREATE TRIGGER claimed_amounts_trigger
BEFORE INSERT OR UPDATE ON cxtoken.claimed
FOR EACH ROW EXECUTE FUNCTION cxtoken.claimed_amounts_trigger();
