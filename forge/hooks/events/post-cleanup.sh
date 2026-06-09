#!/usr/bin/env bash
# post-cleanup hook — rm -rf 之前执行
set -euo pipefail
DIR="$(cd "$(dirname "$0")" && pwd)"
source "$DIR/../env/load-env.sh"

# ── 在此处添加清理后逻辑 ──
