# NetBird Server 1Panel 部署维护

这个仓库用于维护一套精简的 NetBird 服务端部署：`netbirdio/dashboard` + `netbirdio/netbird-server` combined server，由 1Panel OpenResty 负责公网 HTTPS 和路径转发。

仓库只关注服务端部署、配置生成、状态查看、备份和卸载，不处理客户端安装。

## 当前部署约定

- 部署目录：`/root/netbird-docker`
- 域名：`netbird.example.com`
- Dashboard 本地端口：`127.0.0.1:18084`
- Combined server 本地端口：`127.0.0.1:18085`
- STUN UDP 公网端口：`13478/udp`
- 1Panel OpenResty location 文件：`/opt/1panel/apps/openresty/openresty/www/sites/netbird.example.com/proxy/root.conf`
- 容器：`netbird-dashboard`、`netbird-server`

## 目录说明

- `netbird-server-tui.sh`：服务端维护 TUI，一键生成、安装、查看、备份、卸载。
- `lib/`：TUI 脚本模块，按通用工具、模板渲染、操作命令、菜单和自测拆分。
- `docker-compose.yml`：脱敏后的当前 compose 摘要。
- `1panel-openresty-root.conf`：脱敏后的当前 1Panel OpenResty location 摘要。
- `netbird/`：NetBird 源码 submodule，用来参考 upstream 的 combined server 配置和脚本。

敏感或运行态文件不入库：`config.yaml`、`dashboard.env`、`data/`、SQLite 数据库、TLS 私钥、管理员凭据、日志和备份包。

## 还差什么

现有摘要已经能说明容器和反代形态，但真正一键部署还需要脚本补齐这些内容：

- 生成 `config.yaml`：包含 `server.exposedAddress`、`server.stunPorts`、relay `authSecret`、SQLite 加密 key、embedded IdP/OIDC 回调地址。
- 生成 `dashboard.env`：指向 `https://<domain>` 和 embedded IdP 的 `/oauth2`。
- 写入或预览 1Panel OpenResty `root.conf`：HTTP/WebSocket 转发给 `18085`，gRPC 用 `grpc_pass` 转给 `18085`，Dashboard 根路径转给 `18084`。
- 启停、重启、日志、状态检查：覆盖本地 dashboard、OIDC endpoint、公网 OIDC endpoint、OpenResty 配置存在性。
- 备份与卸载：保留或删除 `data/` 由操作时确认。
- 本机沙盒测试：验证脚本渲染、1Panel 配置生成和关键字段，不触碰真实 `/root` 或 `/opt/1panel`。

## 使用方式

给脚本执行权限：

```bash
chmod +x ./netbird-server-tui.sh
```

打开 TUI：

```bash
./netbird-server-tui.sh
```

直接渲染并启动默认部署：

```bash
./netbird-server-tui.sh install
```

只预览 1Panel OpenResty 配置：

```bash
./netbird-server-tui.sh 1panel-preview
```

写入 1Panel OpenResty 配置，脚本会先备份旧文件：

```bash
./netbird-server-tui.sh 1panel-apply
./netbird-server-tui.sh 1panel-check
```

查看状态：

```bash
./netbird-server-tui.sh status
```

## 本机测试

非破坏性自测：

```bash
./netbird-server-tui.sh self-test
```

自测会在 `/tmp/netbird-server-tui/self-test-install` 渲染 compose、`config.yaml`、`dashboard.env` 和模拟的 `root.conf`，并检查关键字段。它不会启动真实服务，也不会改动 1Panel。

如果要完整试跑 Docker 行为，可使用沙盒目录和测试端口：

```bash
./netbird-server-tui.sh \
  --install-dir /tmp/netbird-server-tui/run \
  --domain test.example.invalid \
  --dashboard-port 28084 \
  --server-port 28085 \
  --stun-port 23478 \
  render
```

随后可进入该目录执行 `docker compose config` 或 `docker compose up -d`。公网域名、证书和 1Panel 站点不存在时，公网 endpoint 检查会失败，这是预期现象。

## 1Panel 注意事项

1Panel 面板内是否“显示正常”主要取决于两点：

- 站点域名和 SSL 由 1Panel 正常创建。
- 站点的 `proxy/root.conf` 中存在本仓库生成的 location 规则。

脚本能写入和检查 `root.conf`，也会尝试发现运行中的 OpenResty 容器并执行 `nginx -t` / reload。1Panel UI 自身的数据结构不建议由脚本直接改数据库，避免面板状态和实际 Nginx 配置脱节。

## Submodule

首次克隆后拉取 NetBird 源码：

```bash
git submodule update --init --recursive
```

更新 submodule 到记录的提交：

```bash
git submodule update --recursive
```

进入 submodule 查看或更新 upstream：

```bash
cd netbird
git fetch origin
git checkout main
git pull --ff-only
cd ..
git add netbird
```

当前 submodule 来源：`https://github.com/zji996/netbird`。

## 推送到远端

本地仓库准备好后，添加远端并推送：

```bash
git remote add origin <your-repo-url>
git push -u origin main
```

如果使用 GitHub CLI 创建私有仓库：

```bash
gh repo create zji996/netbird-server-1panel --private --source=. --remote=origin --push
```
