#!/bin/bash
set -euo pipefail

SCRIPT_SOURCE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_NAME=""
PROJECT_TYPE=""
HAS_API=0
HAS_WEB=0
API_PORT=""
WEB_HOST_PORT=""
BASE_DIR="${BASE_DIR:-/apps}"

usage() {
    cat <<'EOF'
用法：
  bash create_project.sh
  bash create_project.sh --name demo --type all --api-port 8080 --web-port 8081

选项：
  --name <项目名>          项目名称，仅支持小写字母、数字、中划线和下划线
  --type <api|web|all>     服务类型
  --api-port <端口>        API 服务端口
  --web-port <端口>        Web 外部端口
  --base-dir <目录>        项目根目录，默认读取 BASE_DIR 环境变量或使用 /apps
  -h, --help               显示帮助
EOF
}

require_option_value() {
    local option=$1
    local value=${2:-}

    if [[ -z "$value" || "$value" == --* ]]; then
        echo "❌ $option 需要参数"
        exit 1
    fi
}

parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --name)
                require_option_value "$1" "${2:-}"
                PROJECT_NAME=$2
                shift 2
                ;;
            --type)
                require_option_value "$1" "${2:-}"
                PROJECT_TYPE=$2
                shift 2
                ;;
            --api-port)
                require_option_value "$1" "${2:-}"
                API_PORT=$2
                shift 2
                ;;
            --web-port)
                require_option_value "$1" "${2:-}"
                WEB_HOST_PORT=$2
                shift 2
                ;;
            --base-dir)
                require_option_value "$1" "${2:-}"
                BASE_DIR=$2
                shift 2
                ;;
            -h|--help)
                usage
                exit 0
                ;;
            *)
                echo "❌ 未知选项：$1"
                usage
                exit 1
                ;;
        esac
    done
}

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

validate_base_dir() {
    local dir=$1

    if [[ -z "$dir" ]]; then
        echo "❌ 项目根目录不能为空"
        exit 1
    fi

    if [[ "$dir" != /* ]]; then
        echo "❌ 项目根目录必须是绝对路径"
        exit 1
    fi

    if ! [[ "$dir" =~ ^/[A-Za-z0-9._/-]+$ ]]; then
        echo "❌ 项目根目录只能包含字母、数字、点、下划线、中划线和斜线"
        exit 1
    fi

    BASE_DIR="${dir%/}"
    if [[ -z "$BASE_DIR" ]]; then
        BASE_DIR="/"
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

prompt_value() {
    local prompt=$1
    local var_name=$2
    local value

    if ! IFS= read -r -p "$prompt" value; then
        echo "❌ 缺少输入：$prompt"
        exit 1
    fi

    printf -v "$var_name" '%s' "$value"
}

select_services() {
    local choice=$1

    HAS_API=0
    HAS_WEB=0

    case $choice in
        1|api) HAS_API=1 ;;
        2|web) HAS_WEB=1 ;;
        3|all) HAS_API=1; HAS_WEB=1 ;;
        *) echo "❌ 无效服务类型：$choice"; exit 1 ;;
    esac
}

parse_args "$@"

if [[ -t 1 ]]; then
    clear
fi

echo "=================================================="
echo "          Simon Docker项目自动化创建工具        "
echo "=================================================="

# 1. 输入项目名称
if [[ -z "$PROJECT_NAME" ]]; then
    prompt_value "👉 请输入项目名称：" PROJECT_NAME
fi
validate_project_name "$PROJECT_NAME"
validate_base_dir "$BASE_DIR"

# 2. 选择模块
if [[ -z "$PROJECT_TYPE" ]]; then
    echo -e "\n请选择需要的服务："
    echo "1) 仅 API"
    echo "2) 仅 Web"
    echo "3) API + Web 全部"
    prompt_value "请输入选项：" PROJECT_TYPE
fi
select_services "$PROJECT_TYPE"

# 3. 输入端口
if [[ $HAS_API -eq 1 ]]; then
    if [[ -z "$API_PORT" ]]; then
        prompt_value "👉 请输入 API 运行端口：" API_PORT
    fi
    validate_port "$API_PORT" "API"
fi

if [[ $HAS_WEB -eq 1 ]]; then
    if [[ -z "$WEB_HOST_PORT" ]]; then
        prompt_value "👉 请输入 Web 外部端口：" WEB_HOST_PORT
    fi
    validate_port "$WEB_HOST_PORT" "Web"
fi

# 4. 定义目录结构
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
