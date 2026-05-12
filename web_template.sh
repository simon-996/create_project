#!/bin/bash
APP_NAME="[[PROJECT_NAME]]"
APP_PORT=80
HOST_PORT=[[WEB_HOST_PORT]]

CONTAINER_NAME="${APP_NAME}-web"
DOCKER_IMAGE="$CONTAINER_NAME"

BASE_DIR="/apps/"
HOME_DIR="$BASE_DIR$APP_NAME"
APP_DIR="$HOME_DIR/web"
LOG_DIR="$HOME_DIR/logs"

mkdir -p "$APP_DIR" "$LOG_DIR"
LOG_FILE="$LOG_DIR/deployment_web_log.txt"

echo "============================================" >> "$LOG_FILE"
echo "Deployment Web Start | $(date)" >> "$LOG_FILE"

# 停止旧容器
if docker ps -a --format '{{.Names}}' | grep -Fxq "$CONTAINER_NAME"; then
  if docker ps -q --filter "name=$CONTAINER_NAME" | grep -q .; then
    docker stop "$CONTAINER_NAME"
  fi
  docker rm "$CONTAINER_NAME"
fi

# 清理
rm -rf "${APP_DIR:?}"/*

# 移动解压
cp "$HOME_DIR/web.tar.gz" "$APP_DIR/"
cd "$APP_DIR" || exit 1
tar -xzf web.tar.gz
rm -f web.tar.gz

# 移动 dist
if [ -d "dist" ]; then
  mv dist Docker/
else
  echo "❌ dist 不存在" >> "$LOG_FILE"
  exit 1
fi

# 构建
cd Docker || exit 1
docker build -t "$DOCKER_IMAGE" .

# 启动
docker run -d \
  -p "$HOST_PORT":"$APP_PORT" \
  -v "$LOG_DIR:/logs" \
  --restart always \
  --name "$CONTAINER_NAME" \
  "$DOCKER_IMAGE"

echo "✅ Web 部署完成！" >> "$LOG_FILE"
