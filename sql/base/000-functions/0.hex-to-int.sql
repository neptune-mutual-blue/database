DROP FUNCTION IF EXISTS hex_to_int(_hex text) CASCADE;

CREATE FUNCTION hex_to_int(_hex text)
RETURNS integer
IMMUTABLE
AS
$$
BEGIN
  RETURN ('x' || lpad(_hex, 8, '0'))::bit(32)::integer;
END
$$
LANGUAGE plpgsql;


