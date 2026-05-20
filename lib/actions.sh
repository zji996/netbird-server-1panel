render_files() {
  validate_settings
  require_cmd openssl
  local relay_secret encryption_key
  relay_secret="$(existing_secret_or_new)"
  encryption_key="$(existing_encryption_key_or_new)"

  mkdir -p "$INSTALL_DIR/data"
  render_compose > "$TMP_DIR/docker-compose.yml"
  render_config_yaml "$relay_secret" "$encryption_key" > "$TMP_DIR/config.yaml"
  render_dashboard_env > "$TMP_DIR/dashboard.env"

  write_file "$INSTALL_DIR/docker-compose.yml" "$TMP_DIR/docker-compose.yml"
  write_file "$INSTALL_DIR/config.yaml" "$TMP_DIR/config.yaml"
  write_file "$INSTALL_DIR/dashboard.env" "$TMP_DIR/dashboard.env"
  info "$(tf rendered_files "$INSTALL_DIR")"
}

start_services() {
  require_cmd docker
  run_compose up -d
}

stop_services() {
  run_compose down
}

restart_services() {
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

show_status() {
  info "$(tf status_install_dir "$INSTALL_DIR")"
  info "$(tf status_domain "$DOMAIN")"
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
  endpoint_check "$(msg endpoint_oidc_public)" "https://${DOMAIN}/oauth2/.well-known/openid-configuration"
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
}

check_1panel() {
  local container
  if [[ -f "$ONEPANEL_ROOT_CONF" ]]; then
    info "$(msg root_conf_contains)"
    rg -n "127\\.0\\.0\\.1:${SERVER_PORT}|127\\.0\\.0\\.1:${DASHBOARD_PORT}|grpc_pass|proxy_pass" "$ONEPANEL_ROOT_CONF" || true
  else
    warn "$(tf root_conf_missing "$ONEPANEL_ROOT_CONF")"
  fi

  container="$(docker ps --format '{{.Names}}' | rg 'openresty|1panel.*openresty' | head -n 1 || true)"
  if [[ -n "$container" ]]; then
    info "$(tf checking_openresty "$container")"
    docker exec "$container" nginx -t
    if tui_yesno "$(tf reload_openresty "$container")"; then
      docker exec "$container" nginx -s reload
    fi
  else
    warn "$(msg no_openresty)"
  fi
}

backup_installation() {
  local backup_dir archive
  backup_dir="$(dirname "$INSTALL_DIR")"
  archive="${backup_dir}/netbird-backup-$(date +%Y%m%d%H%M%S).tar.gz"
  tar -czf "$archive" -C "$INSTALL_DIR" docker-compose.yml config.yaml dashboard.env data 2>/dev/null || tar -czf "$archive" -C "$INSTALL_DIR" .
  info "$(tf backup_archive "$archive")"
}

uninstall_installation() {
  if [[ -f "$INSTALL_DIR/docker-compose.yml" ]]; then
    run_compose down || true
  fi
  if tui_yesno "$(tf remove_config "$INSTALL_DIR")"; then
    rm -f "$INSTALL_DIR/docker-compose.yml" "$INSTALL_DIR/config.yaml" "$INSTALL_DIR/dashboard.env"
  fi
  if tui_yesno "$(tf remove_data "$INSTALL_DIR")"; then
    rm -rf "$INSTALL_DIR/data"
  fi
  info "$(msg uninstall_done)"
}

install_flow() {
  if has_tui; then
    prompt_settings
  else
    validate_settings
  fi
  render_files
  start_services
  show_status
}
