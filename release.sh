#!/bin/bash

# 发布脚本 - 在本地 Mac 执行
# 编译 Linux 版本并提交到 git

echo "🔨 编译 Linux 版本..."
GOOS=linux GOARCH=amd64 go build -o doc-server .

echo "📤 推送到 GitHub..."
git add doc-server
git commit -m "release: 更新二进制文件"
git push origin master

echo "📤 推送到 Gitee..."
git push gitee master

# 自动更新服务器（如果配置了 server.conf）
if [ -f server.conf ]; then
    source server.conf
    if [ -n "$SSH_HOST" ] && [ -n "$REMOTE_PATH" ]; then
        echo "🚀 自动更新服务器..."
        ssh "$SSH_HOST" "cd $REMOTE_PATH && ./update.sh"
        echo "✅ 发布完成！服务器已自动更新"
    else
        echo "⚠️  server.conf 未配置完整，跳过自动更新"
    fi
else
    echo "✅ 发布完成！服务器执行 git pull && ./doc-server 即可更新"
fi
