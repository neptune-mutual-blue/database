CREATE OR REPLACE FUNCTION log_like
(
  _account                                address,
  _token_id                               uint256
)
RETURNS uint256
AS
$$
  DECLARE _previous                       boolean;
  DECLARE _like_count                     uint256;
BEGIN
  IF NOT EXISTS(SELECT 1 FROM nfts WHERE token_id = _token_id) THEN
    RAISE EXCEPTION 'Invalid token id';
  END IF;
  
  IF NOT EXISTS(SELECT * FROM likes WHERE token_id = _token_id AND liked_by = _account) THEN
    INSERT INTO likes(token_id, liked_by, liked)
    SELECT _token_id, _account, false;
  END IF;

  SELECT likes.liked
  INTO _previous
  FROM likes
  WHERE likes.liked_by                    = _account
  AND likes.token_id                      = _token_id;

  UPDATE likes
  SET
    last_unliked_at                       = CASE WHEN liked = true  THEN NOW() ELSE last_unliked_at END,
    last_liked_at                         = CASE WHEN liked = false THEN NOW() ELSE last_liked_at   END,
    liked                                 = NOT(COALESCE(liked, false)) 
  WHERE likes.liked_by                    = _account
  AND likes.token_id                      = _token_id;

  UPDATE nfts
  SET likes                               = likes + (CASE WHEN _previous = true THEN -1 ELSE 1 END)
  WHERE token_id                          = _token_id
  RETURNING nfts.likes
  INTO _like_count;

  RETURN _like_count;
END
$$
LANGUAGE plpgsql;

--SELECT * FROM log_like('0xB452AC021a1151AAF342c1B75aA914E03e6503b5', 100500)
