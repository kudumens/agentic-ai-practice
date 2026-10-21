#!/bin/bash
#
# Phase 1 verification for the local n8n + PostgreSQL lab.
#
# Verifies, in order:
#   1. Docker + Docker Compose are available
#   2. compose.yaml is syntactically valid
#   3. Both containers are running (and Postgres is healthy)
#   4. PostgreSQL accepts connections and is reachable from the n8n container
#   5. n8n answers its health endpoint
#   6. n8n is backed by PostgreSQL (not SQLite)
#   7. The instance owner account has been created
#   8. The Ollama credential exists and the n8n container can reach Ollama
#   9. The lab model variants are built and serve a 16,384 token context
#
set -u

# Docker Compose v2 is the plugin form (`docker compose`). The standalone
# `docker-compose` binary is the deprecated v1 form and is not always present.
COMPOSE="${COMPOSE:-}"
if [ -z "$COMPOSE" ]; then
    if docker compose version > /dev/null 2>&1; then
        COMPOSE="docker compose"
    elif command -v docker-compose > /dev/null 2>&1; then
        COMPOSE="docker-compose"
    else
        echo "Error: docker compose could not be found"
        exit 1
    fi
fi

FAILURES=0

pass() { echo "  PASS: $1"; }
fail() { echo "  FAIL: $1"; FAILURES=$((FAILURES + 1)); }

echo "Testing n8n setup..."

# 1. Tooling -------------------------------------------------------------
if ! docker info > /dev/null 2>&1; then
    echo "Error: Docker daemon is not running"
    exit 1
fi

echo "Docker and docker compose are available and working correctly."

# 2. Compose config ------------------------------------------------------
echo "Testing docker compose configuration..."
if $COMPOSE config > /dev/null 2>&1; then
    pass "compose.yaml configuration is valid"
else
    fail "compose.yaml has issues"
    exit 1
fi

# 3. Container state -----------------------------------------------------
echo "Testing container state..."
if $COMPOSE ps --status running --services 2>/dev/null | grep -qx "postgres"; then
    pass "postgres container is running"
else
    fail "postgres container is not running"
fi

if $COMPOSE ps --status running --services 2>/dev/null | grep -qx "n8n"; then
    pass "n8n container is running"
else
    fail "n8n container is not running"
fi

PG_HEALTH=$($COMPOSE ps postgres 2>/dev/null | grep -c "(healthy)")
if [ "$PG_HEALTH" -ge 1 ]; then
    pass "postgres reports healthy"
else
    fail "postgres is not healthy (n8n may start before the DB is ready)"
fi

# 4. Database connectivity ------------------------------------------------
echo "Testing database connectivity..."
if $COMPOSE exec -T postgres pg_isready -U n8n -d n8n > /dev/null 2>&1; then
    pass "pg_isready reports the database is accepting connections"
else
    fail "pg_isready could not confirm the database is accepting connections"
fi

# n8n must be able to reach Postgres over the compose network.
# The n8n image has no psql/pg_isready client, so probe the port with node.
if $COMPOSE exec -T n8n sh -c \
    'node -e "
const net = require(\"net\");
const host = process.env.DB_POSTGRESDB_HOST || \"postgres\";
const port = Number(process.env.DB_POSTGRESDB_PORT || 5432);
const s = net.connect(port, host, () => { s.end(); process.exit(0); });
s.on(\"error\", () => process.exit(1));
setTimeout(() => process.exit(1), 5000);
"' > /dev/null 2>&1; then
    pass "n8n container can reach postgres over the network"
else
    fail "n8n container cannot reach postgres over the network"
fi

# 5. n8n health endpoint --------------------------------------------------
echo "Testing n8n health endpoint..."
HEALTH=$(curl -fsS http://localhost:5678/healthz 2>/dev/null)
if echo "$HEALTH" | grep -q '"status":"ok"'; then
    pass "n8n health endpoint returned ok"
else
    fail "n8n health endpoint did not return ok (got: ${HEALTH:-no response})"
fi

# 6. Persistence is in PostgreSQL, not SQLite ----------------------------
echo "Testing that n8n persists to PostgreSQL..."
if $COMPOSE exec -T postgres psql -U n8n -d n8n -tAc \
    "select count(*) from information_schema.tables where table_schema='public' and table_name='workflow_entity';" \
    2>/dev/null | grep -q '^1$'; then
    pass "n8n schema (workflow_entity) exists in PostgreSQL"
else
    fail "n8n schema was not found in PostgreSQL"
fi

# n8n-data is a named volume on a Postgres deployment, so a SQLite file there
# would mean n8n silently fell back to SQLite.
if $COMPOSE exec -T n8n sh -c 'test -f /home/node/.n8n/database.sqlite'; then
    fail "database.sqlite found in the n8n data volume - n8n is falling back to SQLite"
else
    pass "no SQLite database file in the n8n data volume - n8n is using PostgreSQL"
fi

# 7. Owner account --------------------------------------------------------
# PLAN.md Phase 1 step 4: create the owner account. n8n seeds a placeholder
# owner row, so the real check is the setup flag it sets afterwards.
echo "Testing owner account..."
OWNER_FLAG=$($COMPOSE exec -T postgres psql -U n8n -d n8n -tAc \
    "select value from settings where key='userManagement.isInstanceOwnerSetUp';" 2>/dev/null | tr -d ' \r\n')
if [ "$OWNER_FLAG" = "true" ]; then
    pass "instance owner account has been created"
else
    fail "owner account has not been set up (isInstanceOwnerSetUp=${OWNER_FLAG:-unset})"
fi

# 8. Ollama credential ----------------------------------------------------
# PLAN.md Phase 1 step 5: an Ollama credential pointing at the host's
# Ollama server. The n8n container reaches it through host.docker.internal.
echo "Testing Ollama credential..."
CRED_COUNT=$($COMPOSE exec -T postgres psql -U n8n -d n8n -tAc \
    "select count(*) from credentials_entity where type='ollamaApi';" 2>/dev/null | tr -d ' \r\n')
if [ "${CRED_COUNT:-0}" -ge 1 ] 2>/dev/null; then
    pass "Ollama credential exists in the database"
else
    fail "no Ollama credential found (type 'ollamaApi')"
fi

if $COMPOSE exec -T n8n sh -c \
    'node -e "
fetch(\"http://host.docker.internal:11434/\")
  .then((r) => { console.log(r.status); process.exit(r.status === 200 ? 0 : 1); })
  .catch(() => process.exit(1));
"' > /dev/null 2>&1; then
    pass "n8n container can reach Ollama on the host (host.docker.internal:11434)"
else
    fail "n8n container cannot reach Ollama on the host (host.docker.internal:11434)"
fi

# 9. Lab model variants ---------------------------------------------------
# PLAN.md Phase 1 step 6 and section 5: the lab-* Modelfiles are built and
# carry a 16,384 token context window.
if command -v ollama > /dev/null 2>&1; then
    echo "Testing lab model variants..."
    for variant in lab-llama3.1-8b lab-mistral-small3.2-24b; do
        if ollama list 2>/dev/null | awk '{print $1}' | grep -qx "$variant:latest"; then
            pass "$variant is built"
        else
            fail "$variant is not built (run: ollama create $variant -f models/$variant.Modelfile)"
        fi
    done

    # The context window only shows up in `ollama ps` after the model has
    # served a request, so send a tiny one first.
    for variant in lab-llama3.1-8b lab-mistral-small3.2-24b; do
        ollama stop "$variant" > /dev/null 2>&1
    done
    ollama stop "mistral-small3.2:24b" > /dev/null 2>&1
    curl -fsS --max-time 300 http://localhost:11434/api/chat \
        -d "{\"model\":\"lab-llama3.1-8b\",\"messages\":[{\"role\":\"user\",\"content\":\"hi\"}],\"stream\":false}" \
        > /dev/null 2>&1

    # `ollama ps` has no JSON output, and the PROCESSOR column is two words
    # ("100% GPU"), so the context is not at a fixed field index. Look for
    # the value 16384 anywhere in the variant's row instead.
    CTX=$(ollama ps 2>/dev/null | awk '$1 ~ /^lab-llama3.1-8b/ {
        for (i = 1; i <= NF; i++) if ($i == "16384") found = 1
    } END { print (found ? "16384" : "other") }')
    if [ "${CTX:-}" = "16384" ]; then
        pass "lab-llama3.1-8b serves a 16,384 token context window"
    else
        fail "lab-llama3.1-8b context is ${CTX:-unknown}, expected 16384"
    fi
else
    echo "  SKIP: ollama is not installed, skipping lab model variant checks"
fi

echo ""
if [ "$FAILURES" -eq 0 ]; then
    echo "Setup test completed successfully!"
    exit 0
fi

echo "Setup test completed with $FAILURES failure(s)."
exit 1