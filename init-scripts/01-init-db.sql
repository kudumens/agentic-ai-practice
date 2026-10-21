-- Phase 1 init script for the local n8n lab.
--
-- The `n8n` database itself is created by the official postgres image via
-- POSTGRES_DB=n8n. n8n then owns and migrates its own schema on first boot.
--
-- This file exists so that /docker-entrypoint-initdb.d is mounted and
-- ready for Phase 2+ (extensions, additional roles, etc.).
--
-- NOTE: files in this directory only run when the data volume is empty.

SELECT 'n8n init script executed' AS status;