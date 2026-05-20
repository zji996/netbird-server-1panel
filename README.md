# NetBird Server 1Panel 部署维护

这个仓库用于维护一套精简的 NetBird 服务端部署：`netbirdio/dashboard` + `netbirdio/netbird-server` combined server，由 1Panel OpenResty 负责公网 HTTPS 和路径转发。

仓库只关注服务端部署、配置生成、状态查看、备份和卸载，不处理客户端安装。

## 默认部署画像

- 配置入口：TUI 中的 deployment profile
- Profile 存储：`profiles/<name>/profile.env`，已被 `.gitignore` 忽略
- 示例配置：`netbird-server.env.example`，仅作为自动化/开发参考
- 部署目录：由 `NETBIRD_INSTALL_DIR` 控制，默认 `/root/netbird-docker`
- 域名：由 `NETBIRD_DOMAIN` 控制，默认 `netbird.example.com`
- Dashboard 本地端口：由 `NETBIRD_DASHBOARD_PORT` 控制，默认 `127.0.0.1:18084`
- Combined server 本地端口：由 `NETBIRD_SERVER_PORT` 控制，默认 `127.0.0.1:18085`
- STUN UDP 公网端口：由 `NETBIRD_STUN_PORT` 控制，默认 `13478/udp`
- 1Panel OpenResty location 文件：默认按域名推导，也可用 `NETBIRD_1PANEL_ROOT_CONF` 覆盖
- 容器：`netbird-dashboard`、`netbird-server`

## 目录说明

- `netbird-server-tui.sh`：服务端维护 TUI，一键生成、安装、查看、备份、卸载。
- `profiles/`：本机部署 profile 目录，内容不入库；复配时从 TUI 选择已有 profile。
- `netbird-server.env.example`：配置示例，主要给自动化或人工排查参考，普通使用不需要直接编辑。
- `lib/`：TUI 脚本模块，按通用工具、模板渲染、操作命令、菜单和自测拆分。
- `docker-compose.yml`：脱敏后的当前 compose 摘要。
- `1panel-openresty-root.conf`：脱敏后的当前 1Panel OpenResty location 摘要。
- `netbird/`：NetBird 源码 submodule，用来参考 upstream 的 combined server 配置和脚本。

敏感或运行态文件不入库：`config.yaml`、`dashboard.env`、`data/`、SQLite 数据库、TLS 私钥、管理员凭据、日志和备份包。

## 使用方式

给脚本执行权限：

```bash
chmod +x ./netbird-server-tui.sh
```

打开 TUI：

```bash
./netbird-server-tui.sh
```

主菜单默认进入“部署向导”。如果已经有 profile，向导会先问你是否复用；没有 profile 时会新建一个。随后在一个表单里配置大多数信息：域名、安装目录、HTTP/HTTPS、本地端口、STUN 端口和 1Panel `root.conf` 路径。最后用勾选项决定是否保存 profile、生成服务文件、在 TUI 内预览 OpenResty 配置、写入 1Panel、启动容器。

最少操作路径：

```bash
./netbird-server-tui.sh
```

如果使用命令行自动化，可直接运行：

```bash
./netbird-server-tui.sh wizard
```

复用已有 profile：

```bash
./netbird-server-tui.sh --profile <name> status
./netbird-server-tui.sh --profile <name> install
```

进入 TUI 时会先选择界面语言，默认中文。非交互模式也默认中文，可用 `--lang en` 或 `NETBIRD_LANG=en` 切换英文：

```bash
./netbird-server-tui.sh --lang en status
NETBIRD_LANG=en ./netbird-server-tui.sh --noninteractive status
```

高级菜单里仍保留了底层操作：

- `render`：只生成 `docker-compose.yml`、`config.yaml`、`dashboard.env`，不启动容器。
- `1panel-preview`：在 TUI 中预览 OpenResty location。
- `1panel-apply`：写入 1Panel `root.conf`，写入前会备份旧文件。
- `install`：生成服务文件并启动容器。
- `doctor`：检查 Docker、Compose、本地端口、80/443、UDP STUN 提示和 1Panel 路径。

推荐把长期配置保存成 profile。`profiles/` 下的实际 profile 已被 git ignore，可以放心保存本机路径、域名和端口。命令行参数只用于临时覆盖；自动化场景也可以使用 `--profile <name>`、`--config <file>` 或当前 shell 中的 `NETBIRD_*` 环境变量。

## HTTP/HTTPS

默认是 `https`，适合 1Panel 已经为站点配置 SSL 的情况。脚本会检查 80/443 端口状态，提醒是否可能被占用。

如果只是本机测试、可信内网，或者前面还有其他代理负责 TLS，可以在向导里把公网协议改为 `http`。自动化时也可以设置：

```bash
NETBIRD_PUBLIC_SCHEME=http
NETBIRD_PUBLIC_PORT=80
```

HTTP 模式会让 OpenResty 配置使用 `X-Forwarded-Proto: http`，并不输出 HSTS。除非你明确知道登录流量不会暴露，否则生产环境仍建议使用 HTTPS。

## 本机测试

非破坏性自测：

```bash
./netbird-server-tui.sh self-test
```

自测会在 `/tmp/netbird-server-tui/self-test-install` 渲染 compose、`config.yaml`、`dashboard.env` 和模拟的 `root.conf`，并检查关键字段。它不会启动真实服务，也不会改动 1Panel。

如果要完整试跑 Docker 行为，可使用沙盒目录和测试端口：

```bash
cp netbird-server.env.example /tmp/netbird-server.env
./netbird-server-tui.sh \
  --config /tmp/netbird-server.env \
  --install-dir /tmp/netbird-server-tui/run \
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
