\getenv node_password NODE_DB_PASSWORD
SELECT 'CREATE ROLE node_app LOGIN' WHERE NOT EXISTS(SELECT 1 FROM pg_roles WHERE rolname='node_app') \gexec
SELECT format('ALTER ROLE node_app PASSWORD %L', :'node_password') \gexec
CREATE SCHEMA IF NOT EXISTS node AUTHORIZATION node_app;
ALTER SCHEMA node OWNER TO node_app;
GRANT USAGE, CREATE ON SCHEMA node TO node_app;
SELECT format('ALTER TABLE node.%I OWNER TO node_app',tablename) FROM pg_tables WHERE schemaname='node' \gexec
SELECT format('ALTER SEQUENCE node.%I OWNER TO node_app',sequencename) FROM pg_sequences WHERE schemaname='node' \gexec
ALTER ROLE node_app SET search_path TO node, pg_catalog;
