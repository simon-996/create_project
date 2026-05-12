#!/bin/bash
APP_NAME="[[PROJECT_NAME]]"
APP_PORT=[[API_PORT]]
HOST_PORT=$APP_PORT

CONTAINER_NAME="${APP_NAME}-api"
DOCKER_IMAGE="$CONTAINER_NAME"

BASE_DIR="/apps/"
HOME_DIR="$BASE_DIR$APP_NAME"
APP_DIR="$HOME_DIR/api"
LOG_DIR="$HOME_DIR/logs"

mkdir -p "$APP_DIR" "$LOG_DIR"
LOG_FILE="$LOG_DIR/deployment_api_log.txt"

echo "============================================" >> "$LOG_FILE"
echo "Deployment API Start | $(date)" >> "$LOG_FILE"

# 停止旧容器
if docker ps -a --format '{{.Names}}' | grep -Fxq "$CONTAINER_NAME"; then
  if docker ps -q --filter "name=$CONTAINER_NAME" | grep -q .; then
    docker stop "$CONTAINER_NAME"
  fi
  docker rm "$CONTAINER_NAME"
fi

# 清理旧文件
rm -rf "${APP_DIR:?}"/*

# 移动并解压
cp "$HOME_DIR/app.tar.gz" "$APP_DIR/"
cd "$APP_DIR" || exit 1
tar -xzf app.tar.gz
rm -f app.tar.gz

# 构建镜像
docker build -t "$DOCKER_IMAGE" .

# 启动容器
docker run -d \
  -p "$HOST_PORT":"$APP_PORT" \
  -v "$LOG_DIR:/logs" \
  --restart always \
  --name "$CONTAINER_NAME" \
  "$DOCKER_IMAGE"

echo "✅ API 部署完成！" >> "$LOG_FILE"
