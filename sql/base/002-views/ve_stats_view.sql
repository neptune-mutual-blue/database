CREATE OR REPLACE VIEW ve_stats_view
AS
SELECT SUM(amount) AS total_vote_locked, AVG(duration_in_weeks) AS average_lock
FROM ve.vote_escrow_lock;
