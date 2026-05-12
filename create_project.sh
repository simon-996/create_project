#!/bin/bash
set -euo pipefail

clear
echo "=================================================="
echo "          Simon Docker项目自动化创建工具        "
echo "=================================================="

# 1. 输入项目名称
read -p "👉 请输入项目名称：" PROJECT_NAME
if [[ -z "$PROJECT_NAME" ]]; then
    echo -e "\n❌ 项目名称不能为空！"
    exit 1
fi

# 2. 选择模块
echo -e "\n请选择需要的服务："
echo "1) 仅 API"
echo "2) 仅 Web"
echo "3) API + Web 全部"
read -p "请输入选项：" CHOICE

HAS_API=0
HAS_WEB=0
API_PORT=""
WEB_HOST_PORT=""

case $CHOICE in
    1) HAS_API=1 ;;
    2) HAS_WEB=1 ;;
    3) HAS_API=1; HAS_WEB=1 ;;
    *) echo "❌ 无效选项"; exit 1 ;;
esac

# 3. 输入端口
if [[ $HAS_API -eq 1 ]]; then
    read -p "👉 请输入 API 运行端口：" API_PORT
    if ! [[ "$API_PORT" =~ ^[0-9]+$ ]]; then echo "❌ 端口必须是数字"; exit 1; fi
fi

if [[ $HAS_WEB -eq 1 ]]; then
    read -p "👉 请输入 Web 外部端口：" WEB_HOST_PORT
    if ! [[ "$WEB_HOST_PORT" =~ ^[0-9]+$ ]]; then echo "❌ 端口必须是数字"; exit 1; fi
fi

# 4. 定义目录结构
BASE="/apps"
PROJECT_DIR="$BASE/$PROJECT_NAME"
API_DIR="$PROJECT_DIR/api"
WEB_DIR="$PROJECT_DIR/web"
LOG_DIR="$PROJECT_DIR/logs"
SCRIPT_DIR="$PROJECT_DIR/scripts"

echo -e "\n📁 正在创建目录结构..."
mkdir -p "$API_DIR" "$WEB_DIR" "$LOG_DIR" "$SCRIPT_DIR"
echo "✅ 目录创建完成：$PROJECT_DIR"

# ==============================
# 生成 deploy_api.sh
# ==============================
if [[ $HAS_API -eq 1 ]]; then
cat > "$SCRIPT_DIR/deploy_api.sh" << EOF
#!/bin/bash
APP_NAME="$PROJECT_NAME"
APP_PORT=$API_PORT
HOST_PORT=\$APP_PORT

CONTAINER_NAME="\${APP_NAME}-api"
DOCKER_IMAGE="\$CONTAINER_NAME"

BASE_DIR="/apps/"
HOME_DIR="\$BASE_DIR\$APP_NAME"
APP_DIR="\$HOME_DIR/api"
LOG_DIR="\$HOME_DIR/logs"

mkdir -p "\$APP_DIR" "\$LOG_DIR"
LOG_FILE="\$LOG_DIR/deployment_api_log.txt"

echo "============================================" >> "\$LOG_FILE"
echo "Deployment API Start | \$(date)" >> "\$LOG_FILE"

# 停止旧容器
if docker ps -a --format '{{.Names}}' | grep -Fxq "\$CONTAINER_NAME"; then
  if docker ps -q --filter "name=\$CONTAINER_NAME" | grep -q .; then
    docker stop "\$CONTAINER_NAME"
  fi
  docker rm "\$CONTAINER_NAME"
fi

# 清理旧文件
rm -rf "\${APP_DIR:?}"/*

# 移动并解压
cp "\$HOME_DIR/app.tar.gz" "\$APP_DIR/"
cd "\$APP_DIR" || exit 1
tar -xzf app.tar.gz
rm -f app.tar.gz

# 构建镜像
docker build -t "\$DOCKER_IMAGE" .

# 启动容器
docker run -d \\
  -p "\$HOST_PORT":"\$APP_PORT" \\
  -v "\$LOG_DIR:/logs" \\
  --restart always \\
  --name "\$CONTAINER_NAME" \\
  "\$DOCKER_IMAGE"

echo "✅ API 部署完成！" >> "\$LOG_FILE"
EOF

chmod +x "$SCRIPT_DIR/deploy_api.sh"
echo "✅ 生成 API 部署脚本：$SCRIPT_DIR/deploy_api.sh"
fi

# ==============================
# 生成 deploy_web.sh
# ==============================
if [[ $HAS_WEB -eq 1 ]]; then
cat > "$SCRIPT_DIR/deploy_web.sh" << EOF
#!/bin/bash
APP_NAME="$PROJECT_NAME"
APP_PORT=80
HOST_PORT="$WEB_HOST_PORT"

CONTAINER_NAME="\${APP_NAME}-web"
DOCKER_IMAGE="\$CONTAINER_NAME"

BASE_DIR="/apps/"
HOME_DIR="\$BASE_DIR\$APP_NAME"
APP_DIR="\$HOME_DIR/web"
LOG_DIR="\$HOME_DIR/logs"

mkdir -p "\$APP_DIR" "\$LOG_DIR"
LOG_FILE="\$LOG_DIR/deployment_web_log.txt"

echo "============================================" >> "\$LOG_FILE"
echo "Deployment Web Start | \$(date)" >> "\$LOG_FILE"

# 停止旧容器
if docker ps -a --format '{{.Names}}' | grep -Fxq "\$CONTAINER_NAME"; then
  if docker ps -q --filter "name=\$CONTAINER_NAME" | grep -q .; then
    docker stop "\$CONTAINER_NAME"
  fi
  docker rm "\$CONTAINER_NAME"
fi

# 清理
rm -rf "\${APP_DIR:?}"/*

# 移动解压
cp "\$HOME_DIR/web.tar.gz" "\$APP_DIR/"
cd "\$APP_DIR" || exit 1
tar -xzf web.tar.gz
rm -f web.tar.gz

# 移动 dist
if [ -d "dist" ]; then
  mv dist Docker/
else
  echo "❌ dist 不存在" >> "\$LOG_FILE"
  exit 1
fi

# 构建
cd Docker || exit 1
docker build -t "\$DOCKER_IMAGE" .

# 启动
docker run -d \\
  -p "\$HOST_PORT":"\$APP_PORT" \\
  -v "\$LOG_DIR:/logs" \\
  --restart always \\
  --name "\$CONTAINER_NAME" \\
  "\$DOCKER_IMAGE"

echo "✅ Web 部署完成！" >> "\$LOG_FILE"
EOF

chmod +x "$SCRIPT_DIR/deploy_web.sh"
echo "✅ 生成 Web 部署脚本：$SCRIPT_DIR/deploy_web.sh"
fi

# ==============================
# 完成
# ==============================
echo -e "\n=================================================="
echo "🎉 项目创建全部完成！"
echo "📂 项目路径：$PROJECT_DIR"
echo -e "==================================================\n"
