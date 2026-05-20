LANGUAGE="${NETBIRD_LANG:-zh}"

set_language() {
  case "${1:-zh}" in
    en|EN|english|English) LANGUAGE="en" ;;
    zh|ZH|cn|CN|chinese|Chinese|中文) LANGUAGE="zh" ;;
    *) LANGUAGE="zh" ;;
  esac
}

msg() {
  local key="$1"
  case "$LANGUAGE:$key" in
    en:language_title) echo "Language" ;;
    en:language_prompt) echo "Choose interface language" ;;
    en:language_zh) echo "Chinese (default)" ;;
    en:language_en) echo "English" ;;
    en:menu_title) echo "Select operation" ;;
    en:menu_install) echo "Render config and start services" ;;
    en:menu_render) echo "Render or update generated files" ;;
    en:menu_start) echo "Start services" ;;
    en:menu_stop) echo "Stop services" ;;
    en:menu_restart) echo "Restart services" ;;
    en:menu_status) echo "Show status and endpoint checks" ;;
    en:menu_logs) echo "Show recent logs" ;;
    en:menu_1panel_preview) echo "Preview 1Panel OpenResty config" ;;
    en:menu_1panel_apply) echo "Apply 1Panel OpenResty config" ;;
    en:menu_1panel_check) echo "Check and optionally reload OpenResty" ;;
    en:menu_backup) echo "Backup config and data" ;;
    en:menu_uninstall) echo "Uninstall services/config" ;;
    en:menu_self_test) echo "Run local behavior tests" ;;
    en:menu_doctor) echo "Check prerequisites and current configuration" ;;
    en:menu_quit) echo "Exit" ;;
    en:prompt_domain) echo "NetBird public domain" ;;
    en:prompt_install_dir) echo "Install directory" ;;
    en:prompt_dashboard_port) echo "Dashboard localhost port" ;;
    en:prompt_server_port) echo "Combined server localhost port" ;;
    en:prompt_stun_port) echo "Public UDP STUN port" ;;
    en:prompt_1panel_path) echo "1Panel OpenResty root.conf path" ;;
    en:prompt_bind_address) echo "Local bind address" ;;
    en:prompt_public_scheme) echo "Public scheme" ;;
    en:prompt_public_port) echo "Public HTTPS port" ;;
    en:press_enter) echo "Press Enter to continue..." ;;
    en:reload_openresty) echo "Reload OpenResty container %s now?" ;;
    en:remove_config) echo "Remove generated config files in %s? Data is kept unless you confirm the next prompt." ;;
    en:remove_data) echo "Remove NetBird data directory %s/data? This deletes SQLite state." ;;
    en:err_missing_cmd) echo "Missing required command: %s" ;;
    en:err_empty_domain) echo "Domain cannot be empty" ;;
    en:err_dashboard_port) echo "Invalid dashboard port: %s" ;;
    en:err_server_port) echo "Invalid server port: %s" ;;
    en:err_stun_port) echo "Invalid STUN port: %s" ;;
    en:err_same_ports) echo "Dashboard and server ports must differ" ;;
    en:err_unknown_command) echo "Unknown command: %s" ;;
    en:err_compose_required) echo "Docker Compose is required" ;;
    en:dry_run_write) echo "Dry run: would write %s" ;;
    en:backup_file) echo "Backup: %s -> %s" ;;
    en:rendered_files) echo "Rendered files in %s" ;;
    en:status_install_dir) echo "Install dir: %s" ;;
    en:status_domain) echo "Domain: https://%s" ;;
    en:status_dashboard) echo "Dashboard local: http://127.0.0.1:%s" ;;
    en:status_server) echo "Server local: http://127.0.0.1:%s" ;;
    en:status_stun) echo "STUN UDP: %s" ;;
    en:compose_missing) echo "docker-compose.yml not found" ;;
    en:doctor_title) echo "Environment check" ;;
    en:doctor_ok) echo "OK: %s" ;;
    en:doctor_warn) echo "Check: %s" ;;
    en:doctor_config_file) echo "Config file: %s" ;;
    en:doctor_config_missing) echo "Config file not found; using built-in defaults. Copy netbird-server.env.example to netbird-server.env to customize." ;;
    en:doctor_docker) echo "Docker command is available" ;;
    en:doctor_compose) echo "Docker Compose is available" ;;
    en:doctor_port_free) echo "TCP port %s is free on %s" ;;
    en:doctor_port_busy) echo "TCP port %s on %s appears busy" ;;
    en:doctor_udp_note) echo "Ensure firewall/security group allows UDP %s" ;;
    en:doctor_install_dir) echo "Install directory: %s" ;;
    en:doctor_1panel_path) echo "1Panel root.conf path: %s" ;;
    en:doctor_summary) echo "Run render first, then 1panel-preview/1panel-apply, then start or install." ;;
    en:endpoint_ok) echo "%s OK (%s): %s" ;;
    en:endpoint_not_ready) echo "%s not ready (%s): %s" ;;
    en:endpoint_dashboard) echo "Dashboard local" ;;
    en:endpoint_oidc_local) echo "OIDC local" ;;
    en:endpoint_oidc_public) echo "OIDC public" ;;
    en:root_conf_exists) echo "1Panel root.conf exists: %s" ;;
    en:root_conf_missing) echo "1Panel root.conf not found: %s" ;;
    en:wrote_file) echo "Wrote %s" ;;
    en:root_conf_contains) echo "root.conf contains:" ;;
    en:checking_openresty) echo "Checking OpenResty container: %s" ;;
    en:no_openresty) echo "No running OpenResty container detected. You can reload it from 1Panel after applying root.conf." ;;
    en:backup_archive) echo "Backup archive: %s" ;;
    en:uninstall_done) echo "Uninstall step finished" ;;
    en:self_test_start) echo "Running render self-test in %s" ;;
    en:self_test_passed) echo "Self-test passed" ;;

    zh:language_title) echo "语言" ;;
    zh:language_prompt) echo "请选择界面语言" ;;
    zh:language_zh) echo "中文（默认）" ;;
    zh:language_en) echo "English" ;;
    zh:menu_title) echo "请选择操作" ;;
    zh:menu_install) echo "生成配置并启动服务" ;;
    zh:menu_render) echo "生成或更新配置文件" ;;
    zh:menu_start) echo "启动服务" ;;
    zh:menu_stop) echo "停止服务" ;;
    zh:menu_restart) echo "重启服务" ;;
    zh:menu_status) echo "查看状态和端点检查" ;;
    zh:menu_logs) echo "查看最近日志" ;;
    zh:menu_1panel_preview) echo "预览 1Panel OpenResty 配置" ;;
    zh:menu_1panel_apply) echo "写入 1Panel OpenResty 配置" ;;
    zh:menu_1panel_check) echo "检查并可选重载 OpenResty" ;;
    zh:menu_backup) echo "备份配置和数据" ;;
    zh:menu_uninstall) echo "卸载服务/配置" ;;
    zh:menu_self_test) echo "运行本机行为测试" ;;
    zh:menu_doctor) echo "检查依赖和当前配置" ;;
    zh:menu_quit) echo "退出" ;;
    zh:prompt_domain) echo "NetBird 公网域名" ;;
    zh:prompt_install_dir) echo "安装目录" ;;
    zh:prompt_dashboard_port) echo "Dashboard 本地端口" ;;
    zh:prompt_server_port) echo "Combined server 本地端口" ;;
    zh:prompt_stun_port) echo "公网 UDP STUN 端口" ;;
    zh:prompt_1panel_path) echo "1Panel OpenResty root.conf 路径" ;;
    zh:prompt_bind_address) echo "本地绑定地址" ;;
    zh:prompt_public_scheme) echo "公网协议" ;;
    zh:prompt_public_port) echo "公网 HTTPS 端口" ;;
    zh:press_enter) echo "按 Enter 继续..." ;;
    zh:reload_openresty) echo "现在重载 OpenResty 容器 %s 吗？" ;;
    zh:remove_config) echo "删除 %s 中生成的配置文件吗？数据会保留，除非你在下一步确认删除。" ;;
    zh:remove_data) echo "删除 NetBird 数据目录 %s/data 吗？这会删除 SQLite 状态。" ;;
    zh:err_missing_cmd) echo "缺少必要命令：%s" ;;
    zh:err_empty_domain) echo "域名不能为空" ;;
    zh:err_dashboard_port) echo "Dashboard 端口无效：%s" ;;
    zh:err_server_port) echo "Server 端口无效：%s" ;;
    zh:err_stun_port) echo "STUN 端口无效：%s" ;;
    zh:err_same_ports) echo "Dashboard 和 Server 端口不能相同" ;;
    zh:err_unknown_command) echo "未知命令：%s" ;;
    zh:err_compose_required) echo "需要 Docker Compose" ;;
    zh:dry_run_write) echo "演练模式：将写入 %s" ;;
    zh:backup_file) echo "备份：%s -> %s" ;;
    zh:rendered_files) echo "已生成文件到 %s" ;;
    zh:status_install_dir) echo "安装目录：%s" ;;
    zh:status_domain) echo "域名：https://%s" ;;
    zh:status_dashboard) echo "Dashboard 本地地址：http://127.0.0.1:%s" ;;
    zh:status_server) echo "Server 本地地址：http://127.0.0.1:%s" ;;
    zh:status_stun) echo "STUN UDP：%s" ;;
    zh:compose_missing) echo "未找到 docker-compose.yml" ;;
    zh:doctor_title) echo "环境检查" ;;
    zh:doctor_ok) echo "正常：%s" ;;
    zh:doctor_warn) echo "需确认：%s" ;;
    zh:doctor_config_file) echo "配置文件：%s" ;;
    zh:doctor_config_missing) echo "未找到配置文件，正在使用内置默认值。可复制 netbird-server.env.example 为 netbird-server.env 后修改。" ;;
    zh:doctor_docker) echo "Docker 命令可用" ;;
    zh:doctor_compose) echo "Docker Compose 可用" ;;
    zh:doctor_port_free) echo "%s:%s TCP 端口空闲" ;;
    zh:doctor_port_busy) echo "%s:%s TCP 端口可能已占用" ;;
    zh:doctor_udp_note) echo "请确保防火墙/安全组放行 UDP %s" ;;
    zh:doctor_install_dir) echo "安装目录：%s" ;;
    zh:doctor_1panel_path) echo "1Panel root.conf 路径：%s" ;;
    zh:doctor_summary) echo "建议顺序：先 render，再 1panel-preview/1panel-apply，然后 start 或 install。" ;;
    zh:endpoint_ok) echo "%s 正常（%s）：%s" ;;
    zh:endpoint_not_ready) echo "%s 未就绪（%s）：%s" ;;
    zh:endpoint_dashboard) echo "Dashboard 本地端点" ;;
    zh:endpoint_oidc_local) echo "OIDC 本地端点" ;;
    zh:endpoint_oidc_public) echo "OIDC 公网端点" ;;
    zh:root_conf_exists) echo "1Panel root.conf 存在：%s" ;;
    zh:root_conf_missing) echo "未找到 1Panel root.conf：%s" ;;
    zh:wrote_file) echo "已写入 %s" ;;
    zh:root_conf_contains) echo "root.conf 包含：" ;;
    zh:checking_openresty) echo "正在检查 OpenResty 容器：%s" ;;
    zh:no_openresty) echo "未检测到运行中的 OpenResty 容器。写入 root.conf 后可在 1Panel 中重载。" ;;
    zh:backup_archive) echo "备份包：%s" ;;
    zh:uninstall_done) echo "卸载步骤已完成" ;;
    zh:self_test_start) echo "正在 %s 运行渲染自测" ;;
    zh:self_test_passed) echo "自测通过" ;;
    *) echo "$key" ;;
  esac
}

tf() {
  local key="$1"; shift
  local template
  template="$(msg "$key")"
  printf "%s" "$(printf "$template" "$@")"
}

select_language() {
  [[ "$NONINTERACTIVE" == "true" ]] && return 0
  [[ -n "${NETBIRD_LANG:-}" ]] && return 0
  has_tui || return 0

  local choice
  choice="$(tui_menu "$(msg language_prompt)" \
    zh "$(msg language_zh)" \
    en "$(msg language_en)")" || choice="zh"
  set_language "${choice:-zh}"
}

set_language "$LANGUAGE"
