# Phase 1: n8n Setup - Implementation Summary

## Status

Complete and verified on 2026-10-21. n8n 1.54.0 runs against PostgreSQL 16, the editor is
reachable at http://localhost:5678, the Ollama credential test passes, and data survives a `docker compose down`
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
   - Checks the instance owner account has been created
   - Checks the Ollama credential exists and that the n8n container can
     reach the host's model server
   - Checks the lab model variants are built with a 16,384 token context

7. **`START_N8N.md`** - Usage instructions:
   - How to start the services
   - Access information for n8n web UI
   - The Ollama credential and the lab model variants
   - Useful Docker commands

8. **`init-scripts/01-init-db.sql`** - Postgres init script mounted at
   `/docker-entrypoint-initdb.d`

9. **`models/`** - Modelfiles for the lab model variants:
   - `lab-llama3.1-8b.Modelfile` - `llama3.1:8b` with a 16,384 token context
   - `lab-mistral-small3.2-24b.Modelfile` - `mistral-small3.2:24b` with a
     16,384 token context

10. **`config/ollama/sh.brew.ollama.plist`** - Launchd plist for the model
    server. Sets `OLLAMA_MAX_LOADED_MODELS=1` so only one model is resident
    at a time, and `OLLAMA_NO_CLOUD=1` so no prompt reaches Ollama's cloud
    services.

11. **`scripts/`** - Helper scripts for driving the n8n REST API:
    - `make_smoke_workflow.py` - builds the smoke-test workflow
    - `show_execution.py` - resolves and prints an execution's run data

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

Verified on n8n 1.54.0 / PostgreSQL 16, on 2026-10-21:

- `./test-setup.sh` passes all 15 checks
- n8n runs its migrations and creates 24 tables in the `public` schema
- No `database.sqlite` in the n8n data volume
- `curl -fsS http://localhost:5678/healthz` returns `{"status":"ok"}`
- The instance owner account is set up and can log in
- The Ollama credential test returns "Connection successful!"
- The n8n container reaches the host's Ollama at
  `http://host.docker.internal:11434`
- Both lab model variants are built and report a 16,384 token context
- A workflow that runs `lab-llama3.1-8b` through the credential returns
  `OLLAMA_OK`
- The workflow, the credential and the owner account all survive
  `docker compose down` followed by `docker compose up`

## Known deviation from PLAN.md

PLAN.md section 4 lists the n8n image as `docker.n8n.io/n8nio/n8n:2.41.6`.
This phase uses `n8nio/n8n:1.54.0`, as specified for the Phase 1 build. The
two are not interchangeable: the database configuration differs (`DB_TYPE`
and the `DB_POSTGRESDB_*` prefix behave as described above on 1.54.0), so the
variables in `compose.yaml` must be re-checked before moving to 2.x.

PLAN.md section 9 names the file `compose.yaml`, which is what is used here.

## Next Steps

Phase 1 is complete. Remaining items, none of which block Phase 2:

1. Re-apply the Docker Desktop memory limit of 8 GB. The settings file says
   `memoryMiB: 8092`, but the running VM reports 15.6 GB, so the models and
   Docker Desktop are competing for the same 32 GB.
2. Move the stack to n8n 2.x, which means re-checking the database
   environment variables and the SSL behaviour first (see PLAN.md).
3. Start Phase 2: the first agent, with the `lab-llama3.1-8b` variant.

## Git Operations

This work was done on the `phase-1-completion` branch, created from `main`
after PR #3 was merged:

```bash
git checkout -b phase-1-completion main
```

To commit changes:
```bash
git add .
git commit -m "Complete Phase 1: Ollama credential, model variants, docs"
git push origin phase-1-completion
```

Then create a pull request from GitHub UI.