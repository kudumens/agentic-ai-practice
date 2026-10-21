#!/usr/bin/env python3
"""Build the Phase 1 smoke-test workflow JSON for n8n.

The workflow exercises the whole Phase 1 path: n8n -> the Ollama credential
-> the Ollama model server on the host -> back into n8n.

Usage:
    python3 scripts/make_smoke_workflow.py <credential-id> <output-file>
"""

import json
import sys

TRIGGER_NAME = "When clicking 'Execute workflow'"


def build(credential_id: str) -> dict:
    return {
        "name": "Phase 1: Ollama smoke test",
        "nodes": [
            {
                "parameters": {},
                "id": "11111111-1111-4111-8111-111111111111",
                "name": TRIGGER_NAME,
                "type": "n8n-nodes-base.manualTrigger",
                "typeVersion": 1,
                "position": [200, 300],
            },
            {
                "parameters": {
                    "promptType": "define",
                    "text": "Reply with exactly: OLLAMA_OK",
                    "options": {},
                },
                "id": "22222222-2222-4222-8222-222222222222",
                "name": "AI Agent",
                "type": "@n8n/n8n-nodes-langchain.agent",
                "typeVersion": 1.6,
                "position": [460, 300],
            },
            {
                "parameters": {
                    "model": "lab-llama3.1-8b",
                    "options": {},
                },
                "id": "33333333-3333-4333-8333-333333333333",
                "name": "Ollama Chat Model",
                "type": "@n8n/n8n-nodes-langchain.lmChatOllama",
                "typeVersion": 1,
                "position": [460, 520],
                "credentials": {
                    "ollamaApi": {
                        "id": credential_id,
                        "name": "Ollama (host)",
                    }
                },
            },
        ],
        "connections": {
            TRIGGER_NAME: {
                "main": [[{"node": "AI Agent", "type": "main", "index": 0}]]
            },
            "Ollama Chat Model": {
                "ai_languageModel": [
                    [{"node": "AI Agent", "type": "ai_languageModel", "index": 0}]
                ]
            },
        },
        "settings": {"executionOrder": "v1"},
        "active": False,
        "versionId": "00000000-0000-0000-0000-000000000000",
        "meta": {"instanceId": "phase1-smoke-test"},
        "tags": [],
    }


if __name__ == "__main__":
    if len(sys.argv) != 3:
        print(__doc__)
        sys.exit(1)
    cred_id, out_path = sys.argv[1], sys.argv[2]
    with open(out_path, "w") as fh:
        json.dump(build(cred_id), fh, indent=2)
    print(f"workflow written to {out_path}")
