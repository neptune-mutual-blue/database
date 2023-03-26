DROP VIEW IF EXISTS nft_activity_view CASCADE;

CREATE VIEW nft_activity_view
AS
SELECT  id AS token_id, 'Soulbound'     AS event, transaction_hash, block_timestamp, transaction_sender AS "from", NULL AS "to" FROM soulbound
UNION ALL
SELECT  id AS token_id, 'Transfer'      AS event, transaction_hash, block_timestamp, "from", "to" FROM transfer_single
--UNION ALL
--@todo: transfer_batch
;
