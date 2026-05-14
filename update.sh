#!/bin/bash

# 一键更新脚本 - 在服务器上执行
# ./update.sh

# 确保 remote 指向 Gitee（国内服务器拉取更快）
GITEE_REMOTE="git@gitee.com:song0223/doc-server.git"
CURRENT_REMOTE=$(git remote get-url origin 2>/dev/null)

if [ "$CURRENT_REMOTE" != "$GITEE_REMOTE" ]; then
    echo "🔧 设置 remote 为 Gitee..."
    git remote set-url origin "$GITEE_REMOTE"
fi

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
