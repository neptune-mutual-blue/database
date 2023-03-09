DROP FUNCTION IF EXISTS is_diversified
(
  _chain_id                                     uint256,
  _cover_key                                    bytes32
);

CREATE FUNCTION is_diversified
(
  _chain_id                                     uint256,
  _cover_key                                    bytes32
)
RETURNS boolean
STABLE
AS
$$
BEGIN
  IF EXISTS
  (
    SELECT * FROM cover.cover_created
    WHERE chain_id = _chain_id
    AND cover_key = _cover_key
    AND supports_products = TRUE
  ) THEN
    RETURN true;
  END IF;

  RETURN false;
END
$$
LANGUAGE plpgsql;
