#!/bin/bash
# ========================================
# 数据库备份脚本
# 用法: ./backup.sh [数据库名]
# 建议添加到 crontab: 0 2 * * * /opt/fluent-life/deploy/scripts/backup.sh
# ========================================

set -e

# 配置
BACKUP_DIR="/opt/backups/database"
DB_NAME="${1:-fluent_life}"
DB_USER="fluent_life"
RETENTION_DAYS=7
DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="${BACKUP_DIR}/${DB_NAME}_${DATE}.sql.gz"

# 创建备份目录
mkdir -p "$BACKUP_DIR"

echo "[$(date '+%Y-%m-%d %H:%M:%S')] 开始备份数据库: $DB_NAME..."

# 检查容器是否运行
if ! docker ps | grep -q "fluent-life-db"; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ❌ 数据库容器未运行"
    exit 1
fi

# 执行备份
if docker exec fluent-life-db pg_dump -U "$DB_USER" "$DB_NAME" 2>/dev/null | gzip > "$BACKUP_FILE"; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ✅ 备份成功: $BACKUP_FILE"
    ls -lh "$BACKUP_FILE"
else
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ❌ 备份失败"
    rm -f "$BACKUP_FILE"
    exit 1
fi

# 清理旧备份
echo "[$(date '+%Y-%m-%d %H:%M:%S')] 清理 ${RETENTION_DAYS} 天前的备份..."
find "$BACKUP_DIR" -name "${DB_NAME}_*.sql.gz" -mtime +$RETENTION_DAYS -delete 2>/dev/null || true

# 显示备份统计
BACKUP_COUNT=$(find "$BACKUP_DIR" -name "${DB_NAME}_*.sql.gz" | wc -l)
echo "[$(date '+%Y-%m-%d %H:%M:%S')] 当前备份数量: $BACKUP_COUNT"
echo "[$(date '+%Y-%m-%d %H:%M:%S')] 备份完成"
