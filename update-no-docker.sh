#!/bin/bash

# 快速更新脚本（不使用Docker）
# 使用方法: ./update-no-docker.sh

echo "🔄 开始更新文档服务器..."

ssh root@服务器ip << 'EOF'
    cd /opt/doc-server

    # 拉取最新代码
    echo "📥 拉取最新代码..."
    git pull

    # 重新编译
    echo "🔨 重新编译..."
    export PATH=/opt/swift/usr/bin:$PATH
    swift build -c release

    # 重启服务
    systemctl restart doc-server

    echo "✅ 更新完成！"
    systemctl status doc-server --no-pager
EOF

echo "🎉 更新完成！"
