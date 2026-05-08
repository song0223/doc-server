#!/bin/bash

# 快速更新脚本 - 只更新代码并重新构建
SERVER="47.100.236.45"
REMOTE_DIR="/opt/doc-server"

echo "📦 打包更新文件..."
tar -czf update.tar.gz Package.swift Sources/

echo "📤 上传到服务器..."
scp update.tar.gz root@$SERVER:/tmp/

echo "🔧 在服务器上更新..."
ssh root@$SERVER << 'EOF'
    cd /opt/doc-server

    # 解压更新
    tar -xzf /tmp/update.tar.gz

    # 重新构建并重启
    docker-compose up -d --build

    # 清理
    rm /tmp/update.tar.gz

    echo "✅ 更新完成！"
EOF

# 清理本地临时文件
rm update.tar.gz

echo "🎉 更新完成！"
