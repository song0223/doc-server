#!/bin/bash

# 文档服务器部署脚本（不使用Docker）
SERVER="47.100.236.45"
REMOTE_DIR="/opt/doc-server"

echo "🚀 开始部署文档服务器..."

# 1. 打包项目
echo "📦 打包项目..."
tar -czf doc-server.tar.gz Package.swift Sources/

# 2. 上传到服务器
echo "📤 上传到服务器..."
scp doc-server.tar.gz root@$SERVER:/tmp/

# 3. 在服务器上部署
echo "🔧 在服务器上部署..."
ssh root@$SERVER << 'EOF'
    # 创建目录
    mkdir -p /opt/doc-server
    cd /opt/doc-server

    # 解压
    tar -xzf /tmp/doc-server.tar.gz
    rm /tmp/doc-server.tar.gz

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
Environment=DB_PASSWORD=Netime@2023
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
EOF

# 4. 清理临时文件
rm doc-server.tar.gz

echo "🎉 部署完成！"
echo "📋 访问地址: http://$SERVER:8088"
echo ""
echo "常用命令："
echo "  查看状态: ssh root@$SERVER 'systemctl status doc-server'"
echo "  查看日志: ssh root@$SERVER 'journalctl -u doc-server -f'"
echo "  重启服务: ssh root@$SERVER 'systemctl restart doc-server'"
