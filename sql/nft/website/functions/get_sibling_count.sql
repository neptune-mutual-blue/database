CREATE OR REPLACE FUNCTION get_sibling_count(_family national character varying(128))
RETURNS integer
STABLE
AS
$$
BEGIN
  RETURN siblings
  FROM characters
  WHERE name = _family;
END
$$
LANGUAGE plpgsql;
