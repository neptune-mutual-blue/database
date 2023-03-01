DROP FUNCTION IF EXISTS string_to_bytes32(_bytes32 text) CASCADE;

CREATE FUNCTION string_to_bytes32(_string text)
RETURNS text
IMMUTABLE
AS
$$
  DECLARE _bytes32 text = '0x';
BEGIN

  FOR i IN 0..character_length(_string)
  LOOP
    _bytes32 := _bytes32 || to_hex(ascii(substring(_string FROM i + 1 FOR 1)));
    RAISE NOTICE '%', to_hex(ascii(substring(_string FROM i + 1 FOR 1)));
  END LOOP;

  RETURN rpad(_bytes32, 64, '0');
END
$$
LANGUAGE plpgsql;

--SELECT * FROM bytes32_to_string(string_to_bytes32('prime'));
