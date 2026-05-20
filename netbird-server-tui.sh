#!/usr/bin/env bash
set -Eeuo pipefail

APP_NAME="NetBird Server TUI"
NONINTERACTIVE="false"
DRY_RUN="false"
COMMAND="menu"

SCRIPT_PATH="${BASH_SOURCE[0]}"
SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_PATH")" && pwd)"
TMP_DIR="${TMPDIR:-/tmp}/netbird-server-tui"
mkdir -p "$TMP_DIR"

# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"
# shellcheck source=lib/config.sh
source "$SCRIPT_DIR/lib/config.sh"
# shellcheck source=lib/i18n.sh
source "$SCRIPT_DIR/lib/i18n.sh"
# shellcheck source=lib/render.sh
source "$SCRIPT_DIR/lib/render.sh"
# shellcheck source=lib/actions.sh
source "$SCRIPT_DIR/lib/actions.sh"
# shellcheck source=lib/wizard.sh
source "$SCRIPT_DIR/lib/wizard.sh"
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
     [--bind-address IP] [--public-scheme http|https] [--public-port PORT]
     [--profile NAME] [--config FILE] [--lang zh|en] [--noninteractive] [--dry-run] [command]

Commands:
  menu                 Open TUI menu (default)
  wizard               Guided setup flow
  install              Render files and start services
  render               Render docker-compose.yml, config.yaml, dashboard.env
  start|stop|restart   Manage Docker Compose services
  status               Show service and endpoint status
  logs                 Tail recent service logs
  1panel-preview       Print OpenResty location config
  1panel-apply         Backup and write OpenResty root.conf
  1panel-check         Check OpenResty config and reload if possible
  backup               Archive config and data directory
  doctor               Check prerequisites and current configuration
  uninstall            Stop services and optionally remove data
  self-test            Run non-destructive local behavior tests

Profiles are stored under ./profiles and ignored by git.
Environment overrides use NETBIRD_* names, for example NETBIRD_INSTALL_DIR.
Language defaults to Chinese. Use --lang en or NETBIRD_LANG=en for English.
EOF
}

load_config

while [[ $# -gt 0 ]]; do
  case "$1" in
    --profile) NETBIRD_PROFILE="$2"; load_config; shift 2 ;;
    --config) NETBIRD_CONFIG_FILE="$2"; load_config; shift 2 ;;
    --install-dir) INSTALL_DIR="$2"; shift 2 ;;
    --domain) DOMAIN="$2"; shift 2 ;;
    --dashboard-port) DASHBOARD_PORT="$2"; shift 2 ;;
    --server-port) SERVER_PORT="$2"; shift 2 ;;
    --stun-port) STUN_PORT="$2"; shift 2 ;;
    --1panel-root-conf) ONEPANEL_ROOT_CONF="$2"; shift 2 ;;
    --bind-address) BIND_ADDRESS="$2"; shift 2 ;;
    --public-scheme) PUBLIC_SCHEME="$2"; shift 2 ;;
    --public-port) PUBLIC_PORT="$2"; shift 2 ;;
    --lang) set_language "$2"; shift 2 ;;
    --noninteractive) NONINTERACTIVE="true"; shift ;;
    --dry-run) DRY_RUN="true"; shift ;;
    -h|--help) usage; exit 0 ;;
    *) COMMAND="$1"; shift; break ;;
  esac
done
reload_config_after_cli

select_language

case "$COMMAND" in
  menu) main_menu ;;
  wizard) setup_wizard ;;
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
  doctor) doctor_check ;;
  uninstall) uninstall_installation ;;
  self-test) self_test ;;
  *) usage; die "$(tf err_unknown_command "$COMMAND")" ;;
esac
