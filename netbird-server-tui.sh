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
COMMAND="menu"

SCRIPT_PATH="${BASH_SOURCE[0]}"
SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_PATH")" && pwd)"
TMP_DIR="${TMPDIR:-/tmp}/netbird-server-tui"
mkdir -p "$TMP_DIR"

# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"
# shellcheck source=lib/i18n.sh
source "$SCRIPT_DIR/lib/i18n.sh"
# shellcheck source=lib/render.sh
source "$SCRIPT_DIR/lib/render.sh"
# shellcheck source=lib/actions.sh
source "$SCRIPT_DIR/lib/actions.sh"
# shellcheck source=lib/self-test.sh
source "$SCRIPT_DIR/lib/self-test.sh"
# shellcheck source=lib/menu.sh
source "$SCRIPT_DIR/lib/menu.sh"

usage() {
  cat <<EOF
$APP_NAME

Usage:
  $0 [--install-dir DIR] [--domain DOMAIN] [--dashboard-port PORT]
     [--server-port PORT] [--stun-port PORT] [--1panel-root-conf FILE]
     [--lang zh|en] [--noninteractive] [--dry-run] [command]

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
Language defaults to Chinese. Use --lang en or NETBIRD_LANG=en for English.
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
    --lang) set_language "$2"; shift 2 ;;
    --noninteractive) NONINTERACTIVE="true"; shift ;;
    --dry-run) DRY_RUN="true"; shift ;;
    -h|--help) usage; exit 0 ;;
    *) COMMAND="$1"; shift; break ;;
  esac
done

select_language

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
  *) usage; die "$(tf err_unknown_command "$COMMAND")" ;;
esac
