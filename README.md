# Fluent Life 部署中心

本目录包含 Fluent Life 项目的全局部署配置和脚本。

## 📁 目录结构

```
deploy/
├── docker-compose.yml          # 全局生产环境编排
├── docker-compose.override.yml # 本地开发覆盖配置
├── scripts/                    # 部署脚本
│   ├── deploy.sh              # 主部署脚本 ⭐
│   ├── backup.sh              # 数据库备份
│   ├── health-check.sh        # 健康检查
│   └── ...
├── config/                     # 配置文件
│   ├── .env.example           # 环境变量模板
│   └── ssl/                   # SSL证书目录
└── README.md                   # 本文档
```

## 🚀 快速开始

### 1. 服务器初始化（新服务器只需执行一次）

```bash
cd /opt/fluent-life/deploy
./scripts/deploy.sh init
```

### 2. 配置环境变量

```bash
cd /opt/fluent-life/deploy

# 复制模板
cp config/.env.example .env

# 编辑配置
vim .env

# 必须配置：
# - DB_PASSWORD: 数据库密码
# - JWT_SECRET: JWT密钥
# - REDIS_PASSWORD: Redis密码（可选）
```

### 3. 一键部署

```bash
# 部署全部服务
./scripts/deploy.sh all

# 部署完成后查看状态
./scripts/deploy.sh status
```

## 📋 常用命令

### 部署命令

```bash
# 部署全部服务（包含数据库、Redis、前后端）
./scripts/deploy.sh all

# 只部署主后端 API
./scripts/deploy.sh api

# 只部署主前端
./scripts/deploy.sh frontend

# 只部署管理后台后端
./scripts/deploy.sh admin-api

# 只部署管理后台前端
./scripts/deploy.sh admin
```

### 运维命令

```bash
# 查看服务状态
./scripts/deploy.sh status

# 查看日志（全部）
./scripts/deploy.sh logs

# 查看指定服务日志
./scripts/deploy.sh logs api
./scripts/deploy.sh logs frontend

# 重启服务
./scripts/deploy.sh restart
./scripts/deploy.sh restart api

# 停止服务
./scripts/deploy.sh stop
./scripts/deploy.sh stop frontend

# 备份数据库
./scripts/deploy.sh backup

# 清理系统
./scripts/deploy.sh cleanup
```

## 🔧 高级配置

### 使用本地数据库（开发环境）

创建 `docker-compose.override.yml`：

```yaml
version: '3.8'
services:
  api:
    environment:
      DB_HOST: host.docker.internal  # 使用本机数据库
```

### 配置 HTTPS

将 SSL 证书放入 `config/ssl/` 目录：

```
config/ssl/
├── cert.pem    # 证书文件
└── key.pem     # 私钥文件
```

修改 `docker-compose.yml` 中的 Nginx 配置，启用 443 端口。

## 📊 服务访问

部署完成后，可以通过以下地址访问：

| 服务 | 地址 | 说明 |
|------|------|------|
| 主前端 | http://localhost | 用户端网页 |
| 主 API | http://localhost:8081 | 后端 API |
| 管理前端 | http://localhost:5172 | 管理后台 |
| 管理 API | http://localhost:8082 | 管理后台 API |

## 🔄 自动部署

配合 GitHub Actions 使用，可以实现代码推送后自动部署：

1. 在 GitHub 仓库 Settings → Secrets 中添加：
   - `SERVER_HOST`: 服务器 IP
   - `SERVER_USER`: SSH 用户名
   - `SSH_PRIVATE_KEY`: SSH 私钥

2. 推送代码到 main 分支，自动触发部署

## 🐛 故障排查

### 服务无法启动

```bash
# 查看详细日志
./scripts/deploy.sh logs

# 检查端口占用
netstat -tulpn | grep 8081

# 重启所有服务
./scripts/deploy.sh restart
```

### 数据库连接失败

```bash
# 检查数据库容器
docker ps | grep postgres

# 查看数据库日志
./scripts/deploy.sh logs postgres
```

### 部署后页面未更新

```bash
# 强制重新构建
./scripts/deploy.sh cleanup
./scripts/deploy.sh all
```

## 📚 相关文档

- [生产环境部署清单](../docs/deployment/生产环境部署清单.md)
- [CI/CD 配置](../.github/workflows/README.md)

## ⚠️ 注意事项

1. **生产环境必须配置 `.env` 文件**
2. **数据库密码建议使用强密码**
3. **定期执行备份**: `./scripts/deploy.sh backup`
4. **监控日志文件**: `/var/log/fluent-life/`

---

**快速命令速查表：**

```bash
./scripts/deploy.sh all      # 完整部署
./scripts/deploy.sh status   # 查看状态
./scripts/deploy.sh logs     # 查看日志
./scripts/deploy.sh backup   # 备份数据库
```
