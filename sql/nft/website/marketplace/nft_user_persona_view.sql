CREATE OR REPLACE VIEW nft_user_persona_view
AS
SELECT
  COALESCE(nft.persona_set.account, nft.soul_bound.transaction_sender) AS account,
  level,
  persona,
  nft.soul_bound.token_id AS bound_token_id
FROM nft.soul_bound
FULL OUTER JOIN nft.persona_set
ON nft.persona_set.account = nft.soul_bound.transaction_sender;
