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
    local base_dir

    project_name=$(escape_sed_replacement "$PROJECT_NAME")
    api_port=$(escape_sed_replacement "$API_PORT")
    web_host_port=$(escape_sed_replacement "$WEB_HOST_PORT")
    base_dir=$(escape_sed_replacement "$BASE_DIR")

    sed \
        -e "s|\[\[PROJECT_NAME\]\]|$project_name|g" \
        -e "s|\[\[API_PORT\]\]|$api_port|g" \
        -e "s|\[\[WEB_HOST_PORT\]\]|$web_host_port|g" \
        -e "s|\[\[BASE_DIR\]\]|$base_dir|g" \
        "$template_file" > "$output_file"
}

validate_project_name() {
    local name=$1

    if [[ -z "$name" ]]; then
        echo -e "\n❌ 项目名称不能为空！"
        exit 1
    fi

    if ! [[ "$name" =~ ^[a-z0-9][a-z0-9_-]*$ ]]; then
        echo "❌ 项目名称只能包含小写字母、数字、中划线和下划线，并且必须以小写字母或数字开头"
        exit 1
    fi
}

validate_port() {
    local port=$1
    local label=$2

    if ! [[ "$port" =~ ^[0-9]+$ ]]; then
        echo "❌ $label 端口必须是数字"
        exit 1
    fi

    if (( port < 1 || port > 65535 )); then
        echo "❌ $label 端口必须在 1-65535 之间"
        exit 1
    fi
}

clear
echo "=================================================="
echo "          Simon Docker项目自动化创建工具        "
echo "=================================================="

# 1. 输入项目名称
read -p "👉 请输入项目名称：" PROJECT_NAME
validate_project_name "$PROJECT_NAME"

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
    validate_port "$API_PORT" "API"
fi

if [[ $HAS_WEB -eq 1 ]]; then
    read -p "👉 请输入 Web 外部端口：" WEB_HOST_PORT
    validate_port "$WEB_HOST_PORT" "Web"
fi

# 4. 定义目录结构
BASE_DIR="${BASE_DIR:-/apps}"
PROJECT_DIR="$BASE_DIR/$PROJECT_NAME"
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
