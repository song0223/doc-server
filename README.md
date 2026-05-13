# API 文档服务器

独立的 API 文档服务器，基于 SwiftNIO 构建，从 MySQL 数据库读取文档数据并提供 Web 访问。

## 功能特性

- 从 MySQL 数据库读取 API 文档
- 响应式 Web 界面
- 支持 Docker 部署
- 支持 Nginx 反向代理
- 健康检查接口

## 项目结构

```
doc-server/
├── Package.swift          # Swift Package 配置
├── Sources/
│   ├── CMySQL/           # MySQL C 库封装
│   └── DocServer/
│       ├── main.swift    # 程序入口
│       ├── MySQLDatabase.swift  # 数据库连接
│       ├── DocRepository.swift  # 数据访问层
│       ├── DocServer.swift      # HTTP 服务器
│       └── HTTPHandler.swift    # 请求处理
├── Dockerfile            # Docker 构建文件
├── docker-compose.yml    # Docker Compose 配置
├── nginx.conf            # Nginx 配置示例
└── deploy.sh             # 部署脚本
```

## 本地开发

### 前置要求

- macOS 13+ 或 Ubuntu 20.04+
- Swift 5.9+
- MySQL 客户端库

### 安装依赖

**macOS:**
```bash
brew install mysql-client
```

**Ubuntu:**
```bash
sudo apt-get install libmysqlclient-dev
```

### 运行

```bash
swift run
```

### 配置

通过环境变量配置：

| 变量 | 默认值 | 说明 |
|------|--------|------|
| DB_HOST | 127.0.0.1 | 数据库地址 |
| DB_PORT | 3306 | 数据库端口 |
| DB_DATABASE | mac_api_tester | 数据库名称 |
| DB_USERNAME | root | 数据库用户名 |
| DB_PASSWORD |  | 数据库密码 |
| SERVER_PORT | 8088 | 服务器端口 |

## 部署到服务器

### 方式一：使用部署脚本

```bash
./deploy.sh
```

脚本会自动：
1. 打包项目
2. 上传到服务器
3. 安装 Docker（如果需要）
4. 构建并启动服务

### 方式二：手动部署

1. **打包项目**
```bash
tar -czf doc-server.tar.gz Package.swift Sources/ Dockerfile docker-compose.yml
```

2. **上传到服务器**
```bash
scp doc-server.tar.gz root@127.0.0.1:/opt/
```

3. **在服务器上部署**
```bash
ssh root@127.0.0.1
cd /opt
tar -xzf doc-server.tar.gz
docker-compose up -d --build
```

### 方式三：直接编译运行

```bash
# 在服务器上安装 Swift 和 MySQL 客户端
sudo apt-get install libmysqlclient-dev

# 编译
swift build -c release

# 运行
.build/release/DocServer
```

## 配置 Nginx 反向代理

1. **安装 Nginx**
```bash
sudo apt-get install nginx
```

2. **配置站点**
```bash
sudo cp nginx.conf /etc/nginx/sites-available/doc-server
sudo ln -s /etc/nginx/sites-available/doc-server /etc/nginx/sites-enabled/
sudo nginx -t
sudo systemctl reload nginx
```

3. **配置域名解析**
将域名 A 记录指向服务器 IP `127.0.0.1`

## 访问地址

- 直接访问: `http://127.0.0.1:8088`
- 域名访问: `http://docs.yourdomain.com`（配置 Nginx 后）

## API 接口

| 路径 | 说明 |
|------|------|
| `/` | 文档首页，显示所有项目 |
| `/doc/{projectID}` | 查看指定项目的文档 |
| `/health` | 健康检查 |

## 数据库表结构

```sql
CREATE TABLE api_documents (
    id VARCHAR(36) PRIMARY KEY,
    project_id VARCHAR(36) NOT NULL,
    title VARCHAR(255) NOT NULL,
    html_content LONGTEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);
```
