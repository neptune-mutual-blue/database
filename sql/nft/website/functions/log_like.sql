CREATE OR REPLACE FUNCTION log_like
(
  _account                                address,
  _token_id                               uint256
)
RETURNS uint256
AS
$$
  DECLARE _previous                       boolean;
  DECLARE _token_likes                    uint256;
BEGIN
  IF NOT EXISTS(SELECT 1 FROM nfts WHERE token_id = _token_id) THEN
    RAISE EXCEPTION 'Invalid token id';
  END IF;

  SELECT likes.liked                      INTO _previous
  FROM likes
  WHERE likes.liked_by                    = _account
  AND likes.token_id                      = _token_id
  LIMIT 1;

  UPDATE likes
  SET
    last_unliked_at                       = CASE WHEN liked = true  THEN NOW() ELSE last_unliked_at END,
    last_liked_at                         = CASE WHEN liked = false THEN NOW() ELSE last_liked_at   END,
    liked                                 = !liked
  WHERE likes.liked_by                    = _account
  AND likes.token_id                      = _token_id;

  UPDATE nfts
  SET likes                               = likes + (CASE WHEN _previous = true THEN -1 ELSE 1 END)
  WHERE token_id                          = _token_id
  RETURNING nfts.likes                    INTO _token_likes;

  RETURN _token_likes;
END
$$
LANGUAGE plpgsql;