#!/bin/bash

# 文档服务器部署脚本（Go 版本）
# 在服务器上直接执行: ./deploy.sh

# 确保 remote 指向 Gitee（国内服务器拉取更快）
GITEE_REMOTE="https://gitee.com/song0223/doc-server.git"
CURRENT_REMOTE=$(git remote get-url origin 2>/dev/null)

if [ "$CURRENT_REMOTE" != "$GITEE_REMOTE" ]; then
    echo "🔧 设置 remote 为 Gitee..."
    git remote set-url origin "$GITEE_REMOTE"
fi

echo "🚀 开始部署文档服务器..."

# 拉取最新代码
echo "📥 拉取最新代码（Gitee）..."
git pull

# 停止旧进程
pkill -f doc-server || true
sleep 1

# 启动服务
echo "🚀 启动服务..."
nohup ./doc-server > doc-server.log 2>&1 &

echo "✅ 部署完成！"
echo "📋 查看日志: tail -f doc-server.log"
