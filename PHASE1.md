# Phase 1: n8n Setup

This directory contains the implementation of Phase 1 from the deployment plan, which sets up n8n with Docker Compose along with a PostgreSQL database.

## Implementation Details

Based on the PLAN.md document, this setup includes:

- n8n version 1.54.0 Docker image
- PostgreSQL 16 database
- Dedicated network `lab-network`
- Port mapping for n8n web UI (5678), bound to loopback only
- Postgres healthcheck with n8n gated on `service_healthy`
- Named volumes for both n8n and PostgreSQL
- Environment variables configured for development

## Files Created

1. `compose.yaml` - Complete Docker Compose configuration for n8n and PostgreSQL
2. `.env` - Environment variables for the services (gitignored)
3. `.env.example` - Template for `.env` with empty secret values
4. `init-scripts/01-init-db.sql` - Postgres init script directory mount
5. `test-setup.sh` - Verification script for the running stack

## Getting Started

1. Make sure Docker is installed and running
2. Create your `.env`:
   ```bash
   cp .env.example .env
   # then fill in N8N_USER_MANAGEMENT_JWT_SECRET, N8N_ENCRYPTION_KEY and POSTGRES_PASSWORD
   # e.g. openssl rand -hex 32
   ```
3. Run `docker compose up -d` to start the services
4. Open http://localhost:5678 and create the owner account (the email and
   password you choose there become the n8n login)
5. Run `./test-setup.sh` to verify the stack

## Verifying the stack

```bash
./test-setup.sh
```

The script checks that both containers are running, that Postgres is healthy and
reachable from the n8n container over the compose network, that n8n answers
`/healthz`, and that n8n is backed by PostgreSQL rather than SQLite.

## Notes on n8n 1.54.0 configuration

Three settings are easy to get wrong on this version, and each one fails at startup:

- `DB_TYPE` must be `postgresdb`, not `postgres`.
- The database variables use the `DB_POSTGRESDB_*` prefix
  (`DB_POSTGRESDB_HOST`, `DB_POSTGRESDB_USER`, `DB_POSTGRESDB_PASSWORD`,
  `DB_POSTGRESDB_DATABASE`, `DB_POSTGRESDB_PORT`, `DB_POSTGRESDB_SCHEMA`).
  The older `DB_POSTGRES_*` names are ignored.
- `DB_POSTGRESDB_SSL_ENABLED` is deliberately left unset. On 1.54.0 the option
  is declared with an untyped (Object) design type, so the value is not
  coerced to a boolean. The string `false` stays truthy and makes n8n attempt
  an SSL connection against a non-SSL Postgres.

`N8N_BASIC_AUTH_*` was removed from n8n before 1.54.0. Access is controlled by
the owner account created in the UI instead.

## Directory Structure

```
.
├── compose.yaml
├── .env                    (gitignored)
├── .env.example
├── init-scripts/
│   └── 01-init-db.sql
├── test-setup.sh
├── PHASE1.md
├── START_N8N.md
├── SUMMARY.md
└── GIT_OPERATIONS.md
```

This implementation follows the specifications in PLAN.md Phase 1.