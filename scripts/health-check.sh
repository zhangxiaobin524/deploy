#!/bin/bash
# ========================================
# 健康检查脚本
# 用法: ./health-check.sh
# 建议添加到 crontab: */5 * * * * /opt/fluent-life/deploy/scripts/health-check.sh
# ========================================

# 配置
API_URL="http://localhost:8081/health"
ADMIN_API_URL="http://localhost:8082/health"
FRONTEND_URL="http://localhost"
LOG_FILE="/var/log/fluent-life/health.log"
ALERT_WEBHOOK=""  # 钉钉/企业微信 webhook 地址
MAX_FAIL_COUNT=3
FAIL_COUNT_FILE="/tmp/fluent-life-fail-count"

# 初始化
mkdir -p "$(dirname "$LOG_FILE")"
touch "$FAIL_COUNT_FILE"

# 发送告警
send_alert() {
    local message="$1"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] 🚨 $message" >> "$LOG_FILE"
    
    if [ -n "$ALERT_WEBHOOK" ]; then
        curl -s -X POST "$ALERT_WEBHOOK" \
            -H "Content-Type: application/json" \
            -d "{\"msg\": \"$message\"}" > /dev/null 2>&1 || true
    fi
}

# 检查服务
check_service() {
    local name="$1"
    local url="$2"
    
    if curl -sf "$url" > /dev/null 2>&1; then
        return 0
    else
        return 1
    fi
}

# 重启服务
restart_service() {
    local service="$1"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] 🔄 尝试重启服务: $service" >> "$LOG_FILE"
    
    cd /opt/fluent-life/deploy || return 1
    docker-compose restart "$service" > /dev/null 2>&1
    
    sleep 10
    
    if check_service "$service" "http://localhost:8081/health"; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] ✅ $service 重启成功" >> "$LOG_FILE"
        return 0
    else
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] ❌ $service 重启失败" >> "$LOG_FILE"
        return 1
    fi
}

# 主逻辑
main() {
    local fail_count=$(cat "$FAIL_COUNT_FILE" 2>/dev/null || echo 0)
    local has_error=0
    
    # 检查主 API
    if ! check_service "API" "$API_URL"; then
        has_error=1
        fail_count=$((fail_count + 1))
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] ⚠️  API 健康检查失败 (${fail_count}/${MAX_FAIL_COUNT})" >> "$LOG_FILE"
        
        if [ "$fail_count" -ge "$MAX_FAIL_COUNT" ]; then
            send_alert "Fluent Life API 服务异常，连续 ${MAX_FAIL_COUNT} 次检查失败"
            restart_service "api" || send_alert "API 服务重启失败，请人工介入"
            fail_count=0
        fi
    else
        # API 正常，检查前端
        if ! check_service "Frontend" "$FRONTEND_URL"; then
            echo "[$(date '+%Y-%m-%d %H:%M:%S')] ⚠️  前端访问异常" >> "$LOG_FILE"
        fi
        
        # 重置失败计数
        if [ "$fail_count" -gt 0 ]; then
            echo "[$(date '+%Y-%m-%d %H:%M:%S')] ✅ 服务恢复正常" >> "$LOG_FILE"
            fail_count=0
        fi
    fi
    
    echo "$fail_count" > "$FAIL_COUNT_FILE"
}

main
