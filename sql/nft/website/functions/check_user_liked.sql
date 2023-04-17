CREATE OR REPLACE FUNCTION check_user_liked
(
  _account                            address,
  _token_id                           uint256
)
RETURNS boolean
STABLE
AS
$$
DECLARE _result boolean;
BEGIN
  SELECT liked  INTO _result
  FROM likes
  WHERE token_id                      = _token_id
  AND liked_by                        = _account
  LIMIT 1;

  RETURN COALESCE(_result, false);
END
$$
LANGUAGE plpgsql;

-- SELECT * FROM check_user_liked(1, '0x')