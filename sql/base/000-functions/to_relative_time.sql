CREATE OR REPLACE FUNCTION ABS(interval)
RETURNS interval
IMMUTABLE
AS
$$
  SELECT CASE WHEN ($1 < interval '0')
  THEN -$1 ELSE $1 END;
$$
LANGUAGE sql;


CREATE OR REPLACE FUNCTION to_relative_time
(
  _from                           TIMESTAMP WITH TIME ZONE,
  _to                             TIMESTAMP WITH TIME ZONE DEFAULT NOW()
)
RETURNS text 
AS 
$$
  DECLARE duration                interval = ABS(_to - _from);
  DECLARE future                  boolean = _from > _to;
  DECLARE result                  text;
BEGIN
  IF duration < INTERVAL '1 minute' THEN
    RETURN 'recently';
  ELSIF duration < INTERVAL '1 hour' THEN
    result := extract(minute from duration)::integer || ' minutes';
  ELSIF duration < INTERVAL '1 day' THEN
    result := extract(hour from duration)::integer || ' hours';
  ELSIF duration < INTERVAL '7 days' THEN
    result := extract(day from duration)::integer || ' days';
  ELSIF duration < INTERVAL '1 month' THEN
    result := (extract(day from duration) / 7)::integer || ' weeks';
  ELSIF duration < INTERVAL '1 year' THEN
    result := (extract(day from duration) / 30)::numeric(8, 1) || ' months';
  ELSE
    result := (extract(day from duration) / 365)::numeric(8, 1) || ' years';
  END IF;


  IF(future) THEN
    RETURN CONCAT('in ', result);
  END IF;

  RETURN CONCAT(result, ' ago');
END;
$$
LANGUAGE plpgsql;



