CREATE OR REPLACE VIEW skip_block_view
AS
WITH RECURSIVE ordered 
AS 
(
  SELECT id, chain_id, block_number::bigint, ROW_NUMBER() OVER (ORDER BY chain_id, block_number::bigint) AS rn
  FROM core.transactions
),
missing_ranges
AS 
(
  SELECT
    ordered1.chain_id                                   AS chain_id,
    ordered1.block_number + 1                           AS start_range,
    ordered2.block_number - 1                           AS end_range,
    (ordered2.block_number - ordered1.block_number)     AS skip_count
  FROM ordered                                          AS ordered1
  INNER JOIN ordered                                    AS ordered2
  ON 1                                                  = 1
  AND ordered1.chain_id                                 = ordered2.chain_id
  AND ordered1.rn                                        = ordered2.rn - 1
  WHERE ordered2.block_number - ordered1.block_number   > 1
)
SELECT
  ROW_NUMBER() OVER (ORDER BY chain_id) AS id,
  chain_id,
  CONCAT(start_range, '-', end_range) AS skip_block_range,
  skip_count
FROM missing_ranges;
