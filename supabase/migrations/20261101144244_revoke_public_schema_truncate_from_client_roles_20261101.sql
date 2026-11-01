-- LVE-2026-11-01-577
-- Revoke PostgreSQL TRUNCATE from exposed client roles on current public API
-- tables and remove the same default privilege for postgres-owned future tables.
-- No rows are deleted and service_role/owner privileges are preserved.

REVOKE TRUNCATE ON ALL TABLES IN SCHEMA public
FROM anon, authenticated;

ALTER DEFAULT PRIVILEGES FOR ROLE postgres
IN SCHEMA public
REVOKE TRUNCATE ON TABLES
FROM anon, authenticated;
