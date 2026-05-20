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
  info "Rendered files in $INSTALL_DIR"
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
    info "$name OK ($code): $url"
  else
    warn "$name not ready ($code): $url"
  fi
}

show_status() {
  info "Install dir: $INSTALL_DIR"
  info "Domain: https://$DOMAIN"
  info "Dashboard local: http://127.0.0.1:$DASHBOARD_PORT"
  info "Server local: http://127.0.0.1:$SERVER_PORT"
  info "STUN UDP: $STUN_PORT"
  if [[ -f "$INSTALL_DIR/docker-compose.yml" ]]; then
    run_compose ps || true
  else
    warn "docker-compose.yml not found"
  fi
  endpoint_check "Dashboard local" "http://127.0.0.1:${DASHBOARD_PORT}/"
  endpoint_check "OIDC local" "http://127.0.0.1:${SERVER_PORT}/oauth2/.well-known/openid-configuration"
  endpoint_check "OIDC public" "https://${DOMAIN}/oauth2/.well-known/openid-configuration"
  if [[ -f "$ONEPANEL_ROOT_CONF" ]]; then
    info "1Panel root.conf exists: $ONEPANEL_ROOT_CONF"
  else
    warn "1Panel root.conf not found: $ONEPANEL_ROOT_CONF"
  fi
}

show_logs() {
  run_compose logs --tail=120 dashboard netbird-server
}

apply_1panel_conf() {
  validate_settings
  render_openresty_root_conf > "$TMP_DIR/root.conf"
  if [[ "$DRY_RUN" == "true" ]]; then
    info "Dry run: would write $ONEPANEL_ROOT_CONF"
    cat "$TMP_DIR/root.conf"
    return 0
  fi
  maybe_sudo mkdir -p "$(dirname "$ONEPANEL_ROOT_CONF")"
  if [[ -f "$ONEPANEL_ROOT_CONF" ]]; then
    local backup="${ONEPANEL_ROOT_CONF}.bak.$(date +%Y%m%d%H%M%S)"
    info "Backup: $ONEPANEL_ROOT_CONF -> $backup"
    maybe_sudo cp -a "$ONEPANEL_ROOT_CONF" "$backup"
  fi
  maybe_sudo cp "$TMP_DIR/root.conf" "$ONEPANEL_ROOT_CONF"
  info "Wrote $ONEPANEL_ROOT_CONF"
}

check_1panel() {
  local container
  if [[ -f "$ONEPANEL_ROOT_CONF" ]]; then
    info "root.conf contains:"
    rg -n "127\\.0\\.0\\.1:${SERVER_PORT}|127\\.0\\.0\\.1:${DASHBOARD_PORT}|grpc_pass|proxy_pass" "$ONEPANEL_ROOT_CONF" || true
  else
    warn "root.conf not found: $ONEPANEL_ROOT_CONF"
  fi

  container="$(docker ps --format '{{.Names}}' | rg 'openresty|1panel.*openresty' | head -n 1 || true)"
  if [[ -n "$container" ]]; then
    info "Checking OpenResty container: $container"
    docker exec "$container" nginx -t
    if tui_yesno "Reload OpenResty container $container now?"; then
      docker exec "$container" nginx -s reload
    fi
  else
    warn "No running OpenResty container detected. You can reload it from 1Panel after applying root.conf."
  fi
}

backup_installation() {
  local backup_dir archive
  backup_dir="$(dirname "$INSTALL_DIR")"
  archive="${backup_dir}/netbird-backup-$(date +%Y%m%d%H%M%S).tar.gz"
  tar -czf "$archive" -C "$INSTALL_DIR" docker-compose.yml config.yaml dashboard.env data 2>/dev/null || tar -czf "$archive" -C "$INSTALL_DIR" .
  info "Backup archive: $archive"
}

uninstall_installation() {
  if [[ -f "$INSTALL_DIR/docker-compose.yml" ]]; then
    run_compose down || true
  fi
  if tui_yesno "Remove generated config files in $INSTALL_DIR? Data is kept unless you confirm the next prompt."; then
    rm -f "$INSTALL_DIR/docker-compose.yml" "$INSTALL_DIR/config.yaml" "$INSTALL_DIR/dashboard.env"
  fi
  if tui_yesno "Remove NetBird data directory $INSTALL_DIR/data? This deletes SQLite state."; then
    rm -rf "$INSTALL_DIR/data"
  fi
  info "Uninstall step finished"
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
