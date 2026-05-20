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
    en:menu_wizard) echo "Guided setup: configure, generate, apply, start" ;;
    en:menu_advanced) echo "Advanced operations" ;;
    en:menu_back) echo "Back" ;;
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
    en:prompt_public_scheme) echo "Public URL scheme" ;;
    en:prompt_public_port) echo "Public port" ;;
    en:prompt_admin_email) echo "Admin email" ;;
    en:err_public_port) echo "Invalid public port: %s" ;;
    en:err_public_scheme) echo "Invalid public scheme: %s" ;;
    en:err_admin_email) echo "Invalid admin email: %s" ;;
    en:dialog_required) echo "The setup wizard requires 'dialog' for form screens. Install it and rerun: sudo apt-get update && sudo apt-get install -y dialog" ;;
    en:wizard_title) echo "NetBird server setup" ;;
    en:wizard_step) echo "Step %s/%s" ;;
    en:wizard_essentials_title) echo "Step 2/4: Essentials" ;;
    en:wizard_essentials_msg) echo "Most deployments only need these three fields. The default is http; the 1Panel upstream to the containers is always plain HTTP. If your 1Panel site already forces HTTPS, set the public scheme to https so NetBird URLs match the browser/client URL." ;;
    en:wizard_advanced_question_title) echo "Step 3/4: Advanced (optional)" ;;
    en:wizard_advanced_question) echo "Adjust advanced settings (ports, bind address, 1Panel path, profile name)? Most deployments can skip this." ;;
    en:wizard_advanced_title) echo "Step 3/4: Advanced settings" ;;
    en:wizard_advanced_msg) echo "Leave 1Panel root.conf empty to auto-derive from the domain. Profile name defaults to the sanitized domain." ;;
    en:wizard_advanced_profile_label) echo "Profile name" ;;
    en:wizard_summary_title) echo "Step 4/4: Review and execute" ;;
    en:wizard_summary_msg) echo "Choose how to proceed. The recommended option deploys everything in one go." ;;
    en:wizard_summary_full) echo "Full deploy: save profile, render files, write 1Panel root.conf, start containers" ;;
    en:wizard_summary_render) echo "Render only: save profile and generate files (do not write 1Panel, do not start)" ;;
    en:wizard_summary_save) echo "Save profile only" ;;
    en:wizard_summary_back) echo "Back to edit essentials" ;;
    en:wizard_summary_cancel) echo "Cancel without changes" ;;
    en:wizard_validation_failed) echo "Some values look wrong. Please re-check:\n\n%s" ;;
    en:wizard_executing) echo "Executing selected actions..." ;;
    en:wizard_http_warning) echo "HTTP mode generates http:// public URLs and X-Forwarded-Proto=http. If 1Panel later forces HTTPS, switch this field to https and regenerate." ;;
    en:wizard_ports_warning) echo "Port 80/443 note: %s" ;;
    en:wizard_done) echo "Wizard finished." ;;
    en:wizard_next_hint) echo "Next steps: run 'status' to verify endpoints, 'doctor' to recheck environment, 'backup' before any major change." ;;
    en:admin_credentials_created) echo "Admin account and password saved to %s. Login email: %s." ;;
    en:admin_credentials_reused) echo "Existing admin password found at %s; keeping the password unchanged." ;;
    en:admin_setup_done) echo "Admin account %s is ready. Account details are in %s." ;;
    en:admin_setup_skipped) echo "NetBird is already initialized; keeping existing admin/user state." ;;
    en:admin_setup_not_ready) echo "Server did not expose setup status in time: %s" ;;
    en:admin_setup_http_failed) echo "Admin setup failed with HTTP %s at %s" ;;
    en:admin_setup_failed) echo "Admin setup skipped because credentials could not be read from %s" ;;
    en:review_title) echo "Step 1.5/4: Reuse profile" ;;
    en:review_msg) echo "%s\n\nReuse this profile? Pick 'Full deploy' to apply as-is, or edit/delete the profile." ;;
    en:review_deploy) echo "Full deploy (save + render + 1Panel + start)" ;;
    en:review_edit) echo "Edit settings" ;;
    en:review_delete) echo "Delete this profile" ;;
    en:review_cancel) echo "Cancel" ;;
    en:review_delete_confirm) echo "Permanently delete profile '%s'? Service files in INSTALL_DIR are not affected." ;;
    en:profile_deleted) echo "Deleted profile %s" ;;
    en:summary_field_profile) echo "Profile" ;;
    en:summary_field_domain) echo "Domain" ;;
    en:summary_field_public) echo "Public URL" ;;
    en:summary_field_admin) echo "Admin email" ;;
    en:summary_field_install) echo "Install dir" ;;
    en:summary_field_dashboard) echo "Dashboard local" ;;
    en:summary_field_server) echo "Server local" ;;
    en:summary_field_stun) echo "STUN UDP" ;;
    en:summary_field_1panel) echo "1Panel root.conf" ;;
    en:summary_field_ports) echo "Port 80/443" ;;
    en:summary_field_scheme_warning) echo "Note" ;;
    en:advanced_title) echo "Advanced operations" ;;
    en:save_env_done) echo "Saved %s" ;;
    en:profile_title) echo "Deployment profile" ;;
    en:profile_prompt) echo "Use an existing profile or create a new one" ;;
    en:profile_new) echo "Create new profile" ;;
    en:profile_name_prompt) echo "Profile name" ;;
    en:profile_loaded) echo "Loaded profile %s" ;;
    en:profile_saved) echo "Saved profile %s" ;;
    en:press_enter) echo "Press Enter to continue..." ;;
    en:reload_openresty) echo "Reload OpenResty container %s now?" ;;
    en:remove_config) echo "Remove generated config files in %s, including admin credentials and generated backups? Data is kept unless you confirm the next prompt." ;;
    en:remove_data) echo "Remove NetBird data directory %s/data? This deletes SQLite state." ;;
    en:remove_1panel_conf) echo "Remove 1Panel OpenResty root.conf %s? A backup is created first. Default is No." ;;
    en:err_missing_cmd) echo "Missing required command: %s" ;;
    en:err_empty_domain) echo "Domain cannot be empty" ;;
    en:err_dashboard_port) echo "Invalid dashboard port: %s" ;;
    en:err_server_port) echo "Invalid server port: %s" ;;
    en:err_stun_port) echo "Invalid STUN port: %s" ;;
    en:err_same_ports) echo "Dashboard and server ports must differ" ;;
    en:err_unknown_command) echo "Unknown command: %s" ;;
    en:err_compose_required) echo "Docker Compose is required" ;;
    en:dry_run_write) echo "Dry run: would write %s" ;;
    en:dry_run_remove) echo "Dry run: would remove %s" ;;
    en:dry_run_compose_down) echo "Dry run: would run docker compose down in %s" ;;
    en:backup_file) echo "Backup: %s -> %s" ;;
    en:rendered_files) echo "Rendered files in %s" ;;
    en:status_install_dir) echo "Install dir: %s" ;;
    en:status_domain) echo "Domain: %s://%s" ;;
    en:status_dashboard) echo "Dashboard local: http://127.0.0.1:%s" ;;
    en:status_server) echo "Server local: http://127.0.0.1:%s" ;;
    en:status_stun) echo "STUN UDP: %s" ;;
    en:compose_missing) echo "docker-compose.yml not found" ;;
    en:doctor_title) echo "Environment check" ;;
    en:doctor_ok) echo "OK: %s" ;;
    en:doctor_warn) echo "Check: %s" ;;
    en:doctor_config_file) echo "Config file: %s" ;;
    en:doctor_config_missing) echo "Config file/profile not found; using built-in defaults. Run the setup wizard to save a profile." ;;
    en:doctor_docker) echo "Docker command is available" ;;
    en:doctor_compose) echo "Docker Compose is available" ;;
    en:doctor_port_free) echo "TCP port %s is free on %s" ;;
    en:doctor_port_busy) echo "TCP port %s on %s appears busy" ;;
    en:doctor_udp_note) echo "Ensure firewall/security group allows UDP %s" ;;
    en:doctor_firewall_manual) echo "Firewall note: allow TCP %s and UDP %s on the host/security group if needed." ;;
    en:doctor_install_dir) echo "Install directory: %s" ;;
    en:doctor_1panel_path) echo "1Panel root.conf path: %s" ;;
    en:doctor_summary) echo "Run render first, then 1panel-preview/1panel-apply, then start or install." ;;
    en:doctor_public_port_free) echo "Public TCP port %s appears free" ;;
    en:doctor_public_port_busy) echo "Public TCP port %s appears busy" ;;
    en:doctor_http_mode) echo "HTTP public URLs selected. If your 1Panel site forces HTTPS, set NETBIRD_PUBLIC_SCHEME=https and rerender." ;;
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
    en:firewall_opened) echo "Opened firewall ports via %s: TCP %s, UDP %s" ;;
    en:firewall_manual) echo "No supported firewall manager detected. If access fails, allow TCP %s and UDP %s manually." ;;
    en:firewall_failed) echo "Failed to update firewall via %s. Please allow TCP %s and UDP %s manually." ;;
    en:firewall_skipped) echo "Dry run: would allow TCP %s and UDP %s" ;;
    en:backup_archive) echo "Backup archive: %s" ;;
    en:uninstall_done) echo "Uninstall step finished" ;;
    en:self_test_start) echo "Running render self-test in %s" ;;
    en:self_test_passed) echo "Self-test passed" ;;

    zh:language_title) echo "语言" ;;
    zh:language_prompt) echo "请选择界面语言" ;;
    zh:language_zh) echo "中文（默认）" ;;
    zh:language_en) echo "English" ;;
    zh:menu_title) echo "请选择操作" ;;
    zh:menu_wizard) echo "部署向导：配置、生成、写入、启动" ;;
    zh:menu_advanced) echo "高级操作" ;;
    zh:menu_back) echo "返回" ;;
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
    zh:prompt_public_scheme) echo "对外访问协议" ;;
    zh:prompt_public_port) echo "公网端口" ;;
    zh:prompt_admin_email) echo "管理员邮箱" ;;
    zh:err_public_port) echo "公网端口无效：%s" ;;
    zh:err_public_scheme) echo "公网协议无效：%s" ;;
    zh:err_admin_email) echo "管理员邮箱无效：%s" ;;
    zh:dialog_required) echo "部署向导需要安装 dialog 才能显示表单。请先执行：sudo apt-get update && sudo apt-get install -y dialog，然后重新运行脚本。" ;;
    zh:wizard_title) echo "NetBird 服务端部署向导" ;;
    zh:wizard_step) echo "第 %s/%s 步" ;;
    zh:wizard_essentials_title) echo "第 2/4 步：基本配置" ;;
    zh:wizard_essentials_msg) echo "大多数部署只需要这三项。默认使用 http；1Panel 转发到容器内部始终是普通 HTTP。若 1Panel 站点已经启用并强制 HTTPS，请把对外访问协议改为 https，让 NetBird 生成的地址与浏览器/客户端看到的一致。" ;;
    zh:wizard_advanced_question_title) echo "第 3/4 步：高级配置（可选）" ;;
    zh:wizard_advanced_question) echo "需要调整高级设置吗？包括端口、绑定地址、1Panel 路径、Profile 名称。大多数部署可以跳过。" ;;
    zh:wizard_advanced_title) echo "第 3/4 步：高级设置" ;;
    zh:wizard_advanced_msg) echo "1Panel root.conf 留空则按域名自动派生。Profile 名称默认从域名 sanitize 派生。" ;;
    zh:wizard_advanced_profile_label) echo "Profile 名称" ;;
    zh:wizard_summary_title) echo "第 4/4 步：确认并执行" ;;
    zh:wizard_summary_msg) echo "请选择后续动作。推荐项会一次完成部署。" ;;
    zh:wizard_summary_full) echo "完整部署：保存 profile + 生成文件 + 写入 1Panel + 启动容器" ;;
    zh:wizard_summary_render) echo "仅生成：保存 profile + 渲染文件（不写 1Panel、不启动）" ;;
    zh:wizard_summary_save) echo "仅保存 profile" ;;
    zh:wizard_summary_back) echo "返回上一步重新编辑" ;;
    zh:wizard_summary_cancel) echo "取消，不做任何更改" ;;
    zh:wizard_validation_failed) echo "检测到以下问题，请回去修改：\n\n%s" ;;
    zh:wizard_executing) echo "正在执行所选操作..." ;;
    zh:wizard_http_warning) echo "HTTP 模式会生成 http:// 对外地址，并写入 X-Forwarded-Proto=http。若之后在 1Panel 站点强制 HTTPS，请把这里改成 https 后重新生成。" ;;
    zh:wizard_ports_warning) echo "80/443 端口提示：%s" ;;
    zh:wizard_done) echo "向导已完成。" ;;
    zh:wizard_next_hint) echo "下一步建议：运行 status 检查端点，doctor 复检环境，重要变更前先 backup。" ;;
    zh:admin_credentials_created) echo "管理员账号密码已保存到 %s。登录邮箱为 %s。" ;;
    zh:admin_credentials_reused) echo "检测到已有管理员密码：%s，本次保持密码不变。" ;;
    zh:admin_setup_done) echo "管理员账号 %s 已就绪。账号密码保存在 %s。" ;;
    zh:admin_setup_skipped) echo "NetBird 已经初始化，本次保留现有管理员/用户状态。" ;;
    zh:admin_setup_not_ready) echo "服务未在限定时间内暴露初始化状态：%s" ;;
    zh:admin_setup_http_failed) echo "管理员账号初始化失败，HTTP %s：%s" ;;
    zh:admin_setup_failed) echo "无法从 %s 读取账号密码，已跳过管理员账号初始化。" ;;
    zh:review_title) echo "第 1.5/4 步：复用 profile" ;;
    zh:review_msg) echo "%s\n\n复用这个 profile 吗？选择「完整部署」按当前值直接部署，也可以编辑/删除。" ;;
    zh:review_deploy) echo "完整部署（保存 + 渲染 + 1Panel + 启动）" ;;
    zh:review_edit) echo "编辑设置" ;;
    zh:review_delete) echo "删除这个 profile" ;;
    zh:review_cancel) echo "取消" ;;
    zh:review_delete_confirm) echo "确定要永久删除 profile「%s」吗？INSTALL_DIR 下的服务文件不会被动到。" ;;
    zh:profile_deleted) echo "已删除 profile：%s" ;;
    zh:summary_field_profile) echo "Profile" ;;
    zh:summary_field_domain) echo "域名" ;;
    zh:summary_field_public) echo "对外地址" ;;
    zh:summary_field_admin) echo "管理员邮箱" ;;
    zh:summary_field_install) echo "安装目录" ;;
    zh:summary_field_dashboard) echo "Dashboard 本地" ;;
    zh:summary_field_server) echo "Server 本地" ;;
    zh:summary_field_stun) echo "STUN UDP" ;;
    zh:summary_field_1panel) echo "1Panel root.conf" ;;
    zh:summary_field_ports) echo "80/443 端口" ;;
    zh:summary_field_scheme_warning) echo "提示" ;;
    zh:advanced_title) echo "高级操作" ;;
    zh:save_env_done) echo "已保存 %s" ;;
    zh:profile_title) echo "部署 Profile" ;;
    zh:profile_prompt) echo "请选择复用已有 profile，或新建 profile" ;;
    zh:profile_new) echo "新建 profile" ;;
    zh:profile_name_prompt) echo "Profile 名称" ;;
    zh:profile_loaded) echo "已加载 profile：%s" ;;
    zh:profile_saved) echo "已保存 profile：%s" ;;
    zh:press_enter) echo "按 Enter 继续..." ;;
    zh:reload_openresty) echo "现在重载 OpenResty 容器 %s 吗？" ;;
    zh:remove_config) echo "删除 %s 中生成的配置文件吗？包括管理员凭据和生成的备份；数据会保留，除非你在下一步确认删除。" ;;
    zh:remove_data) echo "删除 NetBird 数据目录 %s/data 吗？这会删除 SQLite 状态。" ;;
    zh:remove_1panel_conf) echo "删除 1Panel OpenResty root.conf %s 吗？会先创建备份。默认不删除。" ;;
    zh:err_missing_cmd) echo "缺少必要命令：%s" ;;
    zh:err_empty_domain) echo "域名不能为空" ;;
    zh:err_dashboard_port) echo "Dashboard 端口无效：%s" ;;
    zh:err_server_port) echo "Server 端口无效：%s" ;;
    zh:err_stun_port) echo "STUN 端口无效：%s" ;;
    zh:err_same_ports) echo "Dashboard 和 Server 端口不能相同" ;;
    zh:err_unknown_command) echo "未知命令：%s" ;;
    zh:err_compose_required) echo "需要 Docker Compose" ;;
    zh:dry_run_write) echo "演练模式：将写入 %s" ;;
    zh:dry_run_remove) echo "演练模式：将删除 %s" ;;
    zh:dry_run_compose_down) echo "演练模式：将在 %s 执行 docker compose down" ;;
    zh:backup_file) echo "备份：%s -> %s" ;;
    zh:rendered_files) echo "已生成文件到 %s" ;;
    zh:status_install_dir) echo "安装目录：%s" ;;
    zh:status_domain) echo "域名：%s://%s" ;;
    zh:status_dashboard) echo "Dashboard 本地地址：http://127.0.0.1:%s" ;;
    zh:status_server) echo "Server 本地地址：http://127.0.0.1:%s" ;;
    zh:status_stun) echo "STUN UDP：%s" ;;
    zh:compose_missing) echo "未找到 docker-compose.yml" ;;
    zh:doctor_title) echo "环境检查" ;;
    zh:doctor_ok) echo "正常：%s" ;;
    zh:doctor_warn) echo "需确认：%s" ;;
    zh:doctor_config_file) echo "配置文件：%s" ;;
    zh:doctor_config_missing) echo "未找到配置文件/profile，正在使用内置默认值。运行部署向导即可保存 profile。" ;;
    zh:doctor_docker) echo "Docker 命令可用" ;;
    zh:doctor_compose) echo "Docker Compose 可用" ;;
    zh:doctor_port_free) echo "%s:%s TCP 端口空闲" ;;
    zh:doctor_port_busy) echo "%s:%s TCP 端口可能已占用" ;;
    zh:doctor_udp_note) echo "请确保防火墙/安全组放行 UDP %s" ;;
    zh:doctor_firewall_manual) echo "防火墙提示：如访问失败，请在主机/安全组放行 TCP %s 和 UDP %s。" ;;
    zh:doctor_install_dir) echo "安装目录：%s" ;;
    zh:doctor_1panel_path) echo "1Panel root.conf 路径：%s" ;;
    zh:doctor_summary) echo "建议顺序：先 render，再 1panel-preview/1panel-apply，然后 start 或 install。" ;;
    zh:doctor_public_port_free) echo "公网 TCP %s 端口看起来空闲" ;;
    zh:doctor_public_port_busy) echo "公网 TCP %s 端口可能已占用" ;;
    zh:doctor_http_mode) echo "当前生成 HTTP 对外地址；如果 1Panel 站点强制 HTTPS，请设置 NETBIRD_PUBLIC_SCHEME=https 后重新生成。" ;;
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
    zh:firewall_opened) echo "已通过 %s 放行端口：TCP %s，UDP %s" ;;
    zh:firewall_manual) echo "未检测到支持的防火墙管理器。如访问失败，请手动放行 TCP %s 和 UDP %s。" ;;
    zh:firewall_failed) echo "通过 %s 更新防火墙失败。请手动放行 TCP %s 和 UDP %s。" ;;
    zh:firewall_skipped) echo "演练模式：将放行 TCP %s 和 UDP %s" ;;
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
