DROP VIEW IF EXISTS cx_token_deployed_view;
 
CREATE VIEW cx_token_deployed_view
AS
SELECT
  factory.cx_token_deployed.chain_id,
  factory.cx_token_deployed.cover_key,
  factory.cx_token_deployed.product_key,
  factory.cx_token_deployed.token_name,
  factory.cx_token_deployed.cx_token,
  factory.cx_token_deployed.expiry_date
FROM factory.cx_token_deployed;

