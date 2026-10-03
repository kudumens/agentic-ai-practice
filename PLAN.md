# Local n8n AI Agent Lab: Deployment Plan

Date: 2026-10-03
Status: Phase 0 complete. Phase 1 not started.

Confidence tags used throughout: **[Certain]** checked today against this machine or official sources, **[Likely]** strong inference or prior knowledge not re-checked today, **[Guessing]** filling a gap.

## 1. Goal

A local, free, reproducible lab for practicing AI agents in n8n: n8n and its supporting services in Docker, open-weight models (Llama, Mistral) served locally, and a growing set of tools the agents can call (web search, HTTP, code, SQL, vector search, MCP servers).

Out of scope: production hardening, public exposure (webhook tunnels, reverse proxy, TLS), multi-user setup, queue mode and scaling.

## 2. Three things to accept before building

1. **The model server should not run in Docker on this Mac.** [Certain] Docker Desktop on macOS does not pass the Apple GPU through to containers, so Ollama in a container runs on CPU only. n8n's own starter kit tells Mac users to run Ollama on the host and point n8n at `host.docker.internal:11434`. Native Ollama uses Metal on the M1 Max and will be several times faster [Likely on the exact multiple]. Everything else runs in Docker.
2. **Small local models are weak at multi-tool agents.** [Likely] 3B to 8B models pick the wrong tool, invent arguments, and loop once an agent has more than a handful of tools. "Many tools" on one agent is the wrong target. The realistic design is 3 to 6 tools per agent, with an orchestrator routing to sub-agents. Learning where the models break is a large part of the value of this lab.
3. **Context length is the most common silent failure.** [Certain] Ollama's default context window on this machine is 4,096 tokens (Ollama 0.35.1 picks it from available GPU memory, confirmed in its log on 2026-10-03). Tool schemas plus chat history overflow it and the model quietly forgets its tools. Fix it once with lab model variants that carry a larger context (section 5), not in every n8n node and every Python client.

## 3. What this machine can do

Measured today [Certain]:

| Item                                | Value                                                          | Consequence                                                                       |
| ----------------------------------- | -------------------------------------------------------------- | --------------------------------------------------------------------------------- |
| Chip / RAM                          | Apple M1 Max, 32 GB unified                                    | Models up to about 24B parameters at 4-bit fit comfortably                        |
| Free disk                           | 222 GB                                                         | Planned model set needs about 40 GB                                               |
| Docker                              | 29.8.1, Compose v5.5.1                                         | Ready, nothing to install                                                         |
| Docker VM allocation                | 5 CPUs, about 7.75 GB RAM                                      | Reduced from 15.6 GB and confirmed. Leaves room for the models                    |
| System timezone                     | `Africa/Accra` (GMT+0, no daylight saving)                     | Used for `GENERIC_TIMEZONE` and `TZ`                                              |
| Ollama                              | 0.35.1 via Homebrew, running as a service on `127.0.0.1:11434` | Installed in Phase 0. Uses Metal on the M1 Max with 21.3 GiB of GPU-usable memory |
| Ports 5678, 11434, 5432, 6333, 8080 | All free                                                       | No conflicts                                                                      |
| This folder                         | Git repository, remote `kudumens/agentic-ai-practice`          | Work on branches in worktrees, merged through pull requests                       |

Memory budget [Likely]: macOS and apps about 6 GB, Docker VM 8 GB, leaving about 18 GB for one loaded model. That fits one 24B model or two smaller ones, not both.

## 4. Architecture

```text
 macOS host (M1 Max, Metal GPU)
 ┌────────────────────────────────────────────────────────────┐
 │  Ollama (native)  :11434   models: Llama, Mistral, embed   │
 │        ▲                                                   │
 │        │ http://host.docker.internal:11434                 │
 │  ┌─────┴──────────────── Docker network: lab ───────────┐  │
 │  │  n8n :5678 ──► postgres :5432  (n8n DB, chat memory) │  │
 │  │    │      ──► task-runners     (Code node JS/Python) │  │
 │  │    │      ──► qdrant :6333     (vector store, RAG)   │  │
 │  │    │      ──► searxng :8080    (free web search)     │  │
 │  │    └──────►  MCP servers       (extra tools, Phase 5)│  │
 │  └──────────────────────────────────────────────────────┘  │
 │  Browser ──► http://localhost:5678  (loopback only)        │
 └────────────────────────────────────────────────────────────┘
```

### Services

| Service      | Image (pinned)                     | Phase | Purpose                                                                                                               |
| ------------ | ---------------------------------- | ----- | --------------------------------------------------------------------------------------------------------------------- |
| n8n          | `docker.n8n.io/n8nio/n8n:2.41.6`   | 1     | Workflow engine and agent builder. 2.41.6 is the stable release as of 2026-10-02 [Certain]                            |
| postgres     | `postgres:16-alpine`               | 1     | n8n database, agent chat memory, and a practice database for SQL tools. Same image the n8n starter kit uses [Certain] |
| task-runners | `n8nio/runners:2.41.6`             | 3     | Runs Code node JavaScript and native Python in a sidecar. Version must match n8n exactly [Certain]                    |
| qdrant       | `qdrant/qdrant` (pin at install)   | 4     | Vector store for RAG, with a dashboard at `:6333/dashboard`                                                           |
| searxng      | `searxng/searxng` (pin at install) | 3     | Self-hosted metasearch, no API key. JSON output must be enabled in its settings [Likely]                              |
| Ollama       | native, not Docker                 | 0     | Model server with Metal acceleration                                                                                  |

### Why not use the n8n self-hosted AI starter kit as is

It is the right reference and this plan copies its structure, but it uses `latest` tags, ships placeholder secrets, imports demo workflows, and its Ollama profiles (CPU, NVIDIA, AMD) do not apply to Apple Silicon [Certain]. A small compose file of our own is easier to understand and to change.

### Considered and rejected

- **Ollama in Docker**: CPU only on macOS, see section 2.
- **Docker Model Runner**: built into Docker Desktop, runs models on the host and serves OpenAI and Ollama compatible APIs at `http://model-runner.docker.internal` [Certain]. Viable, but n8n has dedicated Ollama nodes, and I could not confirm Metal acceleration from the docs today. Keep as a fallback.
- **pgvector instead of Qdrant**: one container fewer, but Qdrant has a dashboard that makes RAG easier to learn. Either works.
- **Open WebUI**: n8n's Chat Trigger already gives a chat interface. Not needed.

## 5. Models

All tags below exist in the Ollama library with the tools capability [Certain]. Sizes are approximate [Likely].

| Model                  | Size   | Role                                                                   |
| ---------------------- | ------ | ---------------------------------------------------------------------- |
| `llama3.2:3b`          | 2 GB   | Fast smoke tests. Expect tool-calling failures                         |
| `llama3.1:8b`          | 5 GB   | Llama baseline for tool calling                                        |
| `mistral:7b`           | 4.5 GB | Mistral baseline                                                       |
| `mistral-nemo:12b`     | 7 GB   | Mid-size Mistral, larger context                                       |
| `mistral-small3.2:24b` | 15 GB  | Main agent model. Best Mistral that fits in 32 GB, tools and vision    |
| `qwen3:14b`            | 9 GB   | Not Llama or Mistral, but a useful benchmark for tool calling [Likely] |
| `nomic-embed-text`     | 0.3 GB | Embeddings for RAG                                                     |

`llama3.3:70b` (about 43 GB) does not fit. Ollama's tools page also lists newer agent-tuned models (for example `qwen3.6`, `granite4.1`) worth trying once the basics work.

Optional comparison: free hosted tiers (Groq for large Llama models, Mistral's own API, OpenRouter free models) show how a 70B-class model handles the same agent [Likely that these tiers still exist, verify]. Prompts leave the machine when you use them.

### Lab model variants

Agents use named variants of the models, built with Ollama Modelfiles, instead of the base tags. Each variant fixes the context window, so every client gets the same setting: n8n nodes, Python agents, and the OpenAI-compatible endpoint, which has no per-request context option [Likely].

The Modelfiles live in `models/` in this repository, one per variant:

```text
# models/lab-llama3.1-8b.Modelfile
FROM llama3.1:8b
PARAMETER num_ctx 16384
```

Build with `ollama create lab-llama3.1-8b -f models/lab-llama3.1-8b.Modelfile`. A variant reuses the base model's weights, so it adds no disk space [Likely].

| Variant                    | Base                   | Context |
| -------------------------- | ---------------------- | ------- |
| `lab-llama3.1-8b`          | `llama3.1:8b`          | 16,384  |
| `lab-mistral-small3.2-24b` | `mistral-small3.2:24b` | 16,384  |

Rules:

- Context costs memory. The 24B variant at 16,384 must still show `100% GPU` in `ollama ps`. If it does not, drop that variant to 12,288 [Guessing on where the limit falls].
- No `SYSTEM` prompt in a Modelfile. Agent instructions belong in the n8n workflow or the Python code, where each agent's prompt is visible and versioned. A prompt baked into the model is applied silently to every agent that uses it.
- Name every variant `lab-*` so variants are easy to tell apart from base models in `ollama list`.

## 6. Security rules for the lab

- Publish every port on loopback only, for example `127.0.0.1:5678:5678`. Nothing reachable from the network.
- Generate real secrets (`openssl rand -hex 32`) for the Postgres password, `N8N_ENCRYPTION_KEY` and the runner auth token. Keep them in `.env`, which is gitignored. Commit `.env.example` with empty values.
- Back up `N8N_ENCRYPTION_KEY`. Without it, saved credentials cannot be decrypted [Certain].
- Mount only `./shared` into n8n. Never the home directory.
- An agent that reads web pages and can also run code or write files can be steered by text in those pages (prompt injection). Keep web search and write-capable tools on separate agents until you understand the risk.
- Pin image versions. Upgrade deliberately.
- Never send training data to a rented cloud GPU. Fine-tuning, if done at all, runs on this machine (Phase 8).

## 7. Phases

Each phase ends with a check. Do not start the next phase until the check passes.

### Phase 0: Host preparation

1. `git init` in this folder. Add `.gitignore` covering `.env`, `backups/`, `shared/`.
2. Docker Desktop memory reduced to 8 GB. Done.
3. Install Ollama natively (`brew install ollama` then `brew services start ollama`, or the app from ollama.com). This is the only new host dependency, needed for GPU inference.
4. Pull `llama3.1:8b`, `mistral-small3.2:24b`, `nomic-embed-text`. Add the others later.
5. Send a chat request with a `tools` array straight to `http://localhost:11434/api/chat`.

Check: the model returns a structured tool call, and `ollama ps` shows it running on GPU.

Result, 2026-10-03: passed. Both chat models chose `get_weather` with `{"city": "Accra", "unit": "celsius"}` from a choice of two tools, at 8,192 context and temperature 0:

| Model                  | Memory loaded | Processor | Generation speed | First call including load |
| ---------------------- | ------------- | --------- | ---------------- | ------------------------- |
| `llama3.1:8b`          | 5.3 GB        | 100% GPU  | 42.9 tokens/s    | 5 s                       |
| `mistral-small3.2:24b` | 14 GB         | 100% GPU  | 14.0 tokens/s    | 19 s                      |

`nomic-embed-text` returns 768-dimension embeddings. Qdrant collections in Phase 4 must use that size.

### Phase 1: Core stack

1. Write `compose.yaml` with `postgres` and `n8n`, plus `.env` and `.env.example`.
2. n8n settings [Certain unless noted]: `DB_TYPE=postgresdb` and the `DB_POSTGRESDB_*` variables, `N8N_ENCRYPTION_KEY`, `GENERIC_TIMEZONE=Africa/Accra`, `TZ=Africa/Accra`, `N8N_ENFORCE_SETTINGS_FILE_PERMISSIONS=true`, `N8N_DIAGNOSTICS_ENABLED=false`, `N8N_PERSONALIZATION_ENABLED=false`, `N8N_DEFAULT_BINARY_DATA_MODE=filesystem`.
3. Postgres healthcheck, with n8n waiting on it. Named volumes for both.
4. `docker compose up -d`, open `http://localhost:5678`, create the owner account.
5. Create an Ollama credential with base URL `http://host.docker.internal:11434`.
6. Write the Modelfiles in `models/` and build the lab variants (section 5).

Check: the credential test passes, and a workflow survives `docker compose down` followed by `up`. Each lab variant shows its context of 16,384 in `ollama ps` after a request to the native API, and again after a request to `http://localhost:11434/v1/chat/completions`.

If the credential test is refused: Ollama may be listening on loopback only. Docker Desktop for Mac normally still reaches it [Likely]. The fallback is setting `OLLAMA_HOST=0.0.0.0:11434` for Ollama, which also exposes it to the local network, so prefer not to.

### Phase 2: First agent

1. Chat Trigger, AI Agent, Ollama Chat Model (`lab-llama3.1-8b`), Simple Memory.
2. Leave the context length option in the model node unset, so the variant's 16,384 applies.
3. Add two tools: Calculator and Wikipedia.
4. Read the execution log to see each tool call and its arguments.
5. Swap the model for `lab-mistral-small3.2-24b` and for `llama3.2:3b`, rerun the same prompts, and note the differences.

Check: the agent picks the correct tool for ten test prompts, and you can explain the failures of the small model.

### Phase 3: Tool expansion

Add one tool at a time and test before adding the next.

1. HTTP Request Tool against a free public API.
2. Sub-workflow as a tool (Call n8n Workflow Tool). This is the main pattern for custom tools.
3. Add the `task-runners` sidecar, then a Code Tool. Settings [Certain]: on n8n `N8N_RUNNERS_MODE=external`, `N8N_RUNNERS_BROKER_LISTEN_ADDRESS=0.0.0.0`, `N8N_RUNNERS_AUTH_TOKEN`, `N8N_NATIVE_PYTHON_RUNNER=true`. On the runner `N8N_RUNNERS_TASK_BROKER_URI=http://n8n:5679` and the same token. `N8N_RUNNERS_ENABLED` is deprecated in 2.x and not needed.
4. Add `searxng` with JSON output enabled, then the SearXNG Tool for web search.
5. Create a `playground` database in Postgres with sample data, then a Postgres Tool for SQL. Use a read-only database user.
6. Replace Simple Memory with Postgres Chat Memory so conversations persist.
7. Optional: `N8N_COMMUNITY_PACKAGES_ALLOW_TOOL_USAGE=true` so community nodes can be used as tools [Likely, verify the variable name at install].

Check: one agent with five tools answers a question that needs web search plus calculation, and chat history survives a restart.

### Phase 4: RAG

1. Add `qdrant` to the compose file.
2. Ingestion workflow: read files from `./shared`, extract text from PDF and Word files with the Extract From File node, split, embed with `nomic-embed-text` (Embeddings Ollama), store in Qdrant.
3. Give the agent the Qdrant Vector Store as a retrieval tool.

Check: the agent answers from your documents and says so when the answer is not in them.

RAG is how agents learn the content of your documents. Fine-tuning (Phase 8) is not a substitute: it changes how a model behaves, not what facts it reliably knows [Likely].

### Phase 5: MCP

1. MCP Client Tool node: connect the agent to an external MCP server. n8n connects over SSE or streamable HTTP, not stdio [Likely for the client, Certain for the server trigger], so pick servers with an HTTP transport or run them behind a gateway container.
2. MCP Server Trigger node: expose your own n8n workflows as MCP tools, then call them from another client.

Check: the agent lists and calls tools from at least one MCP server, and one n8n workflow is callable as an MCP tool.

### Phase 6: Multi-agent and evaluation

1. Orchestrator agent with sub-agents as tools (AI Agent Tool node), each sub-agent owning 3 to 5 tools.
2. Tool search: store tool descriptions in Qdrant and pick the 3 to 5 most relevant for each request before calling the agent. This copies how the cloud platforms handle large tool sets (see README).
3. A fixed prompt set stored in a data table, run against each model, with results logged for comparison. Log every tool call with its arguments and whether it was correct; Phase 8 trains on this log.
4. Try n8n's built-in evaluation features against that prompt set [Likely available in 2.x, verify].

Check: a written comparison of which model handles which task, with failure examples.

## 8. Operations

| Task              | Command or approach                                                                        |
| ----------------- | ------------------------------------------------------------------------------------------ |
| Start, stop       | `docker compose up -d`, `docker compose down`                                              |
| Logs              | `docker compose logs -f n8n`                                                               |
| Back up workflows | `docker compose exec n8n n8n export:workflow --all --output=/data/shared/backup/`          |
| Back up database  | `docker compose exec postgres pg_dump -U <user> n8n > backups/n8n.sql`                     |
| Upgrade           | Change the tag on `n8n` and `task-runners` together, read the release notes, back up first |
| Destroy all data  | `docker compose down -v`. Irreversible, deletes the volumes                                |
| Free model RAM    | `ollama stop <model>`                                                                      |

## 9. Planned file layout

```text
n8n/
├── README.md            project overview and hardware requirements
├── PLAN.md              this file
├── compose.yaml         all Docker services
├── .env                 real secrets, gitignored
├── .env.example         variable names only, committed
├── .gitignore
├── models/              Modelfiles for the lab variants
├── searxng/settings.yml enables JSON output
├── shared/              mounted into n8n at /data/shared
├── backups/             gitignored
├── agents/              Python agents, Phase 7 only
└── training/            fine-tuning data and adapters, Phase 8 only, gitignored
```

## 10. Decisions

| #   | Decision                                       | Outcome                                             |
| --- | ---------------------------------------------- | --------------------------------------------------- |
| 1   | Ollama native on the host instead of in Docker | Accepted 2026-10-03                                 |
| 2   | Reduce Docker Desktop memory to 8 GB           | Done and confirmed 2026-10-03                       |
| 3   | Timezone                                       | `Africa/Accra` (GMT+0), matches the system setting  |
| 4   | Qdrant or pgvector for RAG                     | Open. Recommendation: Qdrant. Needed at Phase 4     |
| 5   | Use free hosted model tiers for comparison     | Open. Optional, later. Data leaves the machine      |
| 6   | Python agents on the host or in a container    | Open. Recommendation: host first. Needed at Phase 7 |

## 11. Phase 7 (later): Python agents on the same infrastructure

The infrastructure is reusable as is. Python agents do not run inside n8n. The Python Code node is a sandbox for short scripts, not a home for agent frameworks [Likely]. They run as a separate project that talks to the same services.

| Service  | How a Python agent uses it                                                                                                                                                                    |
| -------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Ollama   | Native API at `http://localhost:11434`, or the OpenAI-compatible API at `http://localhost:11434/v1` [Likely], which most frameworks (LangGraph, PydanticAI, OpenAI Agents SDK, CrewAI) accept |
| Postgres | Agent state and memory, in its own database                                                                                                                                                   |
| Qdrant   | Same collections the n8n RAG workflows fill                                                                                                                                                   |
| SearXNG  | Web search over its JSON API                                                                                                                                                                  |
| n8n      | Workflows exposed through the MCP Server Trigger become tools for Python agents. In the other direction, a Python agent served over HTTP or MCP becomes a tool for n8n agents                 |

Three changes this requires, all small:

1. **Publish Postgres, Qdrant and SearXNG on loopback** (`127.0.0.1:5432`, `127.0.0.1:6333`, `127.0.0.1:8080`) so Python on the host can reach them. Build this into the compose file from Phase 1 so nothing has to change later.
2. **Use the lab model variants.** The OpenAI-compatible API has no per-request context option [Likely], so Python agents must call the `lab-*` variants (section 5), not the base tags, or they fall back to the 4,096 default. The Phase 1 check confirms this works.
3. **Separate project folder** (`agents/` here, or its own repository) with its own virtual environment. `uv` is the usual tool. It is a new dependency and gets installed only when this phase starts.

Running the agents in a container on the `lab` network is the alternative. They would use service names (`postgres`, `qdrant`) and `host.docker.internal:11434` for Ollama. Start on the host because the edit and run loop is faster.

The limits from section 2 apply equally: the same small models make the same tool-calling mistakes regardless of framework.

## 12. Phase 8 (optional, later): Local fine-tuning for tool calling

Purpose: make a small, fast model call your own tools more reliably. This targets the bottleneck from section 2. It is not a way to teach the model your documents; that is RAG (Phase 4).

Start only after Phase 6, because Phase 6 produces both the training data and the yardstick.

1. **Training data.** Take the tool calls logged in Phase 6, keep the correct ones, and fix the incorrect ones by hand. Write them as JSONL in mlx-lm's `tools` format, which holds messages together with the tool definitions [Certain]. Keep a separate set of prompts back for testing. A few hundred examples is a reasonable start [Guessing].
2. **Tooling.** Apple's `mlx-lm` library, which supports LoRA and QLoRA on Apple Silicon for Llama, Mistral and Qwen models [Certain]. Install it with `uv` in its own environment under `training/` when the phase starts. It is a new dependency.
3. **Base weights.** Training needs the model in Hugging Face format, downloaded separately from the Ollama copy. Ollama's GGUF files cannot be trained directly [Likely]. Budget about 16 GB of disk per 8B model [Likely].
4. **Training.** Start with an 8B model. The mlx-lm documentation shows Mistral 7B training on an M1 Max with 32 GB at about 250 tokens per second, using batch size 1 and 4 trained layers [Certain]. Stop Ollama models and Docker while training to free memory. A 24B model is a strain on 32 GB; do not plan on it [Likely].
5. **Export.** Fuse the adapter into the model and export to GGUF with `mlx_lm.fuse`, which supports Llama and Mistral at 16-bit [Certain]. Then build an Ollama model from it with a Modelfile (`FROM ./fused.gguf` plus `PARAMETER num_ctx 16384`) named `lab-llama3.1-8b-tools`. Quantize it to 4-bit during `ollama create` so it runs at the speed of the base model [Likely, verify the flag at the time].
6. **Data handling.** Training data and adapters stay under `training/`, which must be gitignored before any data is written there. If the data includes confidential material, it never leaves this machine (section 6).

Check: on the held-back prompts, the tuned 8B model makes fewer tool-call errors than the base 8B model. Compare it with the 24B model as well. If it beats neither, keep the 24B model and drop the tuned one.

## 13. Known gaps in this plan

- No compose file has been written or run. Every setting above is from documentation, not from a working stack on this machine.
- Model sizes in section 5 are approximate. The Ollama default context length is now measured (section 2).
- Lab variants: that the OpenAI-compatible endpoint honors a Modelfile's `num_ctx` is unverified until the Phase 1 check runs.
- Phase 8: how much fine-tuning helps tool calling, the exact `ollama create` quantize option, and the memory needed beyond 8B models are unverified.
- SearXNG, Qdrant and MCP node details were not re-checked against current docs. Verify at the start of their phases.
- Docker Model Runner's GPU use on Apple Silicon is unconfirmed.
- Phase 7 is from prior knowledge. Ollama's OpenAI-compatible endpoint and its context-length behavior were not re-checked today.

## 14. Sources checked on 2026-10-03

- n8n starter kit compose and env example: <https://github.com/n8n-io/self-hosted-ai-starter-kit>
- n8n Docker install: <https://docs.n8n.io/deploy/host-n8n/install-options/install-with-docker>
- n8n task runners: <https://docs.n8n.io/deploy/host-n8n/configure-n8n/set-up-task-runners>
- n8n MCP nodes: <https://docs.n8n.io/integrations/builtin/core-nodes/n8n-nodes-langchain.mcptrigger> and <https://docs.n8n.io/integrations/builtin/core-nodes/n8n-nodes-langchain.mcpclient>
- n8n versions: npm dist-tags and Docker Hub tags for `n8nio/n8n` and `n8nio/runners`
- Ollama model library: <https://ollama.com/search?c=tools> and the individual model tag pages
- Docker Model Runner: <https://docs.docker.com/ai/model-runner/> and <https://docs.docker.com/ai/model-runner/api-reference/>
- Ollama Modelfile reference: <https://docs.ollama.com/modelfile>
- mlx-lm LoRA and QLoRA: <https://github.com/ml-explore/mlx-lm/blob/main/mlx_lm/LORA.md>
