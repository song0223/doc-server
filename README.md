# API 文档服务器

基于 Go 的 API 文档服务器，从 MySQL 数据库读取文档数据并提供 Web 访问。

## 功能

- 从 MySQL 读取 API 文档
- 密码登录保护
- 响应式 Web 界面
- 单二进制部署，无依赖

## 配置

编辑 `config.yaml`：

```yaml
server:
  port: 8088

database:
  host: 127.0.0.1
  port: 3306
  username: root
  password: ""
  database: mac_api_tester

auth:
  password: "your-password-here"
```

## 本地开发

```bash
go run .
```

## 部署

### 1. 交叉编译

```bash
# Mac 上编译 Linux 版本
GOOS=linux GOARCH=amd64 go build -o doc-server .
```

### 2. 上传到服务器

```bash
scp doc-server config.yaml root@服务器ip:/opt/doc-server/
```

### 3. 运行

```bash
cd /opt/doc-server
chmod +x doc-server
./doc-server
```

## 更新

```bash
cd /opt/doc-server
git pull
GOOS=linux GOARCH=amd64 go build -o doc-server .
pkill -f doc-server
nohup ./doc-server > doc-server.log 2>&1 &
```

## API 接口

| 路径 | 说明 |
|------|------|
| `/login` | 登录页面 |
| `/` | 文档首页 |
| `/doc/{projectID}` | 查看文档 |
| `/health` | 健康检查 |
