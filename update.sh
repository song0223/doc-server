#!/bin/bash

# 一键更新脚本
# 在服务器上执行: ./update.sh

echo "📥 拉取最新代码..."
git pull

echo "🔨 编译..."
GOOS=linux GOARCH=amd64 go build -o doc-server .

echo "🔄 重启服务..."
pkill -f doc-server 2>/dev/null
sleep 1
nohup ./doc-server > doc-server.log 2>&1 &

echo "✅ 更新完成！"
echo "📋 查看日志: tail -f doc-server.log"
