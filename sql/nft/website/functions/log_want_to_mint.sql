CREATE OR REPLACE FUNCTION log_want_to_mint(_token_id uint256)
RETURNS TABLE(token_want_to_mint uint256, want_to_mint uint256)
AS
$$
  DECLARE _token_want_to_mint                  uint256;
  DECLARE _want_to_mint                        uint256;
BEGIN
  IF NOT EXISTS(SELECT 1 FROM nfts WHERE token_id = _token_id) THEN
    RAISE EXCEPTION 'Invalid token id';
  END IF;

  UPDATE characters
  SET want_to_mint = characters.want_to_mint + 1
  WHERE name = 
  (
    SELECT family
    FROM nfts
    WHERE token_id = _token_id
  )
  RETURNING characters.want_to_mint INTO _want_to_mint;
  
  UPDATE nfts
  SET want_to_mint = nfts.want_to_mint + 1
  WHERE token_id = _token_id
  RETURNING nfts.want_to_mint INTO _token_want_to_mint;
  
  RETURN QUERY
  SELECT _token_want_to_mint, _want_to_mint;
END
$$
LANGUAGE plpgsql;


--SELECT * FROM log_want_to_mint((SELECT token_id FROM nfts ORDER BY random() LIMIT 1))

-- DO
-- $$
--   DECLARE i INTEGER;
-- BEGIN
--   FOR i IN 1..10000 LOOP
--   PERFORM * FROM log_want_to_mint((SELECT token_id FROM nfts ORDER BY random() LIMIT 1));
--   END LOOP;
-- END;
-- $$
-- LANGUAGE plpgsql;



