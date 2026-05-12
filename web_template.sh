#!/bin/bash
set -euo pipefail

APP_NAME="[[PROJECT_NAME]]"
APP_PORT=80
HOST_PORT=[[WEB_HOST_PORT]]

CONTAINER_NAME="${APP_NAME}-web"
DOCKER_IMAGE="$CONTAINER_NAME"

BASE_DIR="[[BASE_DIR]]"
HOME_DIR="$BASE_DIR/$APP_NAME"
APP_DIR="$HOME_DIR/web"
LOG_DIR="$HOME_DIR/logs"
PACKAGE_FILE="$HOME_DIR/web.tar.gz"
TMP_DIR=""

mkdir -p "$HOME_DIR" "$LOG_DIR"
LOG_FILE="$LOG_DIR/deployment_web_log.txt"

require_command() {
  local command_name=$1

  if ! command -v "$command_name" >/dev/null 2>&1; then
    echo "❌ 缺少依赖命令：$command_name"
    exit 1
  fi
}

cleanup() {
  if [[ -n "${TMP_DIR:-}" && -d "$TMP_DIR" ]]; then
    rm -rf "$TMP_DIR" || true
  fi
}

on_exit() {
  local status=$?

  if (( status != 0 )); then
    echo "❌ Web 部署失败，退出码：$status"
  fi

  cleanup
}

container_exists() {
  docker container inspect "$CONTAINER_NAME" >/dev/null 2>&1
}

container_running() {
  [[ "$(docker container inspect -f '{{.State.Running}}' "$CONTAINER_NAME")" == "true" ]]
}

stop_existing_container() {
  if ! container_exists; then
    return
  fi

  if container_running; then
    docker stop "$CONTAINER_NAME"
  fi

  docker rm "$CONTAINER_NAME"
}

trap on_exit EXIT

require_command docker
require_command tar
require_command mktemp
require_command tee

exec > >(tee -a "$LOG_FILE") 2>&1

echo "============================================"
echo "Deployment Web Start | $(date)"

if [[ ! -f "$PACKAGE_FILE" ]]; then
  echo "❌ Web 压缩包不存在：$PACKAGE_FILE"
  exit 1
fi

echo "检查 Docker 服务..."
docker info >/dev/null

TMP_DIR=$(mktemp -d "$HOME_DIR/.web-deploy.XXXXXX")
tar -xzf "$PACKAGE_FILE" -C "$TMP_DIR"

if [[ ! -d "$TMP_DIR/dist" ]]; then
  echo "❌ Web 压缩包根目录必须包含 dist 目录"
  exit 1
fi

if [[ ! -f "$TMP_DIR/Docker/Dockerfile" ]]; then
  echo "❌ Web 压缩包根目录必须包含 Docker/Dockerfile"
  exit 1
fi

rm -rf "$TMP_DIR/Docker/dist"
mv "$TMP_DIR/dist" "$TMP_DIR/Docker/"

echo "构建 Web 镜像：$DOCKER_IMAGE"
docker build -t "$DOCKER_IMAGE" "$TMP_DIR/Docker"

echo "替换 Web 文件目录：$APP_DIR"
rm -rf "$APP_DIR"
mv "$TMP_DIR" "$APP_DIR"
TMP_DIR=""

echo "重启 Web 容器：$CONTAINER_NAME"
stop_existing_container
docker run -d \
  -p "$HOST_PORT":"$APP_PORT" \
  -v "$LOG_DIR:/logs" \
  --restart always \
  --name "$CONTAINER_NAME" \
  "$DOCKER_IMAGE"

echo "✅ Web 部署完成！"
