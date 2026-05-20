#!/usr/bin/env bash
set -Eeuo pipefail

APP_NAME="NetBird Server TUI"
DEFAULT_INSTALL_DIR="/root/netbird-docker"
DEFAULT_DOMAIN="netbird.example.com"
DEFAULT_DASHBOARD_PORT="18084"
DEFAULT_SERVER_PORT="18085"
DEFAULT_STUN_PORT="13478"
DEFAULT_1PANEL_ROOT_CONF="/opt/1panel/apps/openresty/openresty/www/sites/${DEFAULT_DOMAIN}/proxy/root.conf"

INSTALL_DIR="${NETBIRD_INSTALL_DIR:-$DEFAULT_INSTALL_DIR}"
DOMAIN="${NETBIRD_DOMAIN:-$DEFAULT_DOMAIN}"
DASHBOARD_PORT="${NETBIRD_DASHBOARD_PORT:-$DEFAULT_DASHBOARD_PORT}"
SERVER_PORT="${NETBIRD_SERVER_PORT:-$DEFAULT_SERVER_PORT}"
STUN_PORT="${NETBIRD_STUN_PORT:-$DEFAULT_STUN_PORT}"
ONEPANEL_ROOT_CONF="${NETBIRD_1PANEL_ROOT_CONF:-$DEFAULT_1PANEL_ROOT_CONF}"
NONINTERACTIVE="false"
DRY_RUN="false"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TMP_DIR="${TMPDIR:-/tmp}/netbird-server-tui"
mkdir -p "$TMP_DIR"

info() { printf '[INFO] %s\n' "$*"; }
warn() { printf '[WARN] %s\n' "$*" >&2; }
die() { printf '[ERROR] %s\n' "$*" >&2; exit 1; }

usage() {
  cat <<EOF
$APP_NAME

Usage:
  $0 [--install-dir DIR] [--domain DOMAIN] [--dashboard-port PORT]
     [--server-port PORT] [--stun-port PORT] [--1panel-root-conf FILE]
     [--noninteractive] [--dry-run] [command]

Commands:
  menu                 Open TUI menu (default)
  install              Render files and start services
  render               Render docker-compose.yml, config.yaml, dashboard.env
  start|stop|restart   Manage Docker Compose services
  status               Show service and endpoint status
  logs                 Tail recent service logs
  1panel-preview       Print OpenResty location config
  1panel-apply         Backup and write OpenResty root.conf
  1panel-check         Check OpenResty config and reload if possible
  backup               Archive config and data directory
  uninstall            Stop services and optionally remove data
  self-test            Run non-destructive local behavior tests

Environment overrides use NETBIRD_* names, for example NETBIRD_INSTALL_DIR.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --install-dir) INSTALL_DIR="$2"; shift 2 ;;
    --domain) DOMAIN="$2"; shift 2 ;;
    --dashboard-port) DASHBOARD_PORT="$2"; shift 2 ;;
    --server-port) SERVER_PORT="$2"; shift 2 ;;
    --stun-port) STUN_PORT="$2"; shift 2 ;;
    --1panel-root-conf) ONEPANEL_ROOT_CONF="$2"; shift 2 ;;
    --noninteractive) NONINTERACTIVE="true"; shift ;;
    --dry-run) DRY_RUN="true"; shift ;;
    -h|--help) usage; exit 0 ;;
    *) COMMAND="${1:-menu}"; shift; break ;;
  esac
done
COMMAND="${COMMAND:-menu}"

compose_cmd() {
  if docker compose version >/dev/null 2>&1; then
    echo "docker compose"
  elif command -v docker-compose >/dev/null 2>&1; then
    echo "docker-compose"
  else
    return 1
  fi
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || die "Missing required command: $1"
}

has_tui() {
  [[ -t 0 && "$NONINTERACTIVE" != "true" ]] && { command -v whiptail >/dev/null 2>&1 || command -v dialog >/dev/null 2>&1 || command -v fzf >/dev/null 2>&1; }
}

tui_menu() {
  local title="$1"; shift
  if command -v whiptail >/dev/null 2>&1; then
    whiptail --title "$APP_NAME" --menu "$title" 20 76 10 "$@" 3>&1 1>&2 2>&3
  elif command -v dialog >/dev/null 2>&1; then
    dialog --title "$APP_NAME" --menu "$title" 20 76 10 "$@" 3>&1 1>&2 2>&3
  elif command -v fzf >/dev/null 2>&1; then
    local lines=()
    while [[ $# -gt 0 ]]; do
      lines+=("$1 $2")
      shift 2
    done
    printf '%s\n' "${lines[@]}" | fzf --prompt="$title > " | awk '{print $1}'
  else
    return 1
  fi
}

tui_yesno() {
  local message="$1"
  if [[ "$NONINTERACTIVE" == "true" ]]; then
    return 0
  fi
  if command -v whiptail >/dev/null 2>&1; then
    whiptail --title "$APP_NAME" --yesno "$message" 12 72
  elif command -v dialog >/dev/null 2>&1; then
    dialog --title "$APP_NAME" --yesno "$message" 12 72
  else
    read -r -p "$message [y/N] " answer
    [[ "$answer" =~ ^[Yy]$ ]]
  fi
}

tui_input() {
  local prompt="$1"
  local default="$2"
  if [[ "$NONINTERACTIVE" == "true" ]]; then
    printf '%s\n' "$default"
    return 0
  fi
  if command -v whiptail >/dev/null 2>&1; then
    whiptail --title "$APP_NAME" --inputbox "$prompt" 10 72 "$default" 3>&1 1>&2 2>&3
  elif command -v dialog >/dev/null 2>&1; then
    dialog --title "$APP_NAME" --inputbox "$prompt" 10 72 "$default" 3>&1 1>&2 2>&3
  else
    read -r -p "$prompt [$default] " answer
    printf '%s\n' "${answer:-$default}"
  fi
}

maybe_sudo() {
  local err="$TMP_DIR/maybe-sudo.err"
  if "$@" 2>"$err"; then
    rm -f "$err"
    return 0
  fi
  local rc=$?
  if [[ "${EUID:-$(id -u)}" -ne 0 && -t 0 && -t 1 && -t 2 && -x "$(command -v sudo 2>/dev/null || true)" ]]; then
    sudo "$@"
    return $?
  fi
  cat "$err" >&2
  rm -f "$err"
  return "$rc"
}

run_compose() {
  local cmd
  cmd="$(compose_cmd)" || die "Docker Compose is required"
  (cd "$INSTALL_DIR" && $cmd "$@")
}

random_secret() {
  openssl rand -base64 32 | tr -d '\n'
}

valid_port() {
  [[ "$1" =~ ^[0-9]+$ ]] && (( "$1" >= 1 && "$1" <= 65535 ))
}

validate_settings() {
  [[ -n "$DOMAIN" ]] || die "Domain cannot be empty"
  valid_port "$DASHBOARD_PORT" || die "Invalid dashboard port: $DASHBOARD_PORT"
  valid_port "$SERVER_PORT" || die "Invalid server port: $SERVER_PORT"
  valid_port "$STUN_PORT" || die "Invalid STUN port: $STUN_PORT"
  [[ "$DASHBOARD_PORT" != "$SERVER_PORT" ]] || die "Dashboard and server ports must differ"
}

prompt_settings() {
  DOMAIN="$(tui_input "NetBird public domain" "$DOMAIN")"
  INSTALL_DIR="$(tui_input "Install directory" "$INSTALL_DIR")"
  DASHBOARD_PORT="$(tui_input "Dashboard localhost port" "$DASHBOARD_PORT")"
  SERVER_PORT="$(tui_input "Combined server localhost port" "$SERVER_PORT")"
  STUN_PORT="$(tui_input "Public UDP STUN port" "$STUN_PORT")"
  ONEPANEL_ROOT_CONF="$(tui_input "1Panel OpenResty root.conf path" "$ONEPANEL_ROOT_CONF")"
  validate_settings
}

existing_yaml_value() {
  local file="$1"
  local key="$2"
  [[ -f "$file" ]] || return 1
  python3 - "$file" "$key" <<'PY' 2>/dev/null
import re
import sys
path, key = sys.argv[1], sys.argv[2]
text = open(path, encoding="utf-8").read()
pattern = rf"^\s*{re.escape(key)}:\s*[\"']?([^\"'\n#]+)"
match = re.search(pattern, text, re.M)
if match:
    print(match.group(1).strip())
    sys.exit(0)
sys.exit(1)
PY
}

existing_secret_or_new() {
  local config="$INSTALL_DIR/config.yaml"
  if existing_yaml_value "$config" "authSecret"; then
    return 0
  fi
  random_secret
}

existing_encryption_key_or_new() {
  local config="$INSTALL_DIR/config.yaml"
  if existing_yaml_value "$config" "encryptionKey"; then
    return 0
  fi
  random_secret
}

backup_file_if_exists() {
  local file="$1"
  [[ -e "$file" ]] || return 0
  local backup="${file}.bak.$(date +%Y%m%d%H%M%S)"
  info "Backup: $file -> $backup"
  cp -a "$file" "$backup"
}

write_file() {
  local target="$1"
  local tmp="$2"
  if [[ "$DRY_RUN" == "true" ]]; then
    info "Dry run: would write $target"
    cat "$tmp"
    return 0
  fi
  mkdir -p "$(dirname "$target")"
  backup_file_if_exists "$target"
  cp "$tmp" "$target"
}

render_compose() {
  cat <<EOF
services:
  dashboard:
    image: netbirdio/dashboard:latest
    container_name: netbird-dashboard
    restart: unless-stopped
    env_file:
      - ./dashboard.env
    ports:
      - "127.0.0.1:${DASHBOARD_PORT}:80"
    depends_on:
      - netbird-server
    logging:
      driver: "json-file"
      options:
        max-size: "100m"
        max-file: "3"

  netbird-server:
    image: netbirdio/netbird-server:latest
    container_name: netbird-server
    restart: unless-stopped
    environment:
      NB_DISABLE_GEOLOCATION: "true"
    ports:
      - "127.0.0.1:${SERVER_PORT}:80"
      - "${STUN_PORT}:${STUN_PORT}/udp"
    volumes:
      - ./config.yaml:/etc/netbird/config.yaml:ro
      - ./data:/var/lib/netbird
    command: ["--config", "/etc/netbird/config.yaml"]
    logging:
      driver: "json-file"
      options:
        max-size: "100m"
        max-file: "3"
EOF
}

render_config_yaml() {
  local relay_secret="$1"
  local encryption_key="$2"
  cat <<EOF
# Generated by netbird-server-tui.sh
server:
  listenAddress: ":80"
  exposedAddress: "https://${DOMAIN}:443"
  stunPorts:
    - ${STUN_PORT}
  metricsPort: 9090
  healthcheckAddress: ":9000"
  logLevel: "info"
  logFile: "console"

  authSecret: "${relay_secret}"
  dataDir: "/var/lib/netbird"

  disableAnonymousMetrics: true
  disableGeoliteUpdate: true

  auth:
    issuer: "https://${DOMAIN}/oauth2"
    signKeyRefreshEnabled: true
    dashboardRedirectURIs:
      - "https://${DOMAIN}/nb-auth"
      - "https://${DOMAIN}/nb-silent-auth"
    cliRedirectURIs:
      - "http://localhost:53000/"

  reverseProxy:
    trustedHTTPProxies:
      - "127.0.0.1/32"
      - "172.16.0.0/12"
      - "10.0.0.0/8"
      - "192.168.0.0/16"

  store:
    engine: "sqlite"
    encryptionKey: "${encryption_key}"
EOF
}

render_dashboard_env() {
  cat <<EOF
# Generated by netbird-server-tui.sh
NETBIRD_MGMT_API_ENDPOINT=https://${DOMAIN}
NETBIRD_MGMT_GRPC_API_ENDPOINT=https://${DOMAIN}
AUTH_AUDIENCE=netbird-dashboard
AUTH_CLIENT_ID=netbird-dashboard
AUTH_CLIENT_SECRET=
AUTH_AUTHORITY=https://${DOMAIN}/oauth2
USE_AUTH0=false
AUTH_SUPPORTED_SCOPES=openid profile email groups
AUTH_REDIRECT_URI=/nb-auth
AUTH_SILENT_REDIRECT_URI=/nb-silent-auth
NGINX_SSL_PORT=443
LETSENCRYPT_DOMAIN=none
EOF
}

render_openresty_root_conf() {
  cat <<EOF
location ^~ /relay {
    proxy_pass http://127.0.0.1:${SERVER_PORT};
    proxy_http_version 1.1;
    proxy_set_header Upgrade \$http_upgrade;
    proxy_set_header Connection "upgrade";
    proxy_set_header Host \$host;
    proxy_set_header X-Real-IP \$remote_addr;
    proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto https;
    proxy_read_timeout 1d;
}

location ^~ /ws-proxy/ {
    proxy_pass http://127.0.0.1:${SERVER_PORT};
    proxy_http_version 1.1;
    proxy_set_header Upgrade \$http_upgrade;
    proxy_set_header Connection "upgrade";
    proxy_set_header Host \$host;
    proxy_set_header X-Real-IP \$remote_addr;
    proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto https;
    proxy_read_timeout 1d;
}

location ^~ /signalexchange.SignalExchange/ {
    grpc_pass grpc://127.0.0.1:${SERVER_PORT};
    grpc_read_timeout 1d;
    grpc_send_timeout 1d;
    grpc_socket_keepalive on;
    grpc_set_header Host \$host;
    grpc_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
    grpc_set_header X-Forwarded-Proto https;
}

location ^~ /management.ManagementService/ {
    grpc_pass grpc://127.0.0.1:${SERVER_PORT};
    grpc_read_timeout 1d;
    grpc_send_timeout 1d;
    grpc_socket_keepalive on;
    grpc_set_header Host \$host;
    grpc_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
    grpc_set_header X-Forwarded-Proto https;
}

location ^~ /management.ProxyService/ {
    grpc_pass grpc://127.0.0.1:${SERVER_PORT};
    grpc_read_timeout 1d;
    grpc_send_timeout 1d;
    grpc_socket_keepalive on;
    grpc_set_header Host \$host;
    grpc_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
    grpc_set_header X-Forwarded-Proto https;
}

location ^~ /api/ {
    proxy_pass http://127.0.0.1:${SERVER_PORT};
    proxy_set_header Host \$host;
    proxy_set_header X-Real-IP \$remote_addr;
    proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto https;
    proxy_read_timeout 1d;
}

location ^~ /oauth2/ {
    proxy_pass http://127.0.0.1:${SERVER_PORT};
    proxy_set_header Host \$host;
    proxy_set_header X-Real-IP \$remote_addr;
    proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto https;
    proxy_read_timeout 1d;
}

location ^~ / {
    proxy_pass http://127.0.0.1:${DASHBOARD_PORT};
    proxy_set_header Host \$host;
    proxy_set_header X-Real-IP \$remote_addr;
    proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
    proxy_set_header REMOTE-HOST \$remote_addr;
    proxy_set_header Upgrade \$http_upgrade;
    proxy_set_header Connection \$http_connection;
    proxy_set_header X-Forwarded-Proto https;
    proxy_http_version 1.1;
    add_header X-Cache \$upstream_cache_status;
    add_header Cache-Control no-cache;
    proxy_ssl_server_name off;
    proxy_ssl_name \$proxy_host;
    add_header Strict-Transport-Security "max-age=31536000";
}
EOF
}

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

self_test() {
  require_cmd bash
  require_cmd python3
  require_cmd openssl
  local sandbox="$TMP_DIR/self-test-install"
  rm -rf "$sandbox"
  mkdir -p "$sandbox"
  info "Running render self-test in $sandbox"
  NETBIRD_INSTALL_DIR="$sandbox" \
  NETBIRD_DOMAIN="test.example.invalid" \
  NETBIRD_DASHBOARD_PORT="28084" \
  NETBIRD_SERVER_PORT="28085" \
  NETBIRD_STUN_PORT="23478" \
  NETBIRD_1PANEL_ROOT_CONF="$sandbox/root.conf" \
  bash "$0" --noninteractive --install-dir "$sandbox" --domain test.example.invalid --dashboard-port 28084 --server-port 28085 --stun-port 23478 render

  bash -n "$0"
  python3 - "$sandbox" <<'PY'
import pathlib
import sys
root = pathlib.Path(sys.argv[1])
required = ["docker-compose.yml", "config.yaml", "dashboard.env"]
missing = [name for name in required if not (root / name).exists()]
if missing:
    raise SystemExit(f"missing files: {missing}")
compose = (root / "docker-compose.yml").read_text()
config = (root / "config.yaml").read_text()
env = (root / "dashboard.env").read_text()
checks = [
    ("127.0.0.1:28084:80", compose),
    ("127.0.0.1:28085:80", compose),
    ("23478:23478/udp", compose),
    ('exposedAddress: "https://test.example.invalid:443"', config),
    ("- 23478", config),
    ("AUTH_AUTHORITY=https://test.example.invalid/oauth2", env),
]
for needle, haystack in checks:
    if needle not in haystack:
        raise SystemExit(f"missing expected content: {needle}")
print("render assertions passed")
PY
  NETBIRD_INSTALL_DIR="$sandbox" \
  bash "$0" --noninteractive --install-dir "$sandbox" --domain test.example.invalid --dashboard-port 28084 --server-port 28085 --stun-port 23478 --1panel-root-conf "$sandbox/root.conf" 1panel-apply
  rg -n "127\\.0\\.0\\.1:28085|127\\.0\\.0\\.1:28084|grpc_pass" "$sandbox/root.conf" >/dev/null
  info "Self-test passed"
}

main_menu() {
  while true; do
    local choice
    choice="$(tui_menu "Select operation" \
      install "Render config and start services" \
      render "Render or update generated files" \
      start "Start services" \
      stop "Stop services" \
      restart "Restart services" \
      status "Show status and endpoint checks" \
      logs "Show recent logs" \
      onepanel-preview "Preview 1Panel OpenResty config" \
      onepanel-apply "Apply 1Panel OpenResty config" \
      onepanel-check "Check and optionally reload OpenResty" \
      backup "Backup config and data" \
      uninstall "Uninstall services/config" \
      self-test "Run local behavior tests" \
      quit "Exit")" || exit 0
    case "$choice" in
      install) install_flow ;;
      render) prompt_settings; render_files ;;
      start) start_services ;;
      stop) stop_services ;;
      restart) restart_services ;;
      status) show_status ;;
      logs) show_logs ;;
      onepanel-preview) render_openresty_root_conf | ${PAGER:-less} ;;
      onepanel-apply) prompt_settings; apply_1panel_conf ;;
      onepanel-check) check_1panel ;;
      backup) backup_installation ;;
      uninstall) uninstall_installation ;;
      self-test) self_test ;;
      quit) exit 0 ;;
    esac
    if [[ -t 0 ]]; then
      read -r -p "Press Enter to continue..." _
    fi
  done
}

case "$COMMAND" in
  menu) main_menu ;;
  install) install_flow ;;
  render) render_files ;;
  start) start_services ;;
  stop) stop_services ;;
  restart) restart_services ;;
  status) show_status ;;
  logs) show_logs ;;
  1panel-preview) render_openresty_root_conf ;;
  1panel-apply) apply_1panel_conf ;;
  1panel-check) check_1panel ;;
  backup) backup_installation ;;
  uninstall) uninstall_installation ;;
  self-test) self_test ;;
  *) usage; die "Unknown command: $COMMAND" ;;
esac
