DROP FUNCTION IF EXISTS bytes32_to_string(_bytes32 text) CASCADE;

CREATE OR REPLACE FUNCTION bytes32_to_string(_bytes32 text)
RETURNS text
IMMUTABLE
AS
$$
  DECLARE _string text = '';
  DECLARE _fragment text;
  DECLARE _code integer;
  DECLARE _length integer;
BEGIN
  IF(_bytes32 IS NULL) THEN
    RETURN '';
  END IF;

  IF(starts_with(_bytes32, '0x')) THEN
    _bytes32 = substring(_bytes32, 3);
  END IF;
  
  _length := character_length(_bytes32);
  
  FOR i IN 0.._length BY 2
  LOOP
    _code := hex_to_int(substring(_bytes32 FROM i + 1 FOR 2));
    
    IF(_code = 0) THEN
      CONTINUE;
    END IF;

    _fragment := chr(_code);
    _string := _string || _fragment;
  END LOOP;

  RETURN _string;
END
$$
LANGUAGE plpgsql;

--SELECT * FROM bytes32_to_string('0x7072696d65000000000000000000000000000000000000000000000000000000');


