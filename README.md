# NetBird Server 1Panel 部署维护

这个仓库用于维护一套精简的 NetBird 服务端部署：`netbirdio/dashboard` + `netbirdio/netbird-server` combined server，由 1Panel OpenResty 负责公网访问、SSL 和路径转发。

仓库只关注服务端部署、配置生成、状态查看、备份和卸载，不处理客户端安装。

## 默认部署画像

- 配置入口：TUI 中的 deployment profile
- Profile 存储：`profiles/<name>/profile.env`，已被 `.gitignore` 忽略
- 示例配置：`netbird-server.env.example`，仅作为自动化/开发参考
- 部署目录：由 `NETBIRD_INSTALL_DIR` 控制，默认 `/root/netbird-docker`
- 域名：由 `NETBIRD_DOMAIN` 控制，默认 `netbird.example.com`
- 对外访问协议：由 `NETBIRD_PUBLIC_SCHEME` 控制，默认 `http`
- Dashboard 本地端口：由 `NETBIRD_DASHBOARD_PORT` 控制，默认 `127.0.0.1:18084`
- Combined server 本地端口：由 `NETBIRD_SERVER_PORT` 控制，默认 `127.0.0.1:18085`
- STUN UDP 公网端口：由 `NETBIRD_STUN_PORT` 控制，默认 `13478/udp`
- 管理员账号：默认 `admin@<NETBIRD_DOMAIN>`，生成时自动创建随机密码
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

向导是纯文本问答：输入序号选择菜单，输入新值覆盖配置，直接回车保留方括号里的默认值。完整部署开始后会在终端输出阶段进度；首次拉取 Docker 镜像和等待 NetBird 初始化接口时可能会慢一些。

主菜单默认进入“部署向导”。向导主线是 4 步，选中已有 profile 时会多一个复用捷径页：

1. **选择 profile**：没有 profile 时自动新建；已有 profile 时直接列出，按域名展示，也可以选择「新建 profile」。
2. **复用捷径**（仅当选了已有 profile）：把当前 profile 摘要一屏展示，默认选项是「完整部署（保存 + 渲染 + 写 1Panel + 启动）」，也可以选「编辑设置 / 删除 profile / 取消」。
3. **基本配置**：只问三件事——域名、对外访问协议（默认 http，可改 https）、安装目录。其它字段使用默认值或 profile 已有值。
4. **高级配置**（默认跳过）：通过 yes/no 决定是否进入。需要时一并设置本地端口、绑定地址、公网端口、1Panel `root.conf` 路径、Profile 名称（默认从域名 sanitize 派生）。
5. **确认与执行**：屏上展示完整摘要 + 80/443 端口提示 + HTTP 提示，单选「完整部署 / 仅生成 / 仅保存 profile / 返回编辑 / 取消」。完整部署是默认选项。

最少操作路径：

```bash
./netbird-server-tui.sh
```

复用已有 profile 时只要 2 次回车（选 profile → 完整部署）就能跑完。

如果使用命令行自动化，可直接运行：

```bash
./netbird-server-tui.sh wizard
```

复用已有 profile 的非交互链路：

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
- `uninstall`：停止 compose 服务，并按确认清理生成配置、管理员凭据和数据目录；1Panel `root.conf` 会单独询问，默认不删除。

推荐把长期配置保存成 profile。`profiles/` 下的实际 profile 已被 git ignore，可以放心保存本机路径、域名和端口。命令行参数只用于临时覆盖；自动化场景也可以使用 `--profile <name>`、`--config <file>` 或当前 shell 中的 `NETBIRD_*` 环境变量。

## HTTP/HTTPS

默认是 `http`，对应 1Panel OpenResty 反代到本机容器的内部链路：脚本生成的 upstream 始终是 `http://127.0.0.1:<port>`。这样可以先跑通站点和服务，再在 1Panel 中按需要给网站套 SSL 证书。

如果 1Panel 站点对外启用并强制 HTTPS，需要在向导里把“对外访问协议”改为 `https`，或者自动化时设置：

```bash
NETBIRD_PUBLIC_SCHEME=https
NETBIRD_PUBLIC_PORT=443
```

如果保持默认 HTTP，自动化时可以显式设置：

```bash
NETBIRD_PUBLIC_SCHEME=http
NETBIRD_PUBLIC_PORT=80
```

这个字段控制 NetBird 生成的公网地址、OIDC issuer/redirect URI，以及 OpenResty 的 `X-Forwarded-Proto`。1Panel 只是给站点加证书时，记得同步改成 `https` 并重新生成配置，否则浏览器/客户端看到的 URL 和 NetBird 自己生成的 URL 会不一致。

## 管理员账号和端口

首次 `render` 或完整部署时，脚本会准备 embedded IdP 的管理员账号密码；完整部署/`install` 会在服务启动后调用本地 `/api/setup` 完成初始化：

- 邮箱默认是 `admin@<NETBIRD_DOMAIN>`，可用 `NETBIRD_ADMIN_EMAIL` 覆盖。
- 命令行自动化也可以用 `--admin-email admin@example.com` 临时覆盖。
- `config.yaml` 不保存管理员邮箱或密码，避免重启时覆盖你后续修改过的密码。
- 明文密码只保存到安装目录的 `admin-credentials.txt`，文件权限会尽量设为 `600`。
- 后续重新生成时会复用已有密码，不会悄悄重置管理员密码；管理员后续可以在后台自行修改密码。

完整部署和 `install` 会尝试自动放行 `NETBIRD_PUBLIC_PORT/tcp` 和 `NETBIRD_STUN_PORT/udp`：优先适配 `firewalld`，其次适配已启用的 `ufw`。如果主机没有这两类防火墙管理器，脚本只会提示手动放行；云厂商安全组和 1Panel 自身的防火墙规则仍需要按你的环境确认。

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
