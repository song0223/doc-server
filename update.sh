#!/bin/bash

# 一键更新脚本 - 在服务器上执行
# ./update.sh

echo "📥 拉取最新代码..."
MAX_RETRY=3
for i in $(seq 1 $MAX_RETRY); do
    git pull && break
    echo "⚠️  拉取失败，${i}/${MAX_RETRY} 次重试..."
    sleep 3
done

echo "🔄 重启服务..."
pkill -f doc-server 2>/dev/null
sleep 1
chmod +x doc-server
nohup ./doc-server > doc-server.log 2>&1 &

echo "✅ 更新完成！"
echo "📋 查看日志: tail -f doc-server.log"
