#!/bin/bash

# 文档服务器部署脚本
# 使用方法: ./deploy.sh

SERVER="127.0.0.1"  # 服务器IP，用于SSH连接
REMOTE_DIR="/opt/doc-server"

echo "🚀 开始部署文档服务器..."

# 1. 打包项目
echo "📦 打包项目..."
tar -czf doc-server.tar.gz \
    Package.swift \
    Sources/ \
    Dockerfile \
    docker-compose.yml \
    nginx.conf

# 2. 上传到服务器
echo "📤 上传到服务器..."
scp doc-server.tar.gz root@$SERVER:/tmp/

# 3. 在服务器上部署
echo "🔧 在服务器上部署..."
ssh root@$SERVER << 'EOF'
    # 创建目录
    mkdir -p /opt/doc-server
    cd /opt/doc-server

    # 解压
    tar -xzf /tmp/doc-server.tar.gz

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
    echo "🌐 访问地址: http://$SERVER:8088"
EOF

# 4. 清理临时文件
rm doc-server.tar.gz

echo "🎉 部署完成！"
echo "📋 后续步骤："
echo "   1. 在服务器上配置 Nginx 反向代理"
echo "   2. 绑定域名到服务器 IP"
echo "   3. 配置 SSL 证书（可选）"
