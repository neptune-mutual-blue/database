CREATE OR REPLACE FUNCTION get_bound_token_id(_account address)
RETURNS uint256
STABLE
AS
$$
BEGIN
  RETURN token_id
  FROM nft.soul_bound
  WHERE transaction_sender = _account;
END
$$
LANGUAGE plpgsql;
