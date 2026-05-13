#!/bin/bash

# 一键更新脚本 - 在服务器上执行
# ./update.sh

# GitHub 镜像加速（国内服务器用 ghproxy，海外可注释掉）
GITHUB_MIRROR="https://ghproxy.net/https://github.com/"
ORIGINAL_REMOTE="git@github.com:song0223/doc-server.git"
MIRROR_REMOTE="${GITHUB_MIRROR}song0223/doc-server.git"

echo "📥 拉取最新代码..."
MAX_RETRY=3

# 尝试镜像拉取
for i in $(seq 1 $MAX_RETRY); do
    git pull && break
    echo "⚠️  拉取失败，${i}/${MAX_RETRY} 次重试..."
    # 切换到镜像重试
    if [ $i -eq 1 ]; then
        echo "🔄 切换到镜像: $GITHUB_MIRROR"
        git remote set-url origin "$MIRROR_REMOTE"
    fi
    sleep 3
done

echo "🔄 重启服务..."
pkill -f doc-server 2>/dev/null
sleep 1
chmod +x doc-server
nohup ./doc-server > doc-server.log 2>&1 &

echo "✅ 更新完成！"
echo "📋 查看日志: tail -f doc-server.log"

# 恢复原始远程地址（方便本地 push）
git remote set-url origin "$ORIGINAL_REMOTE" 2>/dev/null
