<p align="center">
  <img src="https://img.shields.io/badge/status-experiment%20in%20progress-e63946?style=flat-square" alt="Status" />
  <img src="https://img.shields.io/badge/deployed%20on-Fly.io-8338ec?style=flat-square" alt="Fly.io" />
  <img src="https://img.shields.io/badge/agent-Nous%20Hermes-00b4d8?style=flat-square" alt="Hermes" />
  <img src="https://img.shields.io/badge/memory-Elephantasm-ff6b6b?style=flat-square" alt="Elephantasm" />
</p>

<h1 align="center">
  <code>HERMES ALPHA</code>
</h1>

<p align="center">
  <strong>Can a stock AI agent — given nothing but a mission brief — bootstrap an autonomous bug bounty system from scratch?</strong>
</p>

<p align="center">
  <em>This repo is the experiment.</em>
</p>

---

```
 ┌──────────────────────────────────────────────────────────────────┐
 │                                                                  │
 │   Creator (You)                                                  │
 │     └─ browser terminal / Telegram                               │
 │          └─ Overseer  (persistent, strategic — builds the system)│
 │               └─ Hunter  (ephemeral, tactical — finds the bugs)  │
 │                    └─ subagents  (parallel analysis workers)      │
 │                                                                  │
 └──────────────────────────────────────────────────────────────────┘
```

## The Experiment

Most AI agent projects give the agent a mountain of custom tools, structured APIs, and carefully engineered infrastructure. **Hermes Alpha asks: what if you gave it nothing?**

We take a stock [Hermes agent](https://github.com/NousResearch/hermes-agent) from Nous Research, hand it a single identity document (`soul.md`), and challenge it to **build, deploy, and continuously improve a second AI agent that finds real software vulnerabilities for bug bounty payouts.**

No custom tools. No purpose-built infrastructure. Just a Linux terminal, git, and a mission.

### The Thesis

> A self-improving two-agent loop — where the Overseer evolves the Hunter's code, skills, and strategy based on real outcomes — compounds over time. The Hunter gets measurably better at finding vulnerabilities. The Overseer gets measurably better at improving the Hunter. And the whole system is validated by an objective, economic signal: **bounties paid or not paid.**

This is **Path B** of a deliberate A/B test:

| | **Hermes Prime** (Path A) | **Hermes Alpha** (Path B) |
|---|---|---|
| Approach | Purpose-built infrastructure, custom tools, structured APIs | Stock agent + identity document, zero custom code |
| Question | Does pre-built scaffolding accelerate results? | Can an agent bootstrap everything from first principles? |
| Status | Parallel development | **This repo** |

The winner informs the long-term architecture.

---

## How It Works

### The Overseer

The Overseer is a persistent Hermes agent that lives in a web terminal. It doesn't hunt for vulnerabilities itself. Instead, it:

- **Builds** the Hunter's codebase — security skills, system prompt, tools, Dockerfile
- **Deploys** the Hunter to its own Fly.io machine
- **Monitors** the Hunter's performance via logs and [Elephantasm](https://elephantasm.com) memory streams
- **Intervenes** when it spots problems — soft (runtime guidance injection) or hard (code changes + redeploy)
- **Learns** which interventions work over time, compounding improvements

Three intervention modes, always preferring the least invasive:

```
SOFT  ──→  inject a runtime instruction (immediate, low risk)
HARD  ──→  modify Hunter source, commit, push, redeploy (systemic, medium risk)
MODEL ──→  switch the Hunter's LLM tier (cost/quality optimisation)
```

### The Hunter

A Hermes agent armed with security analysis skills that follows a four-phase workflow per target:

```
 RECON ─────→ ANALYSIS ─────→ VERIFICATION ─────→ REPORTING
 clone repo    static +        build PoC,          structured report
 map surface   dynamic test    confirm exploit      with CVSS, CWE,
 check deps    code review     rule out FPs         repro steps
```

**Target market:** mid-tier bounties ($500–$5,000) — auth bypasses, IDOR, privilege escalation, info disclosure. Systematic analysis beats genius-level creativity here, and that's what agents are good at.

### The Self-Improvement Loop

This is the core insight. A static agent plateaus. A self-improving one compounds:

```
 Hunter v1 analyses target ──→ finds 2 vulns, misses 5
       │
 Overseer reviews logs ──→ identifies gaps in skills
       │
 Overseer rewrites skills, redeploys ──→ Hunter v2
       │
 Hunter v2 analyses next target ──→ finds 4 vulns, misses 3
       │
       └──→  repeat. compound. improve.
```

Four nested feedback loops operate at different timescales:

| Loop | Timescale | What Happens |
|------|-----------|--------------|
| **Tactical** | seconds–minutes | Overseer injects runtime guidance based on live events |
| **Structural** | minutes–hours | Overseer writes new skills/tools, redeploys Hunter |
| **Strategic** | hours–days | Elephantasm memory reveals which strategies actually work |
| **Meta-strategic** | days–weeks | Creator reviews outcomes, redirects the whole system |

---

## The Web Terminal

The gateway is a FastAPI app that bridges a PTY (pseudo-terminal) to WebSocket via [xterm.js](https://xtermjs.org/). When you connect:

1. Authenticate with your password
2. A WebSocket spawns `hermes chat` inside a PTY
3. Bidirectional I/O streams between your browser and the agent's terminal
4. The agent has full access to its Linux environment — git, Python, Node, flyctl, curl, everything

The terminal is styled with a cyberpunk aesthetic — dark background, red accents, scanlines, IBM Plex Mono — because if you're going to watch an AI bootstrap a security operation, it should *look* the part.

**Session resilience** ensures the terminal survives laptop sleep, network blips, and PTY crashes with auto-reconnect and heartbeat detection. A messaging gateway sidecar (Telegram/Discord/Slack/Signal) keeps the agent reachable even when the browser isn't open.

---

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│  Browser                                                │
│  ┌─────────────────┐     ┌────────────────────────┐     │
│  │  xterm.js        │◄──►│  WebSocket              │     │
│  │  (terminal UI)   │    │  (bidirectional I/O)    │     │
│  └─────────────────┘     └───────────┬────────────┘     │
└──────────────────────────────────────┼──────────────────┘
                                       │
┌──────────────────────────────────────┼──────────────────┐
│  Fly.io Machine                      │                  │
│  ┌───────────────────────────────────▼───────────────┐  │
│  │  FastAPI Gateway  (gateway/app.py)                 │  │
│  │  ├─ Auth (session cookie)                          │  │
│  │  ├─ PTY manager (spawn, monitor, bridge)           │  │
│  │  └─ Provider switcher (OpenRouter / Nous Direct)   │  │
│  └───────────────────────────────────┬───────────────┘  │
│                                      │                  │
│  ┌───────────────────────────────────▼───────────────┐  │
│  │  hermes chat  (PTY process)                        │  │
│  │  └─ Identity: soul.md (Overseer persona)           │  │
│  └───────────────────────────────────────────────────┘  │
│                                                         │
│  ┌───────────────────────────────────────────────────┐  │
│  │  Messaging Gateway Sidecar  (independent process)  │  │
│  │  └─ Telegram / Discord / Slack / Signal            │  │
│  └───────────────────────────────────────────────────┘  │
│                                                         │
│  ┌───────────────────────────────────────────────────┐  │
│  │  /root/.hermes  (persistent Fly.io volume)         │  │
│  │  ├─ sessions/   memories/   skills/   logs/        │  │
│  │  └─ .env   config.yaml   SOUL.md                   │  │
│  └───────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────┘
                         │
              ┌──────────┴──────────┐
              │   Elephantasm API    │
              │   (long-term memory) │
              └─────────────────────┘
```

**Key files:**

| File | Purpose |
|------|---------|
| `gateway/app.py` | FastAPI server — auth, PTY lifecycle, WebSocket bridge |
| `gateway/soul.md` | Overseer identity — mission, hierarchy, guardrails |
| `gateway/entrypoint.sh` | Bootstrap persistent volume, start sidecar + server |
| `gateway/Dockerfile` | Install Hermes agent + web gateway |
| `gateway/static/` | Login + terminal HTML (xterm.js, provider selector) |
| `docs/vision.md` | Full architectural vision and design rationale |

---

## Quick Start

### Local (Docker Compose)

```bash
cp .env.example .env
# Edit .env — at minimum set OPENROUTER_API_KEY and TTYD_PASS

make up          # Runs on http://localhost:8081
make down        # Stop
```

### Production (Fly.io)

```bash
# Requires flyctl installed and authenticated
make deploy      # Deploy to Fly.io
make logs        # Tail live logs
make ssh         # SSH into the machine
make status      # Check app status
```

### Environment Variables

```bash
# Required
OPENROUTER_API_KEY=sk-or-...     # LLM provider

# Recommended
TTYD_PASS=...                     # Terminal password
ELEPHANTASM_API_KEY=sk_live_...   # Long-term memory
ELEPHANTASM_ANIMA_ID=anima_...

# Optional
HERMES_API_KEY=sk-...             # Direct Nous Research inference
FIRECRAWL_API_KEY=fc-...          # Web search/scrape
FAL_KEY=...                       # Image generation

# Messaging (pick one or more to keep the agent reachable)
TELEGRAM_BOT_TOKEN=...
DISCORD_BOT_TOKEN=...
SLACK_BOT_TOKEN=...
```

See [`.env.example`](.env.example) for the full list.

---

## Safety & Ethics

This project operates under strict guardrails:

1. **No attacking live systems.** Source code analysis and sandboxed PoC only. Never probe, scan, or exploit production infrastructure.
2. **Scope enforcement.** Every target is verified in-scope for its bounty program before analysis begins.
3. **Human approval required.** No vulnerability report is submitted to any platform without explicit Creator approval.
4. **No credential harvesting.** Credentials found in targets are never extracted, stored, or transmitted.
5. **Budget hard stops.** When the budget limit is reached, the system stops. No exceptions.
6. **Full audit trail.** Every significant action is recorded to Elephantasm.

---

## Economics

At ~$15/day LLM budget + Fly.io compute, the system needs roughly **one $500–$1,000 bounty per month** to break even. The Overseer optimises for the only metric that matters: **high-quality vulnerability reports that earn payouts.** Everything else — speed, coverage, model selection — is a supporting signal in service of that goal.

---

## Why This Matters

This isn't just a bug bounty bot. It's a test of a broader hypothesis about AI agents:

**Can a general-purpose agent, given only a clear mission and a terminal, bootstrap complex multi-agent infrastructure that improves itself over time?**

If the answer is yes, the implications extend far beyond security. If the answer is no, we learn exactly where and why agents need pre-built scaffolding — and that's equally valuable.

The experiment has an objective success criterion (bounties paid) and a built-in control group (Hermes Prime). Whatever happens, we learn something real.

---

<p align="center">
  <sub>Built with <a href="https://github.com/NousResearch/hermes-agent">Hermes</a> by Nous Research &nbsp;·&nbsp; Memory by <a href="https://elephantasm.com">Elephantasm</a> &nbsp;·&nbsp; Deployed on <a href="https://fly.io">Fly.io</a></sub>
</p>
<p align="center">
  <sub>A <a href="https://github.com/crimson-sun">Crimson Sun</a> experiment</sub>
</p>
