#!/usr/bin/env bash
# forge hook 运行环境 — 由 deploy / cleanup workflow 调用 source
# 所有 GitHub Secrets 已透传，可直接引用 $SECRET_NAME
set -e

# ── normalize built-in vars ──
APP_NAME="${APP_NAME:-unknown}"
APP_DIR="${APP_DIR:-/tmp/app}"
DATA_DIR="${DATA_DIR:-$APP_DIR/data}"
DEPLOY_ROOT="${DEPLOY_ROOT:-/tmp/deploy}"

export APP_NAME APP_DIR DATA_DIR DEPLOY_ROOT

# ── 在此处添加项目专属导出 ──
export DOMAIN="geoflux.oneblue.dev"
