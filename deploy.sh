#!/bin/bash

# 文档服务器部署脚本（使用 Docker）
# 在服务器上直接执行: ./deploy.sh

echo "🚀 开始部署文档服务器..."

# 安装 Docker（如果没有）
if ! command -v docker &> /dev/null; then
    echo "📦 安装 Docker..."
    curl -fsSL https://get.docker.com -o get-docker.sh
    sh get-docker.sh
    systemctl enable docker
    systemctl start docker
fi

# 安装 Docker Compose（如果没有）
if ! command -v docker-compose &> /dev/null; then
    echo "📦 安装 Docker Compose..."
    curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    chmod +x /usr/local/bin/docker-compose
fi

# 停止旧容器
docker-compose down 2>/dev/null || true

# 构建并启动
echo "🔨 构建并启动服务..."
docker-compose up -d --build

echo "✅ 部署完成！"
echo "🌐 访问地址: http://$(hostname -I | awk '{print $1}'):8088"
