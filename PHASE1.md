# Phase 1: n8n Setup

This directory contains the implementation of Phase 1 from the deployment plan, which sets up n8n with Docker Compose along with a PostgreSQL database.

## Status

Complete and verified on 2026-10-21. n8n 1.54.0 runs against PostgreSQL 16, the editor is reachable at http://localhost:5678, the Ollama credential test passes, and the workflow, credential and owner account all survive a `docker compose down` / `up` cycle.

## Implementation Details

Based on the PLAN.md document, this setup includes:

- n8n version 1.54.0 Docker image
- PostgreSQL 16 database
- Dedicated network `lab-network`
- Port mapping for n8n web UI (5678) and Postgres (5432), both bound to loopback only
- Postgres healthcheck with n8n waiting on `service_healthy`
- Named volumes for both n8n and PostgreSQL
- Environment variables configured for development
- An Ollama credential pointing at the host's model server
- Lab model variants built from the Modelfiles in `models/`

## Files

1. `compose.yaml` - Complete Docker Compose configuration for n8n and PostgreSQL
2. `.env` - Environment variables for the services (gitignored)
3. `.env.example` - Template for `.env` with empty secret values
4. `init-scripts/01-init-db.sql` - Postgres init script directory mount
5. `test-setup.sh` - Verification script for the running stack (15 checks)
6. `models/` - Modelfiles for the lab model variants
7. `config/ollama/sh.brew.ollama.plist` - Launchd plist for the model server
8. `scripts/` - Helper scripts for driving the n8n REST API

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
`/healthz`, that n8n is backed by PostgreSQL rather than SQLite, that the
owner account exists, that the Ollama credential is stored and that the n8n
container can reach the host's model server, and that the lab model variants
are built with a 16,384 token context window.

## What was completed in Phase 1

All six steps of PLAN.md Phase 1 are done.

| Step | Result |
| --- | --- |
| `compose.yaml`, `.env`, `.env.example` | Done. `n8nio/n8n:1.54.0` and `postgres:16-alpine` |
| n8n settings | Done. `DB_TYPE=postgresdb`, the `DB_POSTGRESDB_*` prefix, `DB_POSTGRESDB_SSL_ENABLED` left unset |
| Postgres healthcheck, named volumes | Done. n8n waits on `service_healthy` |
| Start the stack, open the editor, create the owner account | Done |
| Ollama credential at `http://host.docker.internal:11434` | Done. The credential test returns "Connection successful!" |
| Modelfiles in `models/`, build the lab variants | Done. `lab-llama3.1-8b` and `lab-mistral-small3.2-24b` |

### Owner account

n8n seeds a placeholder owner row, so an owner account still has to be created
before the editor can be used. It was created through the API:

```bash
curl -X POST http://localhost:5678/rest/owner/setup \
  -H 'Content-Type: application/json' \
  -d '{"email":"owner@lab.local","firstName":"Lab","lastName":"Owner","password":"<your password>"}'
```

n8n's password policy requires 8 to 64 characters, at least one digit and at
least one uppercase letter.

### Ollama credential

The credential type is `ollamaApi` and it has one field, `baseUrl`. The n8n
container reaches the host's model server through `host.docker.internal`:

```bash
curl -X POST http://localhost:5678/rest/credentials \
  -H 'Content-Type: application/json' -b cookies.txt \
  -d '{"name":"Ollama (host)","type":"ollamaApi","data":{"baseUrl":"http://host.docker.internal:11434"}}'
```

Test it with `POST /rest/credentials/test` using the same payload. A correct
setup returns `{"status":"OK","message":"Connection successful!"}`.

### Lab model variants

```bash
ollama create lab-llama3.1-8b -f models/lab-llama3.1-8b.Modelfile
ollama create lab-mistral-small3.2-24b -f models/lab-mistral-small3.2-24b.Modelfile
```

Both variants reuse the base model's weights, so they add no disk space. Both
serve a 16,384 token context, visible in `ollama ps` after the model has
answered a request.

### The smoke-test workflow

`scripts/make_smoke_workflow.py` builds a workflow that runs the
`lab-llama3.1-8b` variant through the credential and returns `OLLAMA_OK`. It
proves the whole path at once: n8n, the credential, the host's model server,
the model, and the answer coming back.

```bash
python3 scripts/make_smoke_workflow.py <credential-id> /tmp/wf.json
curl -X POST http://localhost:5678/rest/workflows -H 'Content-Type: application/json' \
  -b cookies.txt -d @/tmp/wf.json
```

To read an execution's output back, n8n stores run data in a flattened
format. `scripts/show_execution.py` resolves it:

```bash
curl -s "http://localhost:5678/rest/executions/<id>?includeData=true" -b cookies.txt -o exec.json
python3 scripts/show_execution.py exec.json
```

## The model server

Ollama runs natively on the host. Its configuration comes from a launchd
plist, and the lab uses its own so that two settings are present:

```bash
brew services start ollama --file=config/ollama/sh.brew.ollama.plist
```

- `OLLAMA_MAX_LOADED_MODELS=1` - only one model resident at a time. The 24B
  variant needs 15 GB and the 8B needs 6 GB, and they cannot both stay
  resident on this 32 GB machine. Without this setting, Metal fails with
  `Insufficient Memory` and the model server is killed.
- `OLLAMA_NO_CLOUD=1` - no prompt can reach Ollama's cloud services.

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

## Known deviation from PLAN.md

PLAN.md section 4 lists the n8n image as `docker.n8n.io/n8nio/n8n:2.41.6`.
This phase uses `n8nio/n8n:1.54.0`, as specified for the Phase 1 build. The
two are not interchangeable: the database configuration differs (`DB_TYPE`
and the `DB_POSTGRESDB_*` prefix behave as described above on 1.54.0), so the
variables in `compose.yaml` must be re-checked before moving to 2.x.

PLAN.md section 9 names the file `compose.yaml`, which is what is used here.

## Directory Structure

```
.
├── compose.yaml
├── .env                    (gitignored)
├── .env.example
├── init-scripts/
│   └── 01-init-db.sql
├── models/
│   ├── lab-llama3.1-8b.Modelfile
│   └── lab-mistral-small3.2-24b.Modelfile
├── config/ollama/
│   └── sh.brew.ollama.plist
├── scripts/
│   ├── make_smoke_workflow.py
│   └── show_execution.py
├── test-setup.sh
├── PHASE1.md
├── START_N8N.md
├── SUMMARY.md
└── GIT_OPERATIONS.md
```

This implementation follows the specifications in PLAN.md Phase 1.