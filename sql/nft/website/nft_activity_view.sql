DROP VIEW IF EXISTS nft_activity_view CASCADE;

CREATE VIEW nft_activity_view
AS
SELECT id, token_id, 'Soulbound'     AS event, chain_id, transaction_hash, block_timestamp, transaction_sender AS "from", NULL AS "to" FROM nft.soul_bound
UNION ALL
SELECT id, token_id, 'Transfer'      AS event, chain_id, transaction_hash, block_timestamp, sender AS "from", receiver AS "to" FROM nft.neptune_legends_transfer
--UNION ALL
--@todo: transfer_batch
;
