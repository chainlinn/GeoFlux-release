#!/usr/bin/env bash
# post-deploy hook — docker compose up 之后执行
set -euo pipefail
DIR="$(cd "$(dirname "$0")" && pwd)"
source "$DIR/../env/load-env.sh"

# ── 示例：发布到 Cloudflare Tunnel ──
# 1. .secrets 里加 CF_API_TOKEN CF_ACCOUNT_ID CF_TUNNEL_ID CF_ZONE_ID
# 2. load-env.sh 里加 export DOMAIN="$APP_NAME.oneblue.dev"
# 3. 取消下面注释：
source "$DIR/../plugins/cloudflare.sh"
cf_route_add "$DOMAIN" "http://localhost:9000"

# ── 在此处添加部署后逻辑 ──
