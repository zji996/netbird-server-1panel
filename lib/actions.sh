render_files() {
  validate_settings
  require_cmd openssl
  info "$(msg progress_render_files)"
  local relay_secret encryption_key admin_password
  relay_secret="$(existing_secret_or_new)"
  encryption_key="$(existing_encryption_key_or_new)"
  admin_password="$(existing_admin_password_or_new)"

  prepare_config_directory
  mkdir -p "$INSTALL_DIR/data"
  render_compose > "$TMP_DIR/docker-compose.yml"
  render_config_yaml "$relay_secret" "$encryption_key" > "$TMP_DIR/config.yaml"
  render_dashboard_env > "$TMP_DIR/dashboard.env"

  write_file "$INSTALL_DIR/docker-compose.yml" "$TMP_DIR/docker-compose.yml"
  write_file "$(config_file)" "$TMP_DIR/config.yaml"
  write_file "$INSTALL_DIR/dashboard.env" "$TMP_DIR/dashboard.env"
  write_admin_credentials "$admin_password"
  info "$(tf rendered_files "$INSTALL_DIR")"
}

prepare_config_directory() {
  local dir
  dir="$(config_dir)"
  if [[ -e "$dir" && ! -d "$dir" ]]; then
    backup_file_if_exists "$dir"
    rm -f "$dir"
  fi
  mkdir -p "$dir"
}

require_generated_file() {
  local file="$1"
  if [[ ! -e "$file" ]]; then
    die "$(tf err_generated_file_missing "$file")"
  fi
  if [[ ! -f "$file" ]]; then
    die "$(tf err_generated_file_not_file "$file")"
  fi
}

require_generated_dir() {
  local dir="$1"
  if [[ ! -e "$dir" ]]; then
    die "$(tf err_generated_dir_missing "$dir")"
  fi
  if [[ ! -d "$dir" ]]; then
    die "$(tf err_generated_dir_not_dir "$dir")"
  fi
}

ensure_generated_layout() {
  require_generated_file "$INSTALL_DIR/docker-compose.yml"
  require_generated_dir "$(config_dir)"
  require_generated_file "$(config_file)"
  require_generated_file "$INSTALL_DIR/dashboard.env"
}

start_services() {
  require_cmd docker
  ensure_generated_layout
  info "$(msg progress_start_services)"
  run_compose up -d
}

stop_services() {
  info "$(msg progress_stop_services)"
  run_compose down
}

restart_services() {
  info "$(msg progress_restart_services)"
  ensure_generated_layout
  run_compose up -d --force-recreate
}

endpoint_check() {
  local name="$1"
  local url="$2"
  local code
  code="$(curl -k -s -o /dev/null -w '%{http_code}' --max-time 5 "$url" 2>/dev/null || true)"
  if [[ "$code" =~ ^2|3 ]]; then
    info "$(tf endpoint_ok "$name" "$code" "$url")"
  else
    warn "$(tf endpoint_not_ready "$name" "$code" "$url")"
  fi
}

port_is_free() {
  local bind="$1"
  local port="$2"
  if command -v ss >/dev/null 2>&1; then
    ! ss -H -ltn "sport = :$port" 2>/dev/null | rg -q "($bind|0\\.0\\.0\\.0|\\[::\\]|\\*)"
  else
    ! timeout 1 bash -c "</dev/tcp/${bind}/${port}" >/dev/null 2>&1
  fi
}

doctor_check() {
  info "$(msg doctor_title)"

  local config_file="${NETBIRD_CONFIG_FILE:-}"
  if [[ -z "$config_file" && -n "${NETBIRD_PROFILE:-}" ]]; then
    config_file="$(profile_file "$NETBIRD_PROFILE")"
  fi
  if [[ -z "$config_file" ]]; then
    config_file="$SCRIPT_DIR/netbird-server.env"
  fi
  if [[ -f "$config_file" ]]; then
    info "$(tf doctor_config_file "$config_file")"
  else
    info "$(msg doctor_config_missing)"
  fi

  if command -v docker >/dev/null 2>&1; then
    info "$(tf doctor_ok "$(msg doctor_docker)")"
  else
    warn "$(tf doctor_warn "docker")"
  fi

  if compose_cmd >/dev/null 2>&1; then
    info "$(tf doctor_ok "$(msg doctor_compose)")"
  else
    warn "$(tf doctor_warn "$(msg err_compose_required)")"
  fi

  if port_is_free "$BIND_ADDRESS" "$DASHBOARD_PORT"; then
    info "$(tf doctor_ok "$(tf doctor_port_free "$BIND_ADDRESS" "$DASHBOARD_PORT")")"
  else
    warn "$(tf doctor_warn "$(tf doctor_port_busy "$BIND_ADDRESS" "$DASHBOARD_PORT")")"
  fi

  if port_is_free "$BIND_ADDRESS" "$SERVER_PORT"; then
    info "$(tf doctor_ok "$(tf doctor_port_free "$BIND_ADDRESS" "$SERVER_PORT")")"
  else
    warn "$(tf doctor_warn "$(tf doctor_port_busy "$BIND_ADDRESS" "$SERVER_PORT")")"
  fi

  if [[ "$PUBLIC_SCHEME" == "https" ]]; then
    if port_is_free "0.0.0.0" 80; then
      info "$(tf doctor_ok "$(tf doctor_public_port_free 80)")"
    else
      info "$(tf doctor_warn "$(tf doctor_public_port_busy 80)")"
    fi
    if port_is_free "0.0.0.0" "$PUBLIC_PORT"; then
      info "$(tf doctor_ok "$(tf doctor_public_port_free "$PUBLIC_PORT")")"
    else
      info "$(tf doctor_warn "$(tf doctor_public_port_busy "$PUBLIC_PORT")")"
    fi
  else
    info "$(msg doctor_http_mode)"
    if port_is_free "0.0.0.0" "$PUBLIC_PORT"; then
      info "$(tf doctor_ok "$(tf doctor_public_port_free "$PUBLIC_PORT")")"
    else
      info "$(tf doctor_warn "$(tf doctor_public_port_busy "$PUBLIC_PORT")")"
    fi
  fi

  info "$(tf doctor_warn "$(tf doctor_udp_note "$STUN_PORT")")"
  info "$(tf doctor_firewall_manual "$(firewall_tcp_ports_label)" "$STUN_PORT")"
  info "$(tf doctor_install_dir "$INSTALL_DIR")"
  info "$(tf doctor_1panel_path "$ONEPANEL_ROOT_CONF")"
  info "$(msg doctor_summary)"
}

show_status() {
  info "$(tf status_install_dir "$INSTALL_DIR")"
  info "$(tf status_public_url "$(public_origin)")"
  info "$(tf status_dashboard "$DASHBOARD_PORT")"
  info "$(tf status_server "$SERVER_PORT")"
  info "$(tf status_stun "$STUN_PORT")"
  if [[ -f "$INSTALL_DIR/docker-compose.yml" ]]; then
    run_compose ps || true
  else
    warn "$(msg compose_missing)"
  fi
  endpoint_check "$(msg endpoint_dashboard)" "http://127.0.0.1:${DASHBOARD_PORT}/"
  endpoint_check "$(msg endpoint_oidc_local)" "http://127.0.0.1:${SERVER_PORT}/oauth2/.well-known/openid-configuration"
  endpoint_check "$(msg endpoint_oidc_public)" "$(public_url /oauth2/.well-known/openid-configuration)"
  if [[ -f "$ONEPANEL_ROOT_CONF" ]]; then
    info "$(tf root_conf_exists "$ONEPANEL_ROOT_CONF")"
  else
    warn "$(tf root_conf_missing "$ONEPANEL_ROOT_CONF")"
  fi
}

show_logs() {
  run_compose logs --tail=120 dashboard netbird-server
}

apply_1panel_conf() {
  validate_settings
  info "$(msg progress_apply_1panel)"
  render_openresty_root_conf > "$TMP_DIR/root.conf"
  if [[ "$DRY_RUN" == "true" ]]; then
    info "$(tf dry_run_write "$ONEPANEL_ROOT_CONF")"
    cat "$TMP_DIR/root.conf"
    return 0
  fi
  maybe_sudo mkdir -p "$(dirname "$ONEPANEL_ROOT_CONF")"
  if [[ -f "$ONEPANEL_ROOT_CONF" ]]; then
    local backup="${ONEPANEL_ROOT_CONF}.bak.$(date +%Y%m%d%H%M%S)"
    info "$(tf backup_file "$ONEPANEL_ROOT_CONF" "$backup")"
    maybe_sudo cp -a "$ONEPANEL_ROOT_CONF" "$backup"
  fi
  maybe_sudo cp "$TMP_DIR/root.conf" "$ONEPANEL_ROOT_CONF"
  info "$(tf wrote_file "$ONEPANEL_ROOT_CONF")"
  [[ "${NETBIRD_SKIP_OPENRESTY_RELOAD:-false}" == "true" ]] && return 0
  reload_openresty_if_possible || true
}

openresty_container() {
  command -v docker >/dev/null 2>&1 || return 1
  docker ps --format '{{.Names}}' 2>/dev/null | rg 'openresty|1panel.*openresty' | head -n 1 || true
}

public_port_is_listening() {
  if command -v ss >/dev/null 2>&1; then
    ss -H -ltn "sport = :$PUBLIC_PORT" 2>/dev/null | rg -q .
  else
    timeout 1 bash -c "</dev/tcp/127.0.0.1/${PUBLIC_PORT}" >/dev/null 2>&1
  fi
}

check_public_port_listener() {
  if public_port_is_listening; then
    info "$(tf public_port_listening "$PUBLIC_PORT")"
  else
    warn "$(tf public_port_not_listening "$PUBLIC_PORT")"
    warn "$(tf public_port_site_note "$PUBLIC_PORT")"
  fi
}

reload_openresty_if_possible() {
  local container
  container="$(openresty_container)"
  if [[ -z "$container" ]]; then
    warn "$(msg no_openresty)"
    check_public_port_listener
    return 1
  fi

  info "$(tf checking_openresty "$container")"
  if ! docker exec "$container" nginx -t; then
    warn "$(tf openresty_test_failed "$container")"
    return 1
  fi
  docker exec "$container" nginx -s reload
  info "$(tf openresty_reloaded "$container")"
  check_public_port_listener
}

check_1panel() {
  local container
  if [[ -f "$ONEPANEL_ROOT_CONF" ]]; then
    info "$(msg root_conf_contains)"
    rg -n "127\\.0\\.0\\.1:${SERVER_PORT}|127\\.0\\.0\\.1:${DASHBOARD_PORT}|grpc_pass|proxy_pass" "$ONEPANEL_ROOT_CONF" || true
  else
    warn "$(tf root_conf_missing "$ONEPANEL_ROOT_CONF")"
  fi

  container="$(openresty_container)"
  if [[ -n "$container" ]]; then
    info "$(tf checking_openresty "$container")"
    docker exec "$container" nginx -t
    if tui_yesno "$(tf reload_openresty "$container")"; then
      docker exec "$container" nginx -s reload
      info "$(tf openresty_reloaded "$container")"
    fi
    check_public_port_listener
  else
    warn "$(msg no_openresty)"
    check_public_port_listener
  fi
}

backup_installation() {
  local backup_dir archive
  backup_dir="$(dirname "$INSTALL_DIR")"
  archive="${backup_dir}/netbird-backup-$(date +%Y%m%d%H%M%S).tar.gz"
  tar -czf "$archive" -C "$INSTALL_DIR" docker-compose.yml config dashboard.env data 2>/dev/null || tar -czf "$archive" -C "$INSTALL_DIR" .
  info "$(tf backup_archive "$archive")"
}

join_csv() {
  local result="" item
  for item in "$@"; do
    if [[ -n "$result" ]]; then
      result+=", "
    fi
    result+="$item"
  done
  printf '%s' "$result"
}

firewall_tcp_ports() {
  printf '%s\n' "$PUBLIC_PORT"
  if [[ "$PUBLIC_SCHEME" == "https" && "$PUBLIC_PORT" != "80" ]]; then
    printf '80\n'
  fi
}

firewall_tcp_ports_label() {
  local ports=()
  mapfile -t ports < <(firewall_tcp_ports)
  join_csv "${ports[@]}"
}

open_firewall_ports() {
  local tcp_ports=()
  local udp_port="$STUN_PORT"
  local tcp_label
  mapfile -t tcp_ports < <(firewall_tcp_ports)
  tcp_label="$(join_csv "${tcp_ports[@]}")"
  info "$(tf progress_firewall "$tcp_label" "$udp_port")"
  if [[ "$DRY_RUN" == "true" ]]; then
    info "$(tf firewall_skipped "$tcp_label" "$udp_port")"
    return 0
  fi

  if command -v firewall-cmd >/dev/null 2>&1 && firewall-cmd --state >/dev/null 2>&1; then
    local ok="true" tcp_port
    for tcp_port in "${tcp_ports[@]}"; do
      maybe_sudo firewall-cmd --permanent --add-port="${tcp_port}/tcp" || ok="false"
    done
    maybe_sudo firewall-cmd --permanent --add-port="${udp_port}/udp" || ok="false"
    maybe_sudo firewall-cmd --reload || ok="false"
    if [[ "$ok" == "true" ]]; then
      info "$(tf firewall_opened firewalld "$tcp_label" "$udp_port")"
      return 0
    fi
    warn "$(tf firewall_failed firewalld "$tcp_label" "$udp_port")"
    return 1
  fi

  if command -v ufw >/dev/null 2>&1 && ufw status 2>/dev/null | rg -q '^Status: active'; then
    local ok="true" tcp_port
    for tcp_port in "${tcp_ports[@]}"; do
      maybe_sudo ufw allow "${tcp_port}/tcp" || ok="false"
    done
    maybe_sudo ufw allow "${udp_port}/udp" || ok="false"
    if [[ "$ok" == "true" ]]; then
      info "$(tf firewall_opened ufw "$tcp_label" "$udp_port")"
      return 0
    fi
    warn "$(tf firewall_failed ufw "$tcp_label" "$udp_port")"
    return 1
  fi

  warn "$(tf firewall_manual "$tcp_label" "$udp_port")"
  return 0
}

local_api_host() {
  case "${BIND_ADDRESS:-127.0.0.1}" in
    0.0.0.0|"::"|"[::]"|"*") printf '127.0.0.1' ;;
    *) printf '%s' "$BIND_ADDRESS" ;;
  esac
}

local_api_url() {
  local path="$1"
  local host
  host="$(local_api_host)"
  if [[ "$host" == *:* && "$host" != \[*\] ]]; then
    host="[$host]"
  fi
  printf 'http://%s:%s%s' "$host" "$SERVER_PORT" "$path"
}

setup_initial_admin() {
  require_cmd curl
  require_cmd python3
  info "$(msg progress_setup_admin)"
  local password
  password="$(admin_password_from_credentials)"
  if [[ -z "$password" ]]; then
    warn "$(tf admin_setup_failed "$(admin_credentials_file)")"
    return 1
  fi

  local status_url setup_url body http_code payload
  status_url="$(local_api_url /api/instance)"
  setup_url="$(local_api_url /api/setup)"

  local i total=60
  for ((i = 1; i <= total; i++)); do
    if (( i == 1 || i % 5 == 0 )); then
      info "$(tf admin_setup_waiting "$i" "$total" "$status_url")"
    fi
    body="$(curl -sS --max-time 3 "$status_url" 2>/dev/null || true)"
    if [[ "$body" == *'"setup_required":true'* ]]; then
      payload="$(python3 - "$ADMIN_EMAIL" "$password" <<'PY'
import json
import sys

print(json.dumps({
    "email": sys.argv[1],
    "password": sys.argv[2],
    "name": "NetBird Admin",
    "create_pat": False,
}))
PY
)"
      http_code="$(curl -sS -o "$TMP_DIR/admin-setup-response.json" -w '%{http_code}' --max-time 10 \
        -H 'Content-Type: application/json' -d "$payload" "$setup_url" 2>/dev/null || true)"
      if [[ "$http_code" =~ ^2 ]]; then
        info "$(tf admin_setup_done "$ADMIN_EMAIL" "$(admin_credentials_file)")"
        return 0
      fi
      warn "$(tf admin_setup_http_failed "$http_code" "$setup_url")"
      return 1
    fi
    if [[ "$body" == *'"setup_required":false'* ]]; then
      info "$(msg admin_setup_skipped)"
      return 0
    fi
    sleep 2
  done

  warn "$(tf admin_setup_not_ready "$status_url")"
  return 1
}

uninstall_installation() {
  if [[ -f "$INSTALL_DIR/docker-compose.yml" ]]; then
    if [[ "$DRY_RUN" == "true" ]]; then
      info "$(tf dry_run_compose_down "$INSTALL_DIR")"
    else
      info "$(msg progress_stop_services)"
      run_compose down || true
    fi
  fi

  local generated_files=(
    "$INSTALL_DIR/docker-compose.yml"
    "$INSTALL_DIR/config.yaml"
    "$INSTALL_DIR/config"
    "$INSTALL_DIR/dashboard.env"
    "$(admin_credentials_file)"
  )
  if [[ -d "$INSTALL_DIR" ]]; then
    local nullglob_was_set="false"
    if shopt -q nullglob; then
      nullglob_was_set="true"
    fi
    shopt -s nullglob
    generated_files+=(
      "$INSTALL_DIR"/docker-compose.yml.bak.*
      "$INSTALL_DIR"/config.yaml.bak.*
      "$INSTALL_DIR"/config.bak.*
      "$INSTALL_DIR"/dashboard.env.bak.*
      "$INSTALL_DIR"/admin-credentials.txt.bak.*
    )
    [[ "$nullglob_was_set" == "true" ]] || shopt -u nullglob
  fi
  local generated_exists="false" file
  for file in "${generated_files[@]}"; do
    [[ -e "$file" ]] && generated_exists="true"
  done
  if [[ "$generated_exists" == "true" ]] && tui_yesno "$(tf remove_config "$INSTALL_DIR")"; then
    if [[ "$DRY_RUN" == "true" ]]; then
      for file in "${generated_files[@]}"; do
        [[ -e "$file" ]] && info "$(tf dry_run_remove "$file")"
      done
    else
      for file in "${generated_files[@]}"; do
        [[ -e "$file" ]] || continue
        if [[ -d "$file" && ! -L "$file" ]]; then
          rm -rf "$file"
        else
          rm -f "$file"
        fi
      done
    fi
  fi

  if [[ -d "$INSTALL_DIR/data" ]] && tui_yesno "$(tf remove_data "$INSTALL_DIR")"; then
    if [[ "$DRY_RUN" == "true" ]]; then
      info "$(tf dry_run_remove "$INSTALL_DIR/data")"
    else
      rm -rf "$INSTALL_DIR/data"
    fi
  fi

  if [[ -f "$ONEPANEL_ROOT_CONF" ]] && tui_yesno "$(tf remove_1panel_conf "$ONEPANEL_ROOT_CONF")" no; then
    if [[ "$DRY_RUN" == "true" ]]; then
      info "$(tf dry_run_remove "$ONEPANEL_ROOT_CONF")"
    else
      local backup="${ONEPANEL_ROOT_CONF}.bak.$(date +%Y%m%d%H%M%S)"
      info "$(tf backup_file "$ONEPANEL_ROOT_CONF" "$backup")"
      maybe_sudo cp -a "$ONEPANEL_ROOT_CONF" "$backup"
      maybe_sudo rm -f "$ONEPANEL_ROOT_CONF"
    fi
  fi
  if [[ "$DRY_RUN" != "true" ]]; then
    rmdir "$INSTALL_DIR" 2>/dev/null || true
  fi
  info "$(msg uninstall_done)"
}

install_flow() {
  if ! check_settings >/dev/null; then
    if has_tui; then
      setup_wizard
      return
    fi
    validate_settings
  fi
  render_files
  open_firewall_ports || true
  start_services
  setup_initial_admin || true
  info "$(msg progress_status_checks)"
  show_status
}
