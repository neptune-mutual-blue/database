DROP VIEW IF EXISTS all_property_view;

CREATE VIEW all_property_view
AS
WITH parsed
AS
(
  SELECT DISTINCT jsonb_array_elements(attributes) AS values
  FROM nfts
),
key_value_pairs
AS
(
  SELECT values->>'trait_type' AS key, values->>'value' AS value
  FROM parsed
)
SELECT * FROM key_value_pairs
WHERE key NOT IN ('Nickname')
ORDER BY key;
