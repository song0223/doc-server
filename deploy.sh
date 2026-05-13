#!/bin/bash

# 文档服务器部署脚本（Go 版本）
# 在服务器上直接执行: ./deploy.sh

echo "🚀 开始部署文档服务器..."

# 拉取最新代码
echo "📥 拉取最新代码..."
git pull

# 停止旧进程
pkill -f doc-server || true
sleep 1

# 启动服务
echo "🚀 启动服务..."
nohup ./doc-server > doc-server.log 2>&1 &

echo "✅ 部署完成！"
echo "📋 查看日志: tail -f doc-server.log"
