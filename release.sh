#!/bin/bash

# 发布脚本 - 在本地 Mac 执行
# 编译 Linux 版本并提交到 git

echo "🔨 编译 Linux 版本..."
GOOS=linux GOARCH=amd64 go build -o doc-server .

echo "📤 提交到 git..."
git add doc-server
git commit -m "release: 更新二进制文件"
git push origin master

echo "✅ 发布完成！服务器执行 git pull && ./doc-server 即可更新"
