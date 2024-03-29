GRANT USAGE ON SCHEMA vault TO readonlyuser;
GRANT USAGE ON SCHEMA ve TO readonlyuser;
GRANT USAGE ON SCHEMA strategy TO readonlyuser;
GRANT USAGE ON SCHEMA store TO readonlyuser;
GRANT USAGE ON SCHEMA staking TO readonlyuser;
GRANT USAGE ON SCHEMA reassurance TO readonlyuser;
GRANT USAGE ON SCHEMA public TO readonlyuser;
GRANT USAGE ON SCHEMA protocol TO readonlyuser;
GRANT USAGE ON SCHEMA policy TO readonlyuser;
GRANT USAGE ON SCHEMA factory TO readonlyuser;
GRANT USAGE ON SCHEMA cxtoken TO readonlyuser;
GRANT USAGE ON SCHEMA cover TO readonlyuser;
GRANT USAGE ON SCHEMA core TO readonlyuser;
GRANT USAGE ON SCHEMA consensus TO readonlyuser;
GRANT USAGE ON SCHEMA claim TO readonlyuser;
GRANT USAGE ON SCHEMA nft TO readonlyuser;

GRANT SELECT ON ALL TABLES IN SCHEMA factory TO readonlyuser;
GRANT SELECT ON ALL TABLES IN SCHEMA strategy TO readonlyuser;
GRANT SELECT ON ALL TABLES IN SCHEMA core TO readonlyuser;
GRANT SELECT ON ALL TABLES IN SCHEMA reassurance TO readonlyuser;
GRANT SELECT ON ALL TABLES IN SCHEMA cxtoken TO readonlyuser;
GRANT SELECT ON ALL TABLES IN SCHEMA policy TO readonlyuser;
GRANT SELECT ON ALL TABLES IN SCHEMA consensus TO readonlyuser;
GRANT SELECT ON ALL TABLES IN SCHEMA vault TO readonlyuser;
GRANT SELECT ON ALL TABLES IN SCHEMA ve TO readonlyuser;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO readonlyuser;
GRANT SELECT ON ALL TABLES IN SCHEMA protocol TO readonlyuser;
GRANT SELECT ON ALL TABLES IN SCHEMA cover TO readonlyuser;
GRANT SELECT ON ALL TABLES IN SCHEMA staking TO readonlyuser;
GRANT SELECT ON ALL TABLES IN SCHEMA store TO readonlyuser;
GRANT SELECT ON ALL TABLES IN SCHEMA claim TO readonlyuser;
GRANT SELECT ON ALL TABLES IN SCHEMA nft TO readonlyuser;

ALTER DEFAULT PRIVILEGES IN SCHEMA factory GRANT SELECT ON TABLES TO readonlyuser;
ALTER DEFAULT PRIVILEGES IN SCHEMA strategy GRANT SELECT ON TABLES TO readonlyuser;
ALTER DEFAULT PRIVILEGES IN SCHEMA core GRANT SELECT ON TABLES TO readonlyuser;
ALTER DEFAULT PRIVILEGES IN SCHEMA reassurance GRANT SELECT ON TABLES TO readonlyuser;
ALTER DEFAULT PRIVILEGES IN SCHEMA cxtoken GRANT SELECT ON TABLES TO readonlyuser;
ALTER DEFAULT PRIVILEGES IN SCHEMA policy GRANT SELECT ON TABLES TO readonlyuser;
ALTER DEFAULT PRIVILEGES IN SCHEMA consensus GRANT SELECT ON TABLES TO readonlyuser;
ALTER DEFAULT PRIVILEGES IN SCHEMA vault GRANT SELECT ON TABLES TO readonlyuser;
ALTER DEFAULT PRIVILEGES IN SCHEMA ve GRANT SELECT ON TABLES TO readonlyuser;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT ON TABLES TO readonlyuser;
ALTER DEFAULT PRIVILEGES IN SCHEMA protocol GRANT SELECT ON TABLES TO readonlyuser;
ALTER DEFAULT PRIVILEGES IN SCHEMA cover GRANT SELECT ON TABLES TO readonlyuser;
ALTER DEFAULT PRIVILEGES IN SCHEMA staking GRANT SELECT ON TABLES TO readonlyuser;
ALTER DEFAULT PRIVILEGES IN SCHEMA store GRANT SELECT ON TABLES TO readonlyuser;
ALTER DEFAULT PRIVILEGES IN SCHEMA claim GRANT SELECT ON TABLES TO readonlyuser;
ALTER DEFAULT PRIVILEGES IN SCHEMA nft GRANT SELECT ON TABLES TO readonlyuser;

REVOKE CREATE ON SCHEMA factory FROM readonlyuser;
REVOKE CREATE ON SCHEMA strategy FROM readonlyuser;
REVOKE CREATE ON SCHEMA core FROM readonlyuser;
REVOKE CREATE ON SCHEMA reassurance FROM readonlyuser;
REVOKE CREATE ON SCHEMA cxtoken FROM readonlyuser;
REVOKE CREATE ON SCHEMA policy FROM readonlyuser;
REVOKE CREATE ON SCHEMA consensus FROM readonlyuser;
REVOKE CREATE ON SCHEMA vault FROM readonlyuser;
REVOKE CREATE ON SCHEMA ve FROM readonlyuser;
REVOKE CREATE ON SCHEMA protocol FROM readonlyuser;
REVOKE CREATE ON SCHEMA cover FROM readonlyuser;
REVOKE CREATE ON SCHEMA staking FROM readonlyuser;
REVOKE CREATE ON SCHEMA store FROM readonlyuser;
REVOKE CREATE ON SCHEMA claim FROM readonlyuser;
REVOKE CREATE ON SCHEMA nft FROM readonlyuser;

ALTER DEFAULT PRIVILEGES IN SCHEMA factory REVOKE INSERT, UPDATE, DELETE ON TABLES FROM readonlyuser;
ALTER DEFAULT PRIVILEGES IN SCHEMA strategy REVOKE INSERT, UPDATE, DELETE ON TABLES FROM readonlyuser;
ALTER DEFAULT PRIVILEGES IN SCHEMA core REVOKE INSERT, UPDATE, DELETE ON TABLES FROM readonlyuser;
ALTER DEFAULT PRIVILEGES IN SCHEMA reassurance REVOKE INSERT, UPDATE, DELETE ON TABLES FROM readonlyuser;
ALTER DEFAULT PRIVILEGES IN SCHEMA cxtoken REVOKE INSERT, UPDATE, DELETE ON TABLES FROM readonlyuser;
ALTER DEFAULT PRIVILEGES IN SCHEMA policy REVOKE INSERT, UPDATE, DELETE ON TABLES FROM readonlyuser;
ALTER DEFAULT PRIVILEGES IN SCHEMA consensus REVOKE INSERT, UPDATE, DELETE ON TABLES FROM readonlyuser;
ALTER DEFAULT PRIVILEGES IN SCHEMA vault REVOKE INSERT, UPDATE, DELETE ON TABLES FROM readonlyuser;
ALTER DEFAULT PRIVILEGES IN SCHEMA ve REVOKE INSERT, UPDATE, DELETE ON TABLES FROM readonlyuser;
ALTER DEFAULT PRIVILEGES IN SCHEMA protocol REVOKE INSERT, UPDATE, DELETE ON TABLES FROM readonlyuser;
ALTER DEFAULT PRIVILEGES IN SCHEMA cover REVOKE INSERT, UPDATE, DELETE ON TABLES FROM readonlyuser;
ALTER DEFAULT PRIVILEGES IN SCHEMA staking REVOKE INSERT, UPDATE, DELETE ON TABLES FROM readonlyuser;
ALTER DEFAULT PRIVILEGES IN SCHEMA store REVOKE INSERT, UPDATE, DELETE ON TABLES FROM readonlyuser;
ALTER DEFAULT PRIVILEGES IN SCHEMA claim REVOKE INSERT, UPDATE, DELETE ON TABLES FROM readonlyuser;
ALTER DEFAULT PRIVILEGES IN SCHEMA nft REVOKE INSERT, UPDATE, DELETE ON TABLES FROM readonlyuser;

GRANT CREATE ON SCHEMA public TO writeuser;
GRANT CREATE ON SCHEMA factory TO writeuser;
GRANT CREATE ON SCHEMA strategy TO writeuser;
GRANT CREATE ON SCHEMA core TO writeuser;
GRANT CREATE ON SCHEMA reassurance TO writeuser;
GRANT CREATE ON SCHEMA cxtoken TO writeuser;
GRANT CREATE ON SCHEMA policy TO writeuser;
GRANT CREATE ON SCHEMA consensus TO writeuser;
GRANT CREATE ON SCHEMA vault TO writeuser;
GRANT CREATE ON SCHEMA ve TO writeuser;
GRANT CREATE ON SCHEMA protocol TO writeuser;
GRANT CREATE ON SCHEMA cover TO writeuser;
GRANT CREATE ON SCHEMA staking TO writeuser;
GRANT CREATE ON SCHEMA store TO writeuser;
GRANT CREATE ON SCHEMA claim TO writeuser;
GRANT CREATE ON SCHEMA nft TO writeuser;

GRANT INSERT, UPDATE ON ALL TABLES IN SCHEMA public TO writeuser;
GRANT INSERT, UPDATE ON ALL TABLES IN SCHEMA factory TO writeuser;
GRANT INSERT, UPDATE ON ALL TABLES IN SCHEMA strategy TO writeuser;
GRANT INSERT, UPDATE ON ALL TABLES IN SCHEMA core TO writeuser;
GRANT INSERT, UPDATE ON ALL TABLES IN SCHEMA reassurance TO writeuser;
GRANT INSERT, UPDATE ON ALL TABLES IN SCHEMA cxtoken TO writeuser;
GRANT INSERT, UPDATE ON ALL TABLES IN SCHEMA policy TO writeuser;
GRANT INSERT, UPDATE ON ALL TABLES IN SCHEMA consensus TO writeuser;
GRANT INSERT, UPDATE ON ALL TABLES IN SCHEMA vault TO writeuser;
GRANT INSERT, UPDATE ON ALL TABLES IN SCHEMA ve TO writeuser;
GRANT INSERT, UPDATE ON ALL TABLES IN SCHEMA protocol TO writeuser;
GRANT INSERT, UPDATE ON ALL TABLES IN SCHEMA cover TO writeuser;
GRANT INSERT, UPDATE ON ALL TABLES IN SCHEMA staking TO writeuser;
GRANT INSERT, UPDATE ON ALL TABLES IN SCHEMA store TO writeuser;
GRANT INSERT, UPDATE ON ALL TABLES IN SCHEMA claim TO writeuser;
GRANT INSERT, UPDATE ON ALL TABLES IN SCHEMA nft TO writeuser;

ALTER DEFAULT PRIVILEGES IN SCHEMA factory GRANT INSERT, UPDATE ON TABLES TO writeuser;
ALTER DEFAULT PRIVILEGES IN SCHEMA strategy GRANT INSERT, UPDATE ON TABLES TO writeuser;
ALTER DEFAULT PRIVILEGES IN SCHEMA core GRANT INSERT, UPDATE ON TABLES TO writeuser;
ALTER DEFAULT PRIVILEGES IN SCHEMA reassurance GRANT INSERT, UPDATE ON TABLES TO writeuser;
ALTER DEFAULT PRIVILEGES IN SCHEMA cxtoken GRANT INSERT, UPDATE ON TABLES TO writeuser;
ALTER DEFAULT PRIVILEGES IN SCHEMA policy GRANT INSERT, UPDATE ON TABLES TO writeuser;
ALTER DEFAULT PRIVILEGES IN SCHEMA consensus GRANT INSERT, UPDATE ON TABLES TO writeuser;
ALTER DEFAULT PRIVILEGES IN SCHEMA vault GRANT INSERT, UPDATE ON TABLES TO writeuser;
ALTER DEFAULT PRIVILEGES IN SCHEMA ve GRANT INSERT, UPDATE ON TABLES TO writeuser;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT INSERT, UPDATE ON TABLES TO writeuser;
ALTER DEFAULT PRIVILEGES IN SCHEMA protocol GRANT INSERT, UPDATE ON TABLES TO writeuser;
ALTER DEFAULT PRIVILEGES IN SCHEMA cover GRANT INSERT, UPDATE ON TABLES TO writeuser;
ALTER DEFAULT PRIVILEGES IN SCHEMA staking GRANT INSERT, UPDATE ON TABLES TO writeuser;
ALTER DEFAULT PRIVILEGES IN SCHEMA store GRANT INSERT, UPDATE ON TABLES TO writeuser;
ALTER DEFAULT PRIVILEGES IN SCHEMA claim GRANT INSERT, UPDATE ON TABLES TO writeuser;
ALTER DEFAULT PRIVILEGES IN SCHEMA nft GRANT INSERT, UPDATE ON TABLES TO writeuser;
