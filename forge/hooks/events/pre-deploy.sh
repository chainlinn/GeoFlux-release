#!/usr/bin/env bash
# pre-deploy hook — 在 NAS 上 docker compose up 之前执行
# 工作目录: $APP_DIR/docker/compose
# 可用变量: APP_NAME, APP_DIR, DATA_DIR
set -euo pipefail
DATA_DIR="${APP_DIR}/data"

# 在此处添加项目初始化逻辑
# 例如：首次部署时生成配置文件
