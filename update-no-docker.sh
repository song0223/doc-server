#!/bin/bash

# 快速更新脚本（不使用Docker）
# 在服务器上直接执行: ./update-no-docker.sh

echo "🔄 开始更新文档服务器..."

# 拉取最新代码
echo "📥 拉取最新代码..."
git pull

# 重新编译
echo "🔨 重新编译..."
export PATH=/opt/swift/usr/bin:$PATH
swift build -c release

# 重启服务
systemctl restart doc-server

echo "✅ 更新完成！"
systemctl status doc-server --no-pager
