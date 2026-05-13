#!/bin/bash

# 文档服务器部署脚本（使用 Docker）
# 使用方法: ./deploy.sh

REMOTE_DIR="/opt/doc-server"

echo "🚀 开始部署文档服务器..."

# 1. 在服务器上克隆或更新代码
echo "📥 获取最新代码..."
ssh root@服务器ip << 'EOF'
    # 克隆或更新代码
    if [ -d "/opt/doc-server" ]; then
        cd /opt/doc-server
        git pull
    else
        cd /opt
        git clone https://github.com/song0223/doc-server.git
        cd doc-server
    fi

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
    echo "🌐 访问地址: http://服务器ip:8088"
EOF

echo "🎉 部署完成！"
echo "📋 后续步骤："
echo "   1. 在服务器上配置 Nginx 反向代理"
echo "   2. 绑定域名到服务器 IP"
echo "   3. 配置 SSL 证书（可选）"
