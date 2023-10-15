CREATE OR REPLACE VIEW nft_bridge_transactions_view
AS
SELECT
  transaction_hash,
  block_timestamp,
  block_number,
  transaction_sender,
  chain_id,
  sender,
  receiver,
  get_nft_name_info(token_ids) AS tokens,
  dst_chain_id
FROM nft.send_to_chain
