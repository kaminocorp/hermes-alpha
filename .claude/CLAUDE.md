# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Hermes is a self-hosted web terminal for interacting with the stock Hermes AI agent CLI (from Nous Research). It runs `hermes chat` inside a PTY bridged to xterm.js in the browser, giving full access to the native CLI experience (multiline editing, slash commands, rich output, tool use) without installing anything locally. Deployed on Fly.io.

## Commands

```bash
make up           # Run via Docker Compose (port 8080)
make down         # Stop Docker Compose
make deploy       # Deploy to Fly.io
make logs         # Tail Fly.io logs
make ssh          # SSH into Fly.io machine
make status       # Fly.io app status
```

## Architecture

- **`gateway/app.py`** — FastAPI app. Serves a login page and a terminal page. On WebSocket connect, spawns `hermes chat` in a PTY and bridges I/O between the PTY and the browser via xterm.js.
- **`gateway/static/`** — Login and terminal HTML pages, plus xterm.js assets.
- **`gateway/Dockerfile`** — Clones the upstream `hermes-agent` repo, installs it with `pip install -e ".[all]"`, then copies the web app.
- **`gateway/entrypoint.sh`** — Container entrypoint.

### Authentication

The terminal is password-protected via `TTYD_PASS` env var. Session is stored in a secure httponly cookie.

## Environment

Copy `.env.example` to `.env`. Requires at minimum `OPENROUTER_API_KEY`. Optional keys: `FIRECRAWL_API_KEY` (web tools), `FAL_KEY` (image generation). The app runs on port 8080 in all environments.
