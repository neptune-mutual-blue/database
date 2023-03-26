DROP SCHEMA IF EXISTS sol CASCADE;

CREATE SCHEMA sol;

CREATE TABLE sol.abis 
(
  id                                  SERIAL PRIMARY KEY,
  interface                           text,
  name                                text,
  state_mutability                    text,
  type                                text
);

CREATE TABLE sol.inputs
(
  id                                  SERIAL PRIMARY KEY,
  name                                text,
  type                                text,
  internal_type                       text,
  indexed                             BOOLEAN,
  abi_id                              INTEGER REFERENCES sol.abis(id)
);

CREATE TABLE sol.tuple_components
(
  id                                  SERIAL PRIMARY KEY,
  input_id                            INTEGER REFERENCES sol.inputs(id),
  name                                text,
  type                                text,
  internal_type                       text
);

CREATE TABLE sol.outputs
(
  id                                  SERIAL PRIMARY KEY,
  name                                text,
  type                                text,
  internal_type                       text,
  abi_id                              INTEGER REFERENCES sol.abis(id)
);

DROP FUNCTION IF EXISTS sol.insert_abi(_interface text, _abi jsonb);

CREATE FUNCTION sol.insert_abi(_interface text, _abi jsonb)
RETURNS VOID AS
$$
DECLARE abi_id INTEGER;
DECLARE abi_element jsonb;
BEGIN
  FOR i IN 0 .. (jsonb_array_length(_abi) - 1) LOOP
    abi_element := _abi->i;

    INSERT INTO sol.abis (interface, name, state_mutability, type)
    VALUES (_interface, abi_element->>'name', abi_element->>'stateMutability', abi_element->>'type')
    RETURNING id INTO abi_id;

    FOR j IN 0 .. (jsonb_array_length(abi_element->'inputs') - 1) LOOP
      INSERT INTO sol.inputs (name, type, internal_type, indexed, abi_id)
      VALUES (
        COALESCE(abi_element->'inputs'->j->>'name', ''),
        abi_element->'inputs'->j->>'type',
        abi_element->'inputs'->j->>'internalType',
        abi_element->'inputs'->j->>'indexed' = 'true',
        abi_id
      );

      IF abi_element->'inputs'->j->>'type' = 'tuple' THEN
        FOR k IN 0 .. (jsonb_array_length(abi_element->'inputs'->j->'components') - 1) LOOP
          INSERT INTO sol.tuple_components (input_id, name, type, internal_type)
          VALUES (
            currval('sol.inputs_id_seq'),
            COALESCE(abi_element->'inputs'->j->'components'->k->>'name', ''),
            abi_element->'inputs'->j->'components'->k->>'type',
            abi_element->'inputs'->j->'components'->k->>'internalType'
          );
        END LOOP;
      END IF;
    END LOOP;

    IF(abi_element->>'type' = 'function') THEN
      FOR j IN 0 .. (jsonb_array_length(abi_element->'outputs') - 1) LOOP
        INSERT INTO sol.outputs (name, type, internal_type, abi_id)
        VALUES (
          COALESCE(abi_element->'outputs'->j->>'name', ''),
          abi_element->'outputs'->j->>'type',
          abi_element->'outputs'->j->>'internalType',
          abi_id
        );
      END LOOP;
    END IF;
  END LOOP;
END;
$$
LANGUAGE plpgsql;



DROP VIEW IF EXISTS sol.mutable_functions_raw_view;

CREATE VIEW sol.mutable_functions_raw_view
AS
SELECT
  DENSE_RANK() OVER(ORDER BY sol.abiS.interface DESC, sol.abis.interface, sol.abis.name) AS id,
  sol.abis.interface,
  sol.abis.name AS function_name,
  sol.inputs.name AS arg,
  sol.inputs.internal_type AS type
FROM sol.abis
INNER JOIN sol.inputs
ON sol.inputs.abi_id = sol.abis.id
WHERE state_mutability = 'nonpayable'
AND interface NOT IN ('IERC20', 'IERC20Detailed', 'IStore', 'IAaveV2LendingPoolLike', 'ICompoundERC20DelegatorLike')
ORDER BY id;

DROP VIEW IF EXISTS sol.mutable_functions_view;

CREATE VIEW sol.mutable_functions_view
AS
SELECT
  sol.mutable_functions_raw_view.id,
  sol.mutable_functions_raw_view.interface,
  CONCAT
  (
    sol.mutable_functions_raw_view.function_name, 
    '(',
    array_to_string
    (
      array_agg
      (
        CONCAT(type, ' ', arg)
      ),
      ', '), 
    ')') AS function
FROM sol.mutable_functions_raw_view
GROUP BY
  sol.mutable_functions_raw_view.id, 
  sol.mutable_functions_raw_view.interface,
  sol.mutable_functions_raw_view.function_name
ORDER BY 
  sol.mutable_functions_raw_view.id;

