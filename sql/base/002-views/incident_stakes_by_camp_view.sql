DROP VIEW IF EXISTS incident_stakes_by_camp_view CASCADE;

CREATE VIEW incident_stakes_by_camp_view
AS
SELECT incident_stakes_view.activity AS camp,
  incident_stakes_view.chain_id,
  incident_stakes_view.cover_key,
  incident_stakes_view.product_key,
  incident_stakes_view.incident_date,
  sum(get_npm_value(incident_stakes_view.stake::numeric)) AS camp_total
  FROM incident_stakes_view
GROUP BY
  incident_stakes_view.activity,
  incident_stakes_view.chain_id,
  incident_stakes_view.cover_key,
  incident_stakes_view.product_key,
  incident_stakes_view.incident_date;
