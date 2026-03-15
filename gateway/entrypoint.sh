#!/bin/bash
set -e

# ── Bootstrap persistent volume ──────────────────────────────────────
# When a Fly volume is mounted at /root/.hermes it starts empty.
# Seed the directory structure and default config on first boot.
HERMES_DIR="/root/.hermes"

if [ ! -f "$HERMES_DIR/.bootstrapped" ]; then
    echo "[entrypoint] First boot on fresh volume — seeding defaults"
    mkdir -p "$HERMES_DIR"/{sessions,logs,memories,skills,hooks,cron,image_cache,audio_cache}
    cp /opt/hermes-agent/.env.example "$HERMES_DIR/.env"
    cp /opt/hermes-agent/cli-config.yaml.example "$HERMES_DIR/config.yaml" 2>/dev/null || true
    cp /app/soul.md "$HERMES_DIR/SOUL.md" 2>/dev/null || true
    touch "$HERMES_DIR/.bootstrapped"
fi

# Write Fly.io secrets into the hermes .env file so the CLI picks them up.
ENV_FILE="/root/.hermes/.env"

write_if_set() {
    local var="$1"
    local val="${!var}"
    if [ -n "$val" ]; then
        sed -i "/^${var}=/d" "$ENV_FILE"
        echo "${var}=${val}" >> "$ENV_FILE"
    fi
}

write_if_set OPENROUTER_API_KEY
write_if_set HERMES_API_KEY
write_if_set ANTHROPIC_API_KEY
write_if_set OPENAI_API_KEY
write_if_set FIRECRAWL_API_KEY
write_if_set FAL_KEY
write_if_set ELEPHANTASM_API_KEY
write_if_set ELEPHANTASM_ANIMA_ID

exec uvicorn app:app --host 0.0.0.0 --port 8080 --app-dir /app
