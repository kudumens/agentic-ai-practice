# Local n8n AI Agent Lab

A private lab for building AI agents that run entirely on one Mac. n8n orchestrates the agents, open-weight models (Llama, Mistral and others) run locally through Ollama, and supporting services give the agents tools: web search, SQL, code execution, document retrieval and MCP servers.

The aim is to learn how to build agents that complete long, multi-step tasks on confidential material without sending anything to a cloud provider.

Status: Phase 1 (n8n and PostgreSQL stack) and Phase 2 (Integration of Search and Code Execution) complete. Ollama and six models are installed and tested, n8n runs against PostgreSQL, and the lab model variants are built. Piston code execution is successfully integrated using a custom entrypoint to overcome Docker Desktop on macOS limitations. The build plan is in [PLAN.md](PLAN.md).

Confidence tags: **[Certain]** checked on 2026-10-03 against this machine or a primary source, **[Likely]** strong inference or third-party figure, **[Guessing]** an estimate that the lab itself still has to measure.

## What it consists of

| Part | Runs in | Purpose |
| --- | --- | --- |
| n8n | Docker | Agent and workflow builder |
| Postgres | Docker | n8n database, agent memory, SQL practice data |
| Redis | Docker | Cache for SearXNG |
| SearXNG | Docker | Web search without an API key |
| Piston | Docker | Code execution for agents (via custom entrypoint) |
| n8n sandbox service | Docker | Sandbox for n8n Assistant (`sandbox-api` and a privileged `sandbox-runner-1`) |
| Ollama | Natively on macOS | Serves the models with GPU acceleration |

Ollama runs outside Docker because Docker Desktop on macOS cannot give containers access to the Apple GPU [Certain].

## Why hardware matters here

An agent works by having the model choose a tool, fill in its arguments, read the result and decide what to do next. Three things limit how well that works, and all three come down to memory:

1. **Model size.** Larger models choose tools and fill in arguments more accurately. A model must fit in memory to run at usable speed.
2. **Context length.** Every tool description, every tool result and the whole conversation must fit in the context window. Longer context costs several more gigabytes on top of the model [Likely].
3. **Speed.** An agent calls the model many times per task. Generation speed follows memory bandwidth, which differs between chips [Likely].

Small errors compound. An agent that makes the right call 95% of the time finishes a 10-step task correctly about 60% of the time. At 98% per call it is about 82% [Certain, arithmetic]. This is why a modest gain in model quality produces a large gain in finished tasks.

On Apple Silicon the GPU shares system memory, so unified memory is the figure that matters. A rough rule of memory needed [Likely]:

```text
model file size + context overhead (2 to 15 GB) + Docker (8 GB) + macOS and apps (about 6 GB)
```

## Minimum requirements

Enough to run the lab and complete the early phases of the plan.

| Resource | Minimum | Notes |
| --- | --- | --- |
| Processor and GPU | Apple Silicon, M1 or later | The GPU is built in. Intel Macs run models on CPU only and are not practical |
| Memory | 16 GB unified | Runs 7B to 8B models (about 5 GB each) with Docker limited to 4 GB |
| Free disk | 30 GB | About 10 GB of models, the rest for Docker images and data [Likely] |
| Software | Recent macOS, Docker Desktop with Compose, Ollama | Check Ollama's current macOS requirement at install |
| Network | Needed for setup only | Downloads images and models. Not needed afterwards unless an agent uses web tools |

On Linux or Windows the equivalent is an NVIDIA GPU with at least 8 GB of video memory. There Ollama can run inside Docker with GPU access [Likely].

## Keeping everything local and confidential

Local models alone do not make the lab confidential. Each of these sends data off the machine:

| Component | What leaves the machine | How to prevent it |
| --- | --- | --- |
| Web search (SearXNG) | The search query, which an agent may build from confidential text | Leave web search off agents that handle confidential material |
| HTTP and remote MCP tools | Whatever the agent sends to them | Use only local tools on confidential agents |
| Ollama cloud models | The entire prompt | Use only locally downloaded models. Avoid any model tagged `cloud` [Certain that such tags exist] |
| Free hosted model tiers | The entire prompt | Never use with confidential data |
| Fine-tuning on a rented cloud GPU | All the training data | Fine-tune locally with MLX (PLAN Phase 8), or not at all |
| n8n telemetry | Usage data | `N8N_DIAGNOSTICS_ENABLED=false` [Certain]. Also disable version checks and template fetching at install [Likely] |

Other rules already in the plan: every port is bound to loopback only, secrets stay in a gitignored `.env`, and only the `shared/` folder is mounted into n8n. Turn on FileVault so data and backups are encrypted at rest.

The simplest safe pattern is two sets of agents: one with web access for public research, one with no network tools for confidential work.

## Before buying anything

The tool counts above are estimates. Buying on them alone would be a mistake. The plan produces the evidence:

1. Complete Phases 0 to 5 on the current machine.
2. In Phase 6, run a fixed set of tasks against each local model and record where each one fails: wrong tool, false arguments, lost context, or too slow.
3. Run the same tasks, using non-confidential prompts only, against a 70B or larger model on a free hosted tier or a borrowed machine.
4. Buy if the larger model clears the failures that matter. If the failures are caused by workflow design, more memory will not help.

That record is the justification for the purchase.

## Sources

- Ollama model library, sizes and capabilities: <https://ollama.com/library>
- MacBook Pro M5 Pro and M5 Max specifications: <https://www.macworld.com/article/2942089/macbook-pro-m5-pro-max-release-specs-price.html>
- Maxed configuration price: <https://appleinsider.com/articles/26/03/03/m5-macbook-pro-maxxed-out-will-cost-you-7349-but-could-have-been-a-lot-worse>
- M5 bandwidth and speed estimates (third party): <https://www.promptquorum.com/local-llms/apple-silicon-m5-local-llm>
- Tool count and selection accuracy: <https://arxiv.org/html/2605.24660v1>
- Anthropic tool search, limits and accuracy guidance: <https://platform.claude.com/docs/en/agents-and-tools/tool-use-search-tool>
- OpenAI tool search (Azure documentation): <https://learn.microsoft.com/en-us/azure/foundry/openai/how-to/tool-search>
- OpenAI 128-tool limit (Azure quotas): <https://learn.microsoft.com/en-us/azure/foundry/openai/quotas-limits>
- Gemini function calling: <https://ai.google.dev/gemini-api/docs/function-calling>
- Cursor 40-tool limit: <https://forum.cursor.com/t/tools-limited-to-40-total>
- GPT-6 Astra coverage: <https://www.marktechpost.com/2026/09/29/openai-launches-dots-always-on-gpt-6-astra-agents-that-work-from-their-own-cloud-computers/amp/>
- Tool use benchmark in realistic settings: <https://arxiv.org/html/2604.06185>
- n8n self-hosted AI starter kit: <https://github.com/n8n-io/self-hosted-ai-starter-kit>
- mlx-lm LoRA and QLoRA on Apple Silicon: <https://github.com/ml-explore/mlx-lm/blob/main/mlx_lm/LORA.md>
