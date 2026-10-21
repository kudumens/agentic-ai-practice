# How to Start n8n Services

## Prerequisites
- Docker and Docker Compose installed and running

## Starting the Services

1. **Navigate to the project directory**:
   ```bash
   cd /Users/richardadjei-mensah/Documents/LOCAL/CODE-PLAYGROUND/n8n/.claude/worktrees/phase-1-n8n-setup
   ```

2. **Create `.env`** (only needed the first time):
   ```bash
   cp .env.example .env
   # fill in N8N_USER_MANAGEMENT_JWT_SECRET, N8N_ENCRYPTION_KEY, POSTGRES_PASSWORD
   ```

3. **Start the services in detached mode**:
   ```bash
   docker compose up -d
   ```
   Compose waits for the Postgres healthcheck to pass before starting n8n.

4. **Check that services are running**:
   ```bash
   docker compose ps
   ```
   n8n takes roughly 20-30 seconds to run its database migrations on first
   start. It is ready when `http://localhost:5678/healthz` returns
   `{"status":"ok"}`.

## Accessing n8n

Once the services are running, access n8n at:
- **URL**: http://localhost:5678
- **Login**: the owner account you create on first visit

On first load n8n asks you to create the owner account. The email and password
you enter there become the n8n login. The account is stored in PostgreSQL, so it
survives a `docker compose down` / `up` cycle.

## Verifying the Setup

```bash
./test-setup.sh
```

This checks container state, Postgres health and reachability from the n8n
container, the n8n health endpoint, and that n8n is using PostgreSQL rather
than SQLite.

## Stopping the Services

To stop the services (data is preserved):
```bash
docker compose down
```

To stop the services and delete all data, including the database:
```bash
docker compose down -v
```

## Useful Commands

- **View logs**: `docker compose logs -f`
- **Follow n8n logs only**: `docker compose logs -f n8n`
- **Check configuration**: `docker compose config`
- **Check n8n health**: `curl -fsS http://localhost:5678/healthz`
- **Check the database**: `docker compose exec postgres psql -U n8n -d n8n`
- **List n8n tables**: `docker compose exec postgres psql -U n8n -d n8n -c '\dt'`