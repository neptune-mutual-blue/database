CREATE OR REPLACE FUNCTION log_view(_token_id uint256)
RETURNS TABLE(token_views uint256, views uint256)
AS
$$
  DECLARE _token_views                  uint256;
  DECLARE _views                        uint256;
BEGIN
  IF NOT EXISTS(SELECT 1 FROM nfts WHERE token_id = _token_id) THEN
    RAISE EXCEPTION 'Invalid token id';
  END IF;

  UPDATE characters
  SET views = characters.views + 1
  WHERE name = 
  (
    SELECT family
    FROM nfts
    WHERE token_id = _token_id
  )
  RETURNING characters.views INTO _views;
  
  UPDATE nfts
  SET views = nfts.views + 1
  WHERE token_id = _token_id
  RETURNING nfts.views INTO _token_views;
  
  RETURN QUERY
  SELECT _token_views, _views;
END
$$
LANGUAGE plpgsql;


--SELECT * FROM log_view((SELECT token_id FROM nfts ORDER BY random() LIMIT 1))

-- DO
-- $$
--   DECLARE i INTEGER;
-- BEGIN
--   FOR i IN 1..10000 LOOP
--   PERFORM * FROM log_view((SELECT token_id FROM nfts ORDER BY random() LIMIT 1));
--   END LOOP;
-- END;
-- $$
-- LANGUAGE plpgsql;



