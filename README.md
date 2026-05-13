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

### 1. 发布（本地 Mac 执行）

```bash
./release.sh
```

自动编译 Linux 版本并提交到 git。

### 2. 更新（服务器执行）

```bash
./update.sh
```

自动拉取代码并重启服务。

## 配置 Nginx 反向代理

1. 安装 Nginx
```bash
# CentOS
yum install -y nginx

# Ubuntu
apt-get install -y nginx
```

2. 复制配置文件
```bash
cp nginx.conf /etc/nginx/conf.d/doc-server.conf
# 编辑配置文件，把 your-domain.com 改成你的域名
```

3. 重启 Nginx
```bash
systemctl restart nginx
systemctl enable nginx
```

4. 访问
```
http://你的域名
```

## API 接口

| 路径 | 说明 |
|------|------|
| `/login` | 登录页面 |
| `/` | 文档首页 |
| `/doc/{projectID}` | 查看文档 |
| `/health` | 健康检查 |
