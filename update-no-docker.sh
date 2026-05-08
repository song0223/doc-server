#!/bin/bash

# 快速更新脚本（不使用Docker）
SERVER="47.100.236.45"

echo "📦 打包更新文件..."
tar -czf update.tar.gz Package.swift Sources/

echo "📤 上传到服务器..."
scp update.tar.gz root@$SERVER:/tmp/

echo "🔧 在服务器上更新..."
ssh root@$SERVER << 'EOF'
    cd /opt/doc-server

    # 解压更新
    tar -xzf /tmp/update.tar.gz
    rm /tmp/update.tar.gz

    # 重新编译
    export PATH=/opt/swift/usr/bin:$PATH
    swift build -c release

    # 重启服务
    systemctl restart doc-server

    echo "✅ 更新完成！"
    systemctl status doc-server --no-pager
EOF

# 清理本地临时文件
rm update.tar.gz

echo "🎉 更新完成！"
