# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

API 文档服务器 — 从 MySQL 数据库读取 Markdown 格式的 API 文档，提供带密码认证的 Web 界面。是 MacAPITester 的配套工具。单二进制部署，无外部依赖。

## Development Commands

```bash
go run .                          # 本地开发运行 (默认端口 8088)
go build -o doc-server .          # 本地构建
./release.sh                      # 交叉编译 Linux amd64 + 提交二进制 + push
./deploy.sh / ./update.sh         # 服务器端：拉取代码并重启服务
```

无测试、无 linter 配置。

## Architecture

单 package (`package main`)，所有 Go 源码在根目录，无子包。

**请求流程：** `main.go` → 加载配置 → 连接 MySQL → 创建 Handler → `http.ListenAndServe`

| 文件 | 职责 |
|---|---|
| `main.go` | 入口，组装各组件 |
| `config.go` | 读取 `config.yaml`，定义 Config 结构体 |
| `db.go` | MySQL 连接 + `api_documents` 表查询（`FetchAllDocs` / `FetchDoc`）|
| `handler.go` | 路由、认证中间件、Markdown 渲染（gomarkdown/markdown）|

**路由：** `GET /health`, `GET|POST /login`, `GET /`, `GET /doc/{projectID}`

**认证：** 基于内存 `sync.Map` 的 session，cookie 传递随机 token，重启后会话丢失。

**前端：** `templates/` 下 3 个 Go HTML 模板，纯 HTML+CSS+JS，无构建工具。

**数据模型：** 单表 `api_documents`（id, project_id, title, html_content）。

## Key Dependencies

仅 3 个：`go-sql-driver/mysql`、`gopkg.in/yaml.v3`、`gomarkdown/markdown`。无 web 框架，无 ORM。

## Deployment

二进制文件直接提交到 git。流程：Mac 上 `release.sh` 交叉编译 → commit → push；服务器上 `update.sh` 拉取并重启。Nginx 反向代理配置见 `nginx.conf`。
