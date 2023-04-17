CREATE OR REPLACE FUNCTION log_like
(
  _account                               address,
  _token_id                             uint256
)
RETURNS uint256
AS
$$
  DECLARE _previous               boolean;
  DECLARE _current                boolean;
  DECLARE _last_liked_at          TIMESTAMP WITH TIME ZONE;
  DECLARE _last_unliked_at        TIMESTAMP WITH TIME ZONE;
  DECLARE _liked_at               TIMESTAMP WITH TIME ZONE;
  DECLARE _token_likes           uint256;
BEGIN
  IF NOT EXISTS(SELECT 1 FROM nfts WHERE token_id = _token_id) THEN
    RAISE EXCEPTION 'Invalid token id';
  END IF;

  SELECT likes.liked                    INTO _previous
  WHERE likes.liked_by                  = _account
  AND likes.token_id                    = _token_id;

  IF(_previous = false) THEN
    _current                            := true;
    _last_liked_at                      := NOW();
  ELSIF(_previous = true) THEN
    _current                            := false;
    _last_unliked_at                    := NOW();
  ELSE
    _current                            := true;
    _last_liked_at                      := NOW();
  END IF;

  UPDATE likes
  SET
    liked                               = _current,
    last_liked_at                       = _last_liked_at,
    last_unliked_at                     = _last_unliked_at
  WHERE likes.liked_by                  = _account
  AND likes.token_id                    = _token_id;

  IF(_current = true) THEN
    UPDATE nfts
    SET likes = nfts.likes + 1
    WHERE token_id = _token_id
    RETURNING nfts.likes                INTO _token_likes;
  ELSE
    UPDATE nfts
    SET likes = nfts.likes - 1
    WHERE token_id = _token_id
    RETURNING nfts.likes                INTO _token_likes;
  END IF;

  RETURN _token_likes;
END
$$
LANGUAGE plpgsql;