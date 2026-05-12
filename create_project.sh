#!/bin/bash
set -euo pipefail

SCRIPT_SOURCE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

escape_sed_replacement() {
    printf '%s' "$1" | sed 's/[&|\]/\\&/g'
}

render_template() {
    local template_file=$1
    local output_file=$2
    local project_name
    local api_port
    local web_host_port

    project_name=$(escape_sed_replacement "$PROJECT_NAME")
    api_port=$(escape_sed_replacement "$API_PORT")
    web_host_port=$(escape_sed_replacement "$WEB_HOST_PORT")

    sed \
        -e "s|\[\[PROJECT_NAME\]\]|$project_name|g" \
        -e "s|\[\[API_PORT\]\]|$api_port|g" \
        -e "s|\[\[WEB_HOST_PORT\]\]|$web_host_port|g" \
        "$template_file" > "$output_file"
}

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
render_template "$SCRIPT_SOURCE_DIR/api_template.sh" "$SCRIPT_DIR/deploy_api.sh"
chmod +x "$SCRIPT_DIR/deploy_api.sh"
echo "✅ 生成 API 部署脚本：$SCRIPT_DIR/deploy_api.sh"
fi

# ==============================
# 生成 deploy_web.sh
# ==============================
if [[ $HAS_WEB -eq 1 ]]; then
render_template "$SCRIPT_SOURCE_DIR/web_template.sh" "$SCRIPT_DIR/deploy_web.sh"
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
