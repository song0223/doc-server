#!/bin/bash

# 本地直接部署到服务器（不经过 GitHub）
# 用法: ./deploy-local.sh user@server-ip:/path/to/doc-server

if [ -z "$1" ]; then
    echo "用法: ./deploy-local.sh user@server-ip:/path/to/doc-server"
    echo "示例: ./deploy-local.sh root@1.2.3.4:/opt/doc-server"
    exit 1
fi

TARGET="$1"
REMOTE="${TARGET%%:*}"
REMOTE_PATH="${TARGET#*:}"

echo "🔨 编译 Linux 版本..."
GOOS=linux GOARCH=amd64 go build -o doc-server . || { echo "❌ 编译失败"; exit 1; }

echo "📦 上传文件到 $TARGET ..."
scp doc-server "$TARGET/doc-server" || { echo "❌ 上传失败"; exit 1; }
scp templates/*.html "$TARGET/templates/" || { echo "❌ 上传模板失败"; exit 1; }

echo "🔄 重启远程服务..."
ssh "$REMOTE" "cd $REMOTE_PATH && pkill -f doc-server 2>/dev/null; sleep 1; chmod +x doc-server; nohup ./doc-server > doc-server.log 2>&1 &"

echo "✅ 部署完成！"
