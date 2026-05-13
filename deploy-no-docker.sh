#!/bin/bash

# 文档服务器部署脚本（不使用Docker）
# 在服务器上直接执行: ./deploy-no-docker.sh

echo "🚀 开始部署文档服务器..."

# 安装依赖（如果没有）
if ! command -v swift &> /dev/null; then
    echo "📦 安装 Swift 5.7.3（CentOS 7 兼容版本）..."
    # CentOS 7 依赖
    yum install -y clang gcc gcc-c++ libicu libicu-devel libcurl-devel mysql-devel binutils-devel
    yum install -y centos-release-scl
    yum install -y devtoolset-9
    source /opt/rh/devtoolset-9/enable

    # 下载 Swift 5.7.3（最后支持 CentOS 7 的版本）
    wget https://download.swift.org/swift-5.7.3-release/centos7/swift-5.7.3-RELEASE/swift-5.7.3-RELEASE-centos7.tar.gz
    tar xzf swift-5.7.3-RELEASE-centos7.tar.gz
    mv swift-5.7.3-RELEASE-centos7 /opt/swift
    echo 'export PATH=/opt/swift/usr/bin:$PATH' >> /etc/profile.d/swift.sh
    echo 'source /opt/rh/devtoolset-9/enable' >> /etc/profile.d/swift.sh
    source /etc/profile.d/swift.sh
    rm swift-5.7.3-RELEASE-centos7.tar.gz
fi

# 编译
echo "🔨 编译项目..."
export PATH=/opt/swift/usr/bin:$PATH
swift build -c release

# 停止旧进程
pkill -f DocServer || true
sleep 1

# 创建 systemd 服务
cat > /etc/systemd/system/doc-server.service << 'SERVICEEOF'
[Unit]
Description=API Documentation Server
After=network.target mysql.service

[Service]
Type=simple
User=root
WorkingDirectory=/opt/doc-server
Environment=DB_HOST=127.0.0.1
Environment=DB_PORT=3306
Environment=DB_DATABASE=mac_api_tester
Environment=DB_USERNAME=root
Environment=DB_PASSWORD=
Environment=SERVER_PORT=8088
ExecStart=/opt/doc-server/.build/release/DocServer
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
SERVICEEOF

# 启动服务
systemctl daemon-reload
systemctl enable doc-server
systemctl restart doc-server

echo "✅ 部署完成！"
systemctl status doc-server --no-pager
