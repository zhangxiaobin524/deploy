#!/bin/bash
# ========================================
# Fluent Life 统一部署脚本
# 用法: ./deploy.sh [all|api|frontend|admin|admin-api|backup|status|logs|stop|restart]
# ========================================

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 配置
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEPLOY_DIR="$(dirname "$SCRIPT_DIR")"
PROJECT_ROOT="$(dirname "$DEPLOY_DIR")"
BACKUP_DIR="/opt/backups/$(date +%Y%m%d_%H%M%S)"

# 日志函数
log() {
    echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')] $1${NC}"
}

warn() {
    echo -e "${YELLOW}[$(date '+%Y-%m-%d %H:%M:%S')] ⚠️  $1${NC}"
}

error() {
    echo -e "${RED}[$(date '+%Y-%m-%d %H:%M:%S')] ❌  $1${NC}"
    exit 1
}

info() {
    echo -e "${BLUE}[$(date '+%Y-%m-%d %H:%M:%S')] ℹ️  $1${NC}"
}

# 检查环境
check_environment() {
    log "🔍 检查部署环境..."
    
    if ! command -v docker &> /dev/null; then
        error "Docker 未安装"
    fi
    
    if ! command -v docker-compose &> /dev/null; then
        error "Docker Compose 未安装"
    fi
    
    # 检查 .env 文件
    if [ ! -f "$DEPLOY_DIR/.env" ]; then
        error "未找到 .env 文件！请先创建：\n  cp $DEPLOY_DIR/config/.env.example $DEPLOY_DIR/.env\n  然后编辑 .env 文件配置数据库密码等"
    fi
    
    # 加载环境变量
    set -a
    source "$DEPLOY_DIR/.env"
    set +a
    
    # 检查必要配置
    if [ -z "$DB_PASSWORD" ] || [ "$DB_PASSWORD" = "your_secure_password_here" ]; then
        error "数据库密码未配置！请编辑 $DEPLOY_DIR/.env 文件设置 DB_PASSWORD"
    fi
    
    log "✅ 环境检查通过"
}

# 备份当前版本
backup() {
    log "📦 备份当前版本..."
    
    mkdir -p "$BACKUP_DIR"
    
    # 备份数据库
    log "  - 备份数据库..."
    if docker ps | grep -q "fluent-life-db"; then
        docker exec fluent-life-db pg_dump -U fluent_life fluent_life 2>/dev/null | gzip > "$BACKUP_DIR/db_$(date +%Y%m%d).sql.gz" || warn "数据库备份失败"
    fi
    
    log "✅ 备份完成: $BACKUP_DIR"
}

# 部署全部服务
deploy_all() {
    log "🚀 开始部署全部服务..."
    
    cd "$DEPLOY_DIR"
    
    # 拉取最新代码（如果在 git 仓库中）
    if [ -d "$PROJECT_ROOT/.git" ]; then
        log "📥 拉取最新代码..."
        cd "$PROJECT_ROOT" && git pull origin main 2>/dev/null || warn "拉取代码失败，使用本地版本"
        cd "$DEPLOY_DIR"
    else
        warn "未找到 Git 仓库，使用本地代码"
    fi
    
    # 先停止并删除所有旧容器（避免名称冲突）
    log "🛑 清理旧容器..."
    docker-compose down 2>/dev/null || true
    
    # 构建并启动
    log "🔨 构建并启动服务..."
    docker-compose pull 2>/dev/null || true
    docker-compose up -d --build
    
    # 健康检查
    sleep 10
    health_check
    
    # 清理旧镜像
    docker image prune -af --filter "until=168h" > /dev/null 2>&1 || true
    
    log "✅ 全部服务部署完成！"
    show_status
}

# 部署指定服务
deploy_service() {
    local service="$1"
    log "🚀 部署服务: $service..."
    
    cd "$DEPLOY_DIR"
    
    # 检查容器是否已存在，如果存在则先停止删除
    local container_name="fluent-life-$service"
    if docker ps -a --format '{{.Names}}' | grep -q "^${container_name}$"; then
        log "🛑 停止并删除旧容器: $container_name..."
        docker stop "$container_name" > /dev/null 2>&1 || true
        docker rm "$container_name" > /dev/null 2>&1 || true
    fi
    
    # 构建并启动服务
    docker-compose up -d --build "$service"
    
    sleep 5
    
    # 检查服务健康
    if docker-compose ps "$service" | grep -q "Up"; then
        log "✅ $service 部署成功"
    else
        error "$service 部署失败"
    fi
}

# 健康检查
health_check() {
    log "🏥 执行健康检查..."
    
    local services=("api" "admin-api")
    local ports=("8081" "8082")
    
    for i in "${!services[@]}"; do
        local service="${services[$i]}"
        local port="${ports[$i]}"
        
        if curl -sf "http://localhost:$port/health" > /dev/null 2>&1; then
            log "  ✅ $service 健康"
        else
            warn "  ⚠️  $service 未通过健康检查"
        fi
    done
}

# 查看状态
show_status() {
    echo ""
    echo "📊 服务运行状态"
    echo "========================================"
    docker-compose -f "$DEPLOY_DIR/docker-compose.yml" ps
    
    echo ""
    echo "💾 资源使用"
    echo "========================================"
    docker stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.NetIO}}\t{{.BlockIO}}" 2>/dev/null | head -10 || docker stats --no-stream
    
    echo ""
    echo "🌐 访问地址"
    echo "========================================"
    echo "主前端:      http://localhost"
    echo "主 API:      http://localhost:8081"
    echo "管理前端:    http://localhost:5172"
    echo "管理 API:    http://localhost:8082"
}

# 查看日志
show_logs() {
    local service="${1:-}"
    cd "$DEPLOY_DIR"
    
    if [ -z "$service" ] || [ "$service" == "all" ]; then
        docker-compose logs -f --tail=100
    else
        docker-compose logs -f --tail=100 "$service"
    fi
}

# 停止服务
stop_services() {
    local target="${1:-all}"
    cd "$DEPLOY_DIR"
    
    if [ "$target" == "all" ]; then
        log "🛑 停止所有服务..."
        docker-compose down
    else
        log "🛑 停止服务: $target..."
        docker-compose stop "$target"
    fi
    
    log "✅ 服务已停止"
}

# 重启服务
restart_services() {
    local target="${1:-all}"
    cd "$DEPLOY_DIR"
    
    if [ "$target" == "all" ]; then
        log "🔄 重启所有服务..."
        docker-compose restart
    else
        log "🔄 重启服务: $target..."
        docker-compose restart "$target"
    fi
    
    sleep 5
    health_check
    log "✅ 服务已重启"
}

# 清理系统
cleanup() {
    log "🧹 清理系统..."
    
    # 清理未使用镜像
    docker image prune -af --filter "until=168h" > /dev/null 2>&1 || true
    
    # 清理已停止容器
    docker container prune -f > /dev/null 2>&1 || true
    
    # 清理卷
    docker volume prune -f > /dev/null 2>&1 || true
    
    log "✅ 清理完成"
}

# 初始化服务器
init_server() {
    log "🔧 初始化服务器..."
    
    # 创建必要目录
    mkdir -p /opt/fluent-life
    mkdir -p /opt/backups
    mkdir -p /var/log/fluent-life
    
    # 安装 Docker（如果未安装）
    if ! command -v docker &> /dev/null; then
        log "📦 安装 Docker..."
        curl -fsSL https://get.docker.com | sh
        systemctl enable docker
        systemctl start docker
    fi
    
    # 安装 Docker Compose
    if ! command -v docker-compose &> /dev/null; then
        log "📦 安装 Docker Compose..."
        apt update
        apt install -y docker-compose
    fi
    
    log "✅ 服务器初始化完成"
}

# 显示帮助
show_help() {
    echo "Fluent Life 部署脚本"
    echo ""
    echo "用法: $0 [命令] [参数]"
    echo ""
    echo "部署命令:"
    echo "  all              部署全部服务（含数据库、Redis、前后端）"
    echo "  api              只部署主后端 API"
    echo "  frontend         只部署主前端"
    echo "  admin-api        只部署管理后台后端"
    echo "  admin            只部署管理后台前端"
    echo ""
    echo "运维命令:"
    echo "  status           查看服务状态和资源使用"
    echo "  logs [服务名]    查看日志（默认全部，如: logs api）"
    echo "  stop [服务名]    停止服务（默认全部）"
    echo "  restart [服务名] 重启服务（默认全部）"
    echo "  backup           备份数据库"
    echo "  cleanup          清理系统（镜像、容器、卷）"
    echo "  init             初始化服务器（安装 Docker 等）"
    echo ""
    echo "示例:"
    echo "  $0 all                    # 完整部署"
    echo "  $0 api                    # 只更新后端"
    echo "  $0 logs api               # 查看后端日志"
    echo "  $0 restart frontend       # 重启前端"
    echo "  $0 backup                 # 备份数据库"
    echo ""
}

# 主函数
main() {
    local command="${1:-help}"
    
    case "$command" in
        all)
            check_environment
            backup
            deploy_all
            ;;
        api|frontend|admin|admin-api)
            check_environment
            deploy_service "$command"
            ;;
        status)
            show_status
            ;;
        logs)
            show_logs "${2:-all}"
            ;;
        stop)
            stop_services "${2:-all}"
            ;;
        restart)
            restart_services "${2:-all}"
            ;;
        backup)
            backup
            ;;
        cleanup)
            cleanup
            ;;
        init)
            init_server
            ;;
        help|--help|-h|*)
            show_help
            ;;
    esac
}

# 执行
main "$@"
