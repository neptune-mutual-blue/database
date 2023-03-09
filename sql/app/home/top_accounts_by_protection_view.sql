DROP VIEW IF EXISTS top_accounts_by_protection_view CASCADE;

CREATE VIEW top_accounts_by_protection_view
AS
SELECT
  on_behalf_of,
  COUNT(*) AS policies,
  SUM(amount_to_cover) AS protection
FROM policy.cover_purchased
WHERE expires_on > extract(epoch FROM NOW() AT TIME ZONE 'UTC')
GROUP BY on_behalf_of
ORDER BY protection DESC
LIMIT 10;

