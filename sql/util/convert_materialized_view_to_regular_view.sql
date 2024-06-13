CREATE OR REPLACE FUNCTION convert_materialized_view_to_regular_view(materialized_view text)
RETURNS void
AS
$$
  DECLARE _dependencies                                             text[];
  DECLARE _dependency_codes                                         text[];
  DECLARE _mv_code                                                  text;
  DECLARE _r                                                        text;
  DECLARE _sql                                                      text = '';
BEGIN
  WITH dependencies
  AS
  (
    SELECT DISTINCT pg_describe_object(classid, objid, objsubid)    AS dependency
    FROM pg_depend
    WHERE refobjid = materialized_view::regclass
    AND deptype = 'n'
  ),
  all_views
  AS
  (
    SELECT REPLACE(dependency, 'rule _RETURN on view ', '')         AS dependency
    FROM dependencies
  ),
  views_to_drop
  AS
  (
    SELECT ARRAY_AGG(dependency)                                    AS dependencies
    FROM all_views
  )
  SELECT dependencies
  INTO _dependencies
  FROM views_to_drop;

  FOREACH _r IN ARRAY _dependencies
  LOOP
    _dependency_codes:= _dependency_codes|| pg_get_viewdef(_r, true);
    _sql = CONCAT(E'\n', _sql, format('DROP VIEW %I;', _r));
  END LOOP;

  _mv_code := pg_get_viewdef(materialized_view::regclass, true);

  _sql = CONCAT(E'\n', _sql, format('DROP MATERIALIZED VIEW %I;', materialized_view::regclass));

  _sql = CONCAT(E'\n', _sql, format(E'CREATE VIEW %I AS\n%s;', materialized_view::regclass, _mv_code));


  FOR i IN 1..array_length(_dependencies, 1)
  LOOP
    _sql = CONCAT
    (
      E'\n',
      _sql,
      format(E'SET search_path TO public; CREATE VIEW %I AS\n%s;', _dependencies[i], _dependency_codes[i])
    );
  END LOOP;

  RAISE NOTICE '%', _sql;

  EXECUTE _sql;
END
$$
LANGUAGE plpgsql;

ALTER FUNCTION convert_materialized_view_to_regular_view OWNER TO writeuser;
