-- LVE-2026-11-01-577
-- Remove non-RLS TRUNCATE capability from public API roles on all current
-- public-schema tables, and prevent the postgres-owned future tables from
-- receiving that privilege by default. Preserve owner/service_role access.

REVOKE TRUNCATE ON ALL TABLES IN SCHEMA public
FROM anon, authenticated;

ALTER DEFAULT PRIVILEGES FOR ROLE postgres
IN SCHEMA public
REVOKE TRUNCATE ON TABLES
FROM anon, authenticated;
