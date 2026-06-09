#!/usr/bin/env bash
# pre-cleanup hook — docker compose down 之前执行
set -euo pipefail
DIR="$(cd "$(dirname "$0")" && pwd)"
source "$DIR/../env/load-env.sh"

# ── 示例：从 Cloudflare Tunnel 下架 ──
# source "$DIR/../plugins/cloudflare.sh"
# cf_route_del "$DOMAIN"

# ── 在此处添加清理前逻辑 ──
