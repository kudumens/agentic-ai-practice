# Phase 1: n8n Setup - Implementation Summary

## Status

Verified working. n8n 1.54.0 runs against PostgreSQL 16, the editor is
reachable at http://localhost:5678, and data survives a `docker compose down`
/ `up` cycle.

## Completed Tasks

This worktree implements Phase 1 of the deployment plan, setting up n8n with Docker Compose and PostgreSQL database as specified in PLAN.md.

### Files Created

1. **`compose.yaml`** - Complete Docker Compose configuration:
   - n8n version 1.54.0 image
   - PostgreSQL 16 database
   - Dedicated network `lab-network`
   - Port mapping for n8n web UI (5678) and Postgres (5432), both bound to
     loopback only (`127.0.0.1:...`) as required by PLAN.md section 6
   - Postgres healthcheck, with n8n gated on `condition: service_healthy`
   - Named volumes for both n8n and PostgreSQL
   - Environment variables configured for development

2. **`.env`** - Environment variables file (gitignored):
   - JWT secret and encryption key for user management
   - PostgreSQL database settings
   - Timezone configuration
   - Editor and webhook URLs

3. **`.env.example`** - Template for `.env` with empty secret values, as
   required by PLAN.md section 6

4. **`PHASE1.md`** - Documentation of the implementation:
   - Description of what was implemented
   - How to get started
   - n8n 1.54.0 configuration notes
   - Directory structure overview

   The project `README.md` is deliberately left untouched. It is the
   project overview and hardware requirements document, and it belongs to the
   repository root rather than to this phase.

5. **`GIT_OPERATIONS.md`** - Git workflow documentation:
   - Procedures for creating and managing worktrees
   - Pull request templates and guidelines
   - Branch naming conventions

6. **`test-setup.sh`** - Verification script:
   - Tests Docker and Docker Compose availability
   - Validates the compose configuration
   - Checks both containers are running and Postgres is healthy
   - Checks Postgres is reachable from the n8n container
   - Checks the n8n health endpoint
   - Checks n8n is backed by PostgreSQL, not SQLite

7. **`START_N8N.md`** - Usage instructions:
   - How to start the services
   - Access information for n8n web UI
   - Useful Docker commands

8. **`init-scripts/01-init-db.sql`** - Postgres init script mounted at
   `/docker-entrypoint-initdb.d`

## Implementation Details

The implementation follows the specifications in PLAN.md Phase 1, Section 2.3, and includes:

- Multi-service Docker Compose setup with n8n and PostgreSQL
- Proper environment variable management
- Data persistence for both services
- Network isolation using dedicated network
- Development-focused configuration
- Loopback-only port publishing

### n8n 1.54.0 configuration notes

Three settings are easy to get wrong on this version. Each one was a real
startup failure during development:

- `DB_TYPE` must be `postgresdb`. With `postgres`, n8n looks up a
  `database.postgres` config section that does not exist and crashes with
  "Cannot read properties of undefined (reading 'database')".
- The database variables use the `DB_POSTGRESDB_*` prefix
  (`DB_POSTGRESDB_HOST`, `DB_POSTGRESDB_USER`, `DB_POSTGRESDB_PASSWORD`,
  `DB_POSTGRESDB_DATABASE`, `DB_POSTGRESDB_PORT`, `DB_POSTGRESDB_SCHEMA`).
  The older `DB_POSTGRES_*` names are silently ignored, which leaves n8n
  connecting to `localhost` as user `postgres`.
- `DB_POSTGRESDB_SSL_ENABLED` must be left unset. On 1.54.0 the option is
  declared with an untyped (Object) design type, so the value is not coerced
  to a boolean. The string `false` stays truthy and makes n8n attempt an SSL
  connection against a non-SSL Postgres ("The server does not support SSL
  connections").

`N8N_BASIC_AUTH_*` was removed from n8n before 1.54.0. Access is controlled by
the owner account created in the UI instead, so those variables were removed.

## Verification

Verified on n8n 1.54.0 / PostgreSQL 16:

- `./test-setup.sh` passes all 9 checks
- n8n runs its migrations and creates 24 tables in the `public` schema
- No `database.sqlite` in the n8n data volume
- `curl -fsS http://localhost:5678/healthz` returns `{"status":"ok"}`
- Owner account can be created and used to log in
- A workflow created through the n8n API is still returned by the API after
  `docker compose down` followed by `docker compose up`

## Known deviation from PLAN.md

PLAN.md section 5 lists the n8n image as `docker.n8n.io/n8nio/n8n:2.41.6`.
This phase uses `n8nio/n8n:1.54.0`, as specified for the Phase 1 build. The
two are not interchangeable: the database configuration differs (`DB_TYPE`
and the `DB_POSTGRESDB_*` prefix behave as described above on 1.54.0), so the
variables in `compose.yaml` must be re-checked before moving to 2.x.

PLAN.md section 9 names the file `compose.yaml`, which is what is used here.

## Next Steps

Remaining Phase 1 items from PLAN.md:

1. Create an Ollama credential with base URL `http://host.docker.internal:11434`
2. Write the Modelfiles in `models/` and build the lab variants
3. Commit and push changes to the phase-1-n8n-setup branch

## Git Operations

This worktree was created using:
```bash
git worktree add .claude/worktrees/phase-1-n8n-setup
```

To commit changes:
```bash
git add .
git commit -m "Implement Phase 1: n8n setup"
git push origin phase-1-n8n-setup
```

Then create a pull request from GitHub UI.