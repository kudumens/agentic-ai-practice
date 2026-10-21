#!/usr/bin/env python3
"""Read an n8n execution's run data and print the node outputs.

n8n stores execution data in a "flatted" format: a JSON list where nested
values are stringified indices into that same list. This script resolves
those references and prints each node's output.

Usage:
    python3 scripts/show_execution.py <execution-json-file>
"""

import json
import sys


def deref(obj, store, depth=0):
    """Resolve flatted references back into plain Python structures."""
    if depth > 20:
        return obj
    if isinstance(obj, list):
        return [deref(item, store, depth + 1) for item in obj]
    if isinstance(obj, dict):
        return {key: deref(val, store, depth + 1) for key, val in obj.items()}
    if isinstance(obj, str) and obj.isdigit() and int(obj) < len(store):
        return deref(store[int(obj)], store, depth + 1)
    return obj


def main() -> int:
    if len(sys.argv) != 2:
        print(__doc__)
        return 1

    with open(sys.argv[1]) as fh:
        payload = json.load(fh)

    data = payload.get("data", payload)
    store = data.get("data")
    if isinstance(store, str):
        store = json.loads(store)
    if not isinstance(store, list):
        print("unexpected execution payload shape:", type(store))
        return 1

    resolved = deref(store, store)

    # n8n's flatted layout puts resultData in a different slot per payload
    # shape, so look for the object that actually carries runData.
    run_data = {}
    for item in resolved:
        if isinstance(item, dict) and isinstance(item.get("runData"), dict):
            run_data = item["runData"]
            break

    for node, runs in run_data.items():
        for run in runs:
            print("NODE:", node)
            error = run.get("error")
            if error:
                message = error.get("message") if isinstance(error, dict) else error
                print("  ERROR:", str(message)[:300])
            for branch in run.get("data", {}).get("main", []) or []:
                for item in branch or []:
                    payload_json = item.get("json", {}) if isinstance(item, dict) else {}
                    if "output" in payload_json:
                        print("  OUTPUT:", repr(payload_json["output"])[:250])
                    if "text" in payload_json:
                        print("  TEXT:", repr(payload_json["text"])[:250])
    return 0


if __name__ == "__main__":
    sys.exit(main())
