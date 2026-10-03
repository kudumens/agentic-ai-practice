# Local n8n AI Agent Lab

A private lab for building AI agents that run entirely on one Mac. n8n orchestrates the agents, open-weight models (Llama, Mistral and others) run locally through Ollama, and supporting services give the agents tools: web search, SQL, code execution, document retrieval and MCP servers.

The aim is to learn how to build agents that complete long, multi-step tasks on confidential material without sending anything to a cloud provider.

Status: Phase 0 (host preparation) complete. Ollama and three models are installed and tested. The build plan is in [PLAN.md](PLAN.md).

Confidence tags: **[Certain]** checked on 2026-10-03 against this machine or a primary source, **[Likely]** strong inference or third-party figure, **[Guessing]** an estimate that the lab itself still has to measure.

## What it consists of

| Part | Runs in | Purpose |
| --- | --- | --- |
| n8n | Docker | Agent and workflow builder |
| Postgres | Docker | n8n database, agent memory, SQL practice data |
| Qdrant | Docker | Vector store for document retrieval |
| SearXNG | Docker | Web search without an API key |
| Task runners | Docker | Code execution for agents |
| Ollama | Natively on macOS | Serves the models with GPU acceleration |

Ollama runs outside Docker because Docker Desktop on macOS cannot give containers access to the Apple GPU [Certain].

## Why hardware matters here

An agent works by having the model choose a tool, fill in its arguments, read the result and decide what to do next. Three things limit how well that works, and all three come down to memory:

1. **Model size.** Larger models choose tools and fill in arguments more accurately. A model must fit in memory to run at usable speed.
2. **Context length.** Every tool description, every tool result and the whole conversation must fit in the context window. Longer context costs several more gigabytes on top of the model [Likely].
3. **Speed.** An agent calls the model many times per task. Generation speed follows memory bandwidth, which differs between chips [Likely].

Small errors compound. An agent that makes the right call 95% of the time finishes a 10-step task correctly about 60% of the time. At 98% per call it is about 82% [Certain, arithmetic]. This is why a modest gain in model quality produces a large gain in finished tasks.

On Apple Silicon the GPU shares system memory, so unified memory is the figure that matters. A rough rule for memory needed [Likely]:

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

At this level expect one to three tools per agent and single-step tasks [Guessing].

## Hardware tiers

Model sizes are the download sizes listed in the Ollama library [Certain]. The "tools per agent" column is an estimate [Guessing]. Phase 6 of the plan measures it properly.

"Tools per agent" here means tools the model sees at once, without tool search. With tool search or sub-agents, any tier can reach many more tools in total.

| Tier | Machine | Memory left for models | Largest practical models | Tools per agent (estimate) |
| --- | --- | --- | --- | --- |
| Minimum | Any Apple Silicon, 16 GB | About 7 GB | `llama3.1:8b` (4.9 GB), `mistral:7b` (4.4 GB) | 1 to 3 |
| Current | M1 Max, 32 GB (this machine) | About 18 GB | `mistral-small3.2:24b` (15 GB). 27B to 30B models (17 to 18 GB) only with Docker trimmed to 6 GB | 3 to 6 |
| Recommended | M5 Max, 64 GB | About 50 GB | 27B to 30B models at 8-bit (30 to 35 GB) with long context. `llama3.3:70b` (43 GB) fits but is tight | 6 to 10 |
| Optimum | M5 Max with 40-core GPU, 128 GB | About 114 GB | `mistral-medium-3.5` 128B (80 GB), `mistral-large` 123B (73 GB), `gpt-oss:120b` (65 GB), `llama3.3:70b` at 8-bit (75 GB), with long context and a second model loaded | 10 to 15 |

Supporting figures:

| Item | Current (M1 Max 32 GB) | Optimum (M5 Max 128 GB) |
| --- | --- | --- |
| Memory bandwidth | 400 GB/s [Likely] | 614 GB/s with the 40-core GPU, 460 GB/s with the 32-core GPU [Likely, third-party] |
| Largest model class | 24B | 120B to 128B |
| 70B model speed | Does not fit | 12 to 18 tokens per second [Likely, third-party estimate, not independently benchmarked] |
| Disk for models | About 40 GB | 300 GB or more for a working set of large models. The M5 Max starts at 2 TB [Likely] |

Notes on buying:

- The M5 Pro tops out at 64 GB and 307 GB/s. Only the M5 Max reaches 128 GB [Likely, Macworld]. For this workload the Max is worth it for the bandwidth even at 64 GB.
- Memory cannot be upgraded after purchase. Disk can be supplemented with external storage, memory cannot.
- A desktop Mac with the same chip and memory performs the same for this work and usually costs less [Likely]. Choose the MacBook only if portability matters.
- Prices: a fully maxed 128 GB, 8 TB MacBook Pro was reported at $7,349 at launch in March 2026, with a further increase reported in June 2026 [Likely]. Check Apple's store for the current price of a 128 GB configuration with less storage.

## How the leading cloud agents handle many tools

They do not show the model hundreds of tools at once. The platforms accept large tool lists, but their own guidance is to keep the list the model actually sees short.

| Platform | Tools accepted in one request | Point where accuracy drops, per the vendor or tool | How it reaches more tools |
| --- | --- | --- | --- |
| Anthropic Claude API | 10,000 with tool search [Certain] | "Claude's ability to pick the right tool degrades once you exceed 30–50 available tools" [Certain, Anthropic docs] | Tool search loads 3 to 5 tools per need. Anthropic recommends always loading only the 3 to 5 most used [Certain] |
| OpenAI API (GPT-5.4 and later, including GPT-6 Astra) | 128 functions in a plain request [Likely] | Groups of tools ideally under 10 functions each [Likely, OpenAI guidance as reported] | Tool search with deferred loading, available since GPT-5.4 [Likely] |
| Google Gemini API | 128 function declarations, 512 in some MCP setups [Likely] | Not found | Not checked |
| Cursor (coding agent) | Sends at most 40 MCP tools to the model [Likely] | Not stated | Hard cap |

What this means:

- **The working number at the frontier is about 30 to 50 tools in view, and 3 to 5 loaded for any one step.** Thousands are reachable only through search.
- **A 2026 study pointed the same way.** A frontier model chose tools more accurately from a short list built for each question (93.1%) than from a fixed list of 5 (87.1%) [Likely, from a summary of the paper].
- **No vendor publishes a reliable tool count for its long-running agents.** GPT-6 Astra, OpenAI's flagship launched in September 2026, is marketed on carrying a task across many tools and interruptions [Likely, press coverage]. I found no figure for how many tools it sees at once.

The same technique works locally. If a local agent sees only the 3 to 5 tools relevant to the current step, chosen by a search over tool descriptions or by an orchestrator routing to specialist sub-agents, then even a 24B model only faces a short list. Building this is part of Phase 6 of the plan.

This changes the case for new hardware. The number of tools is mostly solved by design. Hardware buys the other things a frontier agent has: better reasoning over long multi-step tasks, enough context to hold the task, and the speed to run many steps.

## What more hardware fixes, and what it does not

It fixes:

- **Model quality.** Moving from a 24B to a 70B or 120B model is the largest single improvement available to a local agent.
- **Context length.** Room for many tool descriptions, long documents and long conversations at once.
- **Multiple models.** A large planning model and a small fast model loaded together, plus the embedding model.
- **Local fine-tuning.** Training a model takes far more memory than running it [Likely]. On 32 GB, fine-tuning a 7B to 8B model is practical; Apple's MLX documentation shows it on this exact machine [Certain]. A 24B model is a strain [Likely]. More memory is the only way to fine-tune larger models without sending confidential training data to a cloud GPU. This is a stronger reason for 64 to 128 GB than running models is.

It does not fix:

- **Too many tools on one agent.** Accuracy falls as the tool list grows for every model, including the best cloud models. A 2026 study found that a frontier cloud model chose tools more accurately from a short list tailored to the question than from a fixed one [Likely, from a summary of the paper]. The remedy is design: few tools per agent, an orchestrator that routes to specialist agents, and retrieving only the relevant tools for each request.
- **The gap to cloud models.** A 128 GB laptop runs strong open models, not the equal of the largest hosted ones [Likely]. Expect it to handle hard tasks slowly and with more supervision.
- **Speed at scale.** Large models on a laptop generate at roughly reading speed. A long agent run takes minutes, not seconds [Likely].

## Keeping everything local and confidential

Local models alone do not make the lab confidential. Each of these sends data off the machine:

| Component | What leaves the machine | How to prevent it |
| --- | --- | --- |
| Web search (SearXNG) | The search query, which an agent may build from confidential text | Leave web search off agents that handle confidential material |
| HTTP and remote MCP tools | Whatever the agent sends to them | Use only local tools on confidential agents |
| Ollama cloud models | The entire prompt | Use only locally downloaded models. Avoid any model tagged `cloud` [Certain that such tags exist] |
| Free hosted model tiers | The entire prompt | Never use them with confidential data |
| Fine-tuning on a rented cloud GPU | All the training data | Fine-tune locally with MLX (PLAN Phase 8), or not at all |
| n8n telemetry | Usage data | `N8N_DIAGNOSTICS_ENABLED=false` [Certain]. Also disable version checks and template fetching at install [Likely] |

Other rules already in the plan: every port is bound to loopback only, secrets stay in a gitignored `.env`, and only the `shared/` folder is mounted into n8n. Turn on FileVault so data and backups are encrypted at rest.

The simplest safe pattern is two sets of agents: one with web access for public research, one with no network tools for confidential work.

## Before buying anything

The tool counts above are estimates. Buying on them alone would be a mistake. The plan produces the evidence:

1. Complete Phases 0 to 5 on the current machine.
2. In Phase 6, run a fixed set of tasks against each local model and record where each one fails: wrong tool, wrong arguments, lost context, or too slow.
3. Run the same tasks, using non-confidential prompts only, against a 70B or larger model on a free hosted tier or a borrowed machine.
4. Buy if the larger model clears the failures that matter. If the failures are caused by workflow design, more memory will not help.

That record is the justification for the purchase.

## Sources

- Ollama model library, sizes and capabilities: <https://ollama.com/library>
- MacBook Pro M5 Pro and M5 Max specifications: <https://www.macworld.com/article/2942089/macbook-pro-m5-pro-max-release-specs-price.html>
- Maxed configuration price: <https://appleinsider.com/articles/26/03/03/m5-macbook-pro-maxxed-out-will-cost-you-7349-but-could-have-been-a-lot-worse>
- M5 bandwidth and speed estimates (third party): <https://www.promptquorum.com/local-llms/apple-silicon-m5-local-llm>
- Tool count and selection accuracy: <https://arxiv.org/html/2605.24660v1>
- Anthropic tool search, limits and accuracy guidance: <https://platform.claude.com/docs/en/agents-and-tools/tool-use/tool-search-tool>
- OpenAI tool search (Azure documentation): <https://learn.microsoft.com/en-us/azure/foundry/openai/how-to/tool-search>
- OpenAI 128-tool limit (Azure quotas): <https://learn.microsoft.com/en-us/azure/foundry/openai/quotas-limits>
- Gemini function calling: <https://ai.google.dev/gemini-api/docs/function-calling>
- Cursor 40-tool limit: <https://forum.cursor.com/t/tools-limited-to-40-total/67976>
- GPT-6 Astra coverage: <https://www.marktechpost.com/2026/09/29/openai-launches-dots-always-on-gpt-6-astra-agents-that-work-from-their-own-cloud-computers/amp/>
- Tool use benchmark in realistic settings: <https://arxiv.org/html/2604.06185>
- n8n self-hosted AI starter kit: <https://github.com/n8n-io/self-hosted-ai-starter-kit>
- mlx-lm LoRA and QLoRA on Apple Silicon: <https://github.com/ml-explore/mlx-lm/blob/main/mlx_lm/LORA.md>
