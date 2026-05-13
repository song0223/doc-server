#!/bin/bash

# 快速更新脚本 - 使用 Docker
# 在服务器上直接执行: ./update.sh

echo "🔄 开始更新文档服务器..."

# 拉取最新代码
echo "📥 拉取最新代码..."
git pull

# 重新构建并重启
echo "🔨 重新构建..."
docker-compose up -d --build

echo "✅ 更新完成！"
