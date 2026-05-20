load_env_file() {
  local file="$1"
  [[ -f "$file" ]] || return 0
  set -a
  # shellcheck disable=SC1090
  source "$file"
  set +a
}

derive_config() {
  ONEPANEL_ROOT_CONF="${ONEPANEL_ROOT_CONF:-/opt/1panel/apps/openresty/openresty/www/sites/${DOMAIN}/proxy/root.conf}"
}

reset_config_values() {
  INSTALL_DIR=""
  DOMAIN=""
  DASHBOARD_PORT=""
  SERVER_PORT=""
  STUN_PORT=""
  BIND_ADDRESS=""
  PUBLIC_SCHEME=""
  PUBLIC_PORT=""
  DASHBOARD_IMAGE=""
  SERVER_IMAGE=""
  ONEPANEL_ROOT_CONF=""
}

load_config() {
  local config_file="${NETBIRD_CONFIG_FILE:-$SCRIPT_DIR/netbird-server.env}"
  reset_config_values
  load_env_file "$config_file"

  INSTALL_DIR="${NETBIRD_INSTALL_DIR:-${INSTALL_DIR:-/root/netbird-docker}}"
  DOMAIN="${NETBIRD_DOMAIN:-${DOMAIN:-netbird.example.com}}"
  DASHBOARD_PORT="${NETBIRD_DASHBOARD_PORT:-${DASHBOARD_PORT:-18084}}"
  SERVER_PORT="${NETBIRD_SERVER_PORT:-${SERVER_PORT:-18085}}"
  STUN_PORT="${NETBIRD_STUN_PORT:-${STUN_PORT:-13478}}"
  BIND_ADDRESS="${NETBIRD_BIND_ADDRESS:-${BIND_ADDRESS:-127.0.0.1}}"
  PUBLIC_SCHEME="${NETBIRD_PUBLIC_SCHEME:-${PUBLIC_SCHEME:-https}}"
  PUBLIC_PORT="${NETBIRD_PUBLIC_PORT:-${PUBLIC_PORT:-443}}"
  DASHBOARD_IMAGE="${NETBIRD_DASHBOARD_IMAGE:-${DASHBOARD_IMAGE:-netbirdio/dashboard:latest}}"
  SERVER_IMAGE="${NETBIRD_SERVER_IMAGE:-${SERVER_IMAGE:-netbirdio/netbird-server:latest}}"
  ONEPANEL_ROOT_CONF="${NETBIRD_1PANEL_ROOT_CONF:-${ONEPANEL_ROOT_CONF:-}}"
  derive_config
}

reload_config_after_cli() {
  derive_config
}
