# Elephantasm Integration — Completion Record

**Date:** 2026-03-13
**Implements:** `docs/elephantasm-integration.md` (Phases 1–4)

---

## Summary

Integrated [Elephantasm](https://elephantasm.com) as the deep long-term agentic memory (LTAM) layer in the vendored Hermes agent. The integration follows the same optional, non-fatal, env-var-gated pattern established by Honcho. All five Elephantasm event types are captured via fire-and-forget extraction, and a Memory Pack is injected into the system prompt at session start.

---

## Files Changed

### `hermes-agent/run_agent.py`

**1. Client initialization — `__init__()` (~line 655)**

Added Elephantasm client setup immediately after the Honcho initialization block. Mirrors the Honcho pattern exactly: guarded by `skip_memory`, lazy-imports the SDK, reads `ELEPHANTASM_API_KEY` and `ELEPHANTASM_ANIMA_ID` from env, catches `ImportError` and all other exceptions silently.

```python
self._elephantasm = None
if not skip_memory:
    try:
        from elephantasm import Elephantasm
        ea_api_key = os.getenv("ELEPHANTASM_API_KEY")
        ea_anima_id = os.getenv("ELEPHANTASM_ANIMA_ID")
        if ea_api_key:
            self._elephantasm = Elephantasm(api_key=ea_api_key, anima_id=ea_anima_id)
    except (ImportError, Exception):
        pass  # non-fatal
```

**Why:** Optional feature — agent must function identically without Elephantasm configured or installed.

---

**2. `_elephantasm_extract()` helper method (~line 1444)**

New method on `AIAgent`, placed alongside `_honcho_sync()`. Wraps every extraction call in try/except so a failed event never disrupts the agent loop.

```python
def _elephantasm_extract(self, event_type: str, content: str, **kwargs):
    if not self._elephantasm:
        return
    try:
        self._elephantasm.extract(
            event_type=event_type, content=content,
            session_id=self.session_id, **kwargs,
        )
    except Exception as e:
        logger.debug("Elephantasm extract failed (non-fatal): %s", e)
```

**Why:** Fire-and-forget design — extractions are lightweight HTTP POSTs. Per-event extraction (vs. batching) gives accurate timestamps and crash resilience at negligible cost.

---

**3. System prompt guidance — `_build_system_prompt()` (~line 1487)**

When `self._elephantasm` is active, appends `ELEPHANTASM_GUIDANCE` to the tool guidance block. This tells the agent it has deep long-term memory and should trust injected memories as its own recollections.

**Why:** The agent needs to know its memories are real and automatically managed, so it doesn't try to manually curate them or distrust the injected context.

---

**4. Memory Pack injection — `run_conversation()` (~line 3308 prefetch, ~3365 bake)**

Two-step process mirroring the Honcho prefetch pattern:

- **Prefetch:** On first turn only (no `conversation_history`), calls `self._elephantasm.inject(query=original_user_message, preset="conversational")` to retrieve a semantically relevant Memory Pack.
- **Bake:** Appends the Memory Pack text to `self._cached_system_prompt` so it's frozen for the session, preserving Anthropic prefix cache stability.

**Why:** One call per session. The `query` parameter enables semantic search so the most relevant memories surface. Freezing the pack in the cached system prompt avoids prefix cache invalidation on subsequent turns.

---

**5. Event extraction — five points throughout the agent loop**

All five Elephantasm event types are captured:

| EventType | Location | What it captures |
|---|---|---|
| `message.in` | After `messages.append(user_msg)` in `run_conversation()` (~line 3330) | User's input (uses `original_user_message`, not the nudge-injected version) |
| `system` | In `_build_assistant_message()` (~line 2509) | Reasoning/CoT/inner monologue from `_extract_reasoning()`. Tagged with `meta={"subtype": "inner_monologue"}` and `importance_score=0.6` |
| `message.out` | In `_build_assistant_message()` (~line 2519) | Agent's response text |
| `tool_call` | In `_execute_tool_calls()` (~line 2985) | Tool name + arguments as JSON. Tagged with `meta={"tool_name": ...}` |
| `tool_result` | In `_execute_tool_calls()` (~line 2991) | Tool output, truncated to 2,000 chars to avoid flooding the event store |

**Why inner monologue is the differentiator:** Most memory systems only see final output. By capturing reasoning tokens (DeepSeek, Qwen, Claude extended thinking, `<think>` blocks), Elephantasm gets insight into *how* the agent thinks, enabling richer synthesis.

**Why all tools are captured:** The Dreamer's synthesis process decides what's important. Better to have complete data than miss something significant.

---

### `hermes-agent/agent/prompt_builder.py`

Added `ELEPHANTASM_GUIDANCE` constant (~line 89), alongside the existing `MEMORY_GUIDANCE`, `SESSION_SEARCH_GUIDANCE`, and `SKILLS_GUIDANCE` constants.

---

### `hermes-agent/pyproject.toml`

- Added `elephantasm = ["elephantasm"]` under `[project.optional-dependencies]`
- Added `"hermes-agent[elephantasm]"` to the `[all]` extras group

**Why optional dependency:** Same pattern as `honcho`. The SDK is only needed when Elephantasm is configured. The `[all]` extra ensures it's installed in the gateway Docker image.

---

### `.env.example`

Documented `ELEPHANTASM_API_KEY` and `ELEPHANTASM_ANIMA_ID` with commented-out examples.

---

### `gateway/entrypoint.sh`

Added `write_if_set ELEPHANTASM_API_KEY` and `write_if_set ELEPHANTASM_ANIMA_ID` so Fly.io secrets are injected into the hermes `.env` file at container startup.

**Why:** The gateway creates a fresh `AIAgent` per WebSocket message. Secrets are set via `fly secrets set` and need to flow through the entrypoint into the hermes env file.

---

### `gateway/Dockerfile`

No changes needed — already runs `pip install -e ".[all]"`, which now includes `elephantasm` via the updated `pyproject.toml`.

---

## Architecture Recap

```
┌──────────────────────────────────────────────────────────┐
│                    Hermes Agent Loop                      │
│                                                          │
│  Session start ──► [INJECT] Memory Pack into prompt      │
│                                                          │
│  User message ───► [EXTRACT] message.in                  │
│                                                          │
│  LLM response ──► [EXTRACT] message.out                  │
│                                                          │
│  Reasoning ──────► [EXTRACT] system (inner_monologue)    │
│                                                          │
│  Tool calls ─────► [EXTRACT] tool_call                   │
│                                                          │
│  Tool results ───► [EXTRACT] tool_result                 │
│                                                          │
│                    Elephantasm Dreamer synthesizes        │
│                    in the background (server-side)        │
└──────────────────────────────────────────────────────────┘
```

## Three-Layer Memory Architecture (final state)

| Layer | System | Scope |
|---|---|---|
| **Scratchpad** | MEMORY.md / USER.md | Bounded, file-backed, agent-managed |
| **User Model** | Honcho | Cross-session user context |
| **Deep Memory** | Elephantasm | Unbounded, evolving, automatic synthesis |

---

## Verification

- **Phase 1 (SDK wiring):** Run `hermes chat` with `HERMES_DUMP_REQUESTS=1`, confirm Memory Pack appears in system prompt.
- **Phase 2 (event extraction):** After a conversation, check the Elephantasm dashboard for captured events across all five types.
- **Phase 3 (inner monologue):** Use a reasoning model (e.g., DeepSeek R1 via OpenRouter), confirm reasoning appears as `system` events with `inner_monologue` subtype.
- **Phase 4 (deployment):** Deploy to Fly.io, run a conversation through the web terminal, confirm events appear in dashboard.

---

## Design Decisions

| Decision | Rationale |
|---|---|
| Fire-and-forget (not batched) | Simpler code, accurate timestamps, crash resilience. SDK calls are lightweight HTTP POSTs. |
| Capture all tools (not filtered) | Let the Dreamer decide importance. Complete data > selective capture. |
| Extract in `_build_assistant_message()` | This method is the single normalizer for all assistant messages — both tool-call turns and final responses pass through it. Captures reasoning at the earliest point after extraction. |
| Memory Pack frozen at session start | Matches the Honcho pattern. Preserves Anthropic prefix cache stability. |
| `original_user_message` for extraction | Avoids sending system nudges (memory/skill reminders) as user events. |
| Tool result truncated to 2K chars | Prevents flooding the event store with large outputs (e.g., file reads, search results). |
