CREATE OR REPLACE FUNCTION get_user_milestones
(
  _account                        address
)
RETURNS TABLE
(
  total_policy_purchased          uint256,
  total_liquidity_added           uint256
)
STABLE
AS
$$ 
  DECLARE total_policy_purchased  uint256;
  DECLARE total_liquidity_added   uint256;
BEGIN
  SELECT
    SUM(get_stablecoin_value(chain_id, amount_to_cover))          INTO total_policy_purchased
  FROM policy.cover_purchased
  WHERE on_behalf_of              = _account;

  SELECT
    SUM(get_stablecoin_value(chain_id, liquidity_added))          INTO total_liquidity_added
  FROM vault.pods_issued
  WHERE account                   = _account;
  
  RETURN QUERY
  SELECT
    COALESCE(total_policy_purchased, 0::uint256),
    COALESCE(total_liquidity_added, 0::uint256);

END
$$
LANGUAGE plpgsql;

-- SELECT * FROM get_user_milestones('0x201bcc0d375f10543e585fbb883b36c715c959b3')