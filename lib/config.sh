load_env_file() {
  local file="$1"
  [[ -f "$file" ]] || return 0
  set -a
  # shellcheck disable=SC1090
  source "$file"
  set +a
}

CONFIG_ENV_KEYS=(
  NETBIRD_DOMAIN
  NETBIRD_INSTALL_DIR
  NETBIRD_DASHBOARD_PORT
  NETBIRD_SERVER_PORT
  NETBIRD_STUN_PORT
  NETBIRD_BIND_ADDRESS
  NETBIRD_PUBLIC_SCHEME
  NETBIRD_PUBLIC_PORT
  NETBIRD_ADMIN_EMAIL
  NETBIRD_DASHBOARD_IMAGE
  NETBIRD_SERVER_IMAGE
  NETBIRD_1PANEL_ROOT_CONF
)
CONFIG_ENV_OVERRIDES_CAPTURED="false"

capture_config_env_overrides() {
  [[ "$CONFIG_ENV_OVERRIDES_CAPTURED" == "true" ]] && return 0
  local key set_var value_var
  for key in "${CONFIG_ENV_KEYS[@]}"; do
    set_var="ORIGINAL_${key}_SET"
    value_var="ORIGINAL_${key}"
    if [[ ${!key+x} ]]; then
      printf -v "$set_var" '%s' "true"
      printf -v "$value_var" '%s' "${!key}"
    else
      printf -v "$set_var" '%s' "false"
    fi
  done
  CONFIG_ENV_OVERRIDES_CAPTURED="true"
}

clear_config_env_values() {
  unset "${CONFIG_ENV_KEYS[@]}"
}

restore_config_env_overrides() {
  local key set_var value_var
  for key in "${CONFIG_ENV_KEYS[@]}"; do
    set_var="ORIGINAL_${key}_SET"
    value_var="ORIGINAL_${key}"
    if [[ "${!set_var:-false}" == "true" ]]; then
      printf -v "$key" '%s' "${!value_var}"
    fi
  done
}

profile_dir() {
  echo "${NETBIRD_PROFILE_DIR:-$SCRIPT_DIR/profiles}"
}

profile_file() {
  local name
  name="$(sanitize_profile_name "$1")"
  echo "$(profile_dir)/$name/profile.env"
}

sanitize_profile_name() {
  local raw="${1:-default}"
  raw="${raw// /-}"
  raw="$(printf '%s' "$raw" | tr -cd '[:alnum:]_.-')"
  [[ "$raw" == "." || "$raw" == ".." ]] && raw="default"
  printf '%s' "${raw:-default}"
}

derive_profile_name() {
  local domain="${1:-default}"
  domain="${domain//./-}"
  sanitize_profile_name "$domain"
}

default_public_port() {
  if [[ "${1:-http}" == "https" ]]; then
    printf '443'
  else
    printf '80'
  fi
}

public_hostport() {
  local default_port
  default_port="$(default_public_port "$PUBLIC_SCHEME")"
  if [[ -n "${PUBLIC_PORT:-}" && "$PUBLIC_PORT" != "$default_port" ]]; then
    printf '%s:%s' "$DOMAIN" "$PUBLIC_PORT"
  else
    printf '%s' "$DOMAIN"
  fi
}

public_origin() {
  printf '%s://%s' "$PUBLIC_SCHEME" "$(public_hostport)"
}

public_url() {
  local path="${1:-}"
  printf '%s%s' "$(public_origin)" "$path"
}

normalize_domain_public_parts() {
  local value="${DOMAIN:-}"
  local parsed_scheme="" parsed_port=""
  local previous_scheme previous_default
  previous_scheme="${PUBLIC_SCHEME:-http}"
  previous_default="$(default_public_port "$previous_scheme")"

  if [[ "$value" == *"://"* ]]; then
    parsed_scheme="${value%%://*}"
    value="${value#*://}"
    case "$parsed_scheme" in
      http|https) PUBLIC_SCHEME="$parsed_scheme" ;;
    esac
  fi

  value="${value%%/*}"

  if [[ "$value" =~ ^([^:]+):([0-9]+)$ ]]; then
    value="${BASH_REMATCH[1]}"
    parsed_port="${BASH_REMATCH[2]}"
  fi

  DOMAIN="$value"
  if [[ -n "$parsed_port" && ( -z "${PUBLIC_PORT:-}" || "${PUBLIC_PORT:-}" == "$previous_default" || "${PUBLIC_PORT:-}" == "$(default_public_port "$PUBLIC_SCHEME")" ) ]]; then
    PUBLIC_PORT="$parsed_port"
  fi
}

list_profiles() {
  local dir
  dir="$(profile_dir)"
  [[ -d "$dir" ]] || return 0
  find "$dir" -mindepth 2 -maxdepth 2 -name profile.env -printf '%h\n' 2>/dev/null | xargs -r -n1 basename | sort
}

profile_one_line() {
  local name
  name="$(sanitize_profile_name "$1")"
  local file
  file="$(profile_file "$name")"
  [[ -f "$file" ]] || { printf '%s' "$name"; return 0; }
  local domain
  domain="$(grep -E '^NETBIRD_DOMAIN=' "$file" 2>/dev/null | tail -n1 | cut -d= -f2-)"
  domain="${domain%\"}"
  domain="${domain#\"}"
  domain="${domain%\'}"
  domain="${domain#\'}"
  if [[ -n "$domain" ]]; then
    printf '%s' "$domain"
  else
    printf '%s' "$name"
  fi
}

delete_profile() {
  local name
  name="$(sanitize_profile_name "$1")"
  local dir
  dir="$(profile_dir)/$name"
  [[ -d "$dir" ]] || return 0
  rm -rf "$dir"
}

default_onepanel_root_conf() {
  printf '/opt/1panel/apps/openresty/openresty/www/sites/%s/proxy/root.conf' "$1"
}

derive_config() {
  ONEPANEL_ROOT_CONF="${ONEPANEL_ROOT_CONF:-$(default_onepanel_root_conf "$DOMAIN")}"
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
  ADMIN_EMAIL=""
  ADMIN_EMAIL_DERIVED_DEFAULT="true"
  DASHBOARD_IMAGE=""
  SERVER_IMAGE=""
  ONEPANEL_ROOT_CONF=""
}

load_config() {
  capture_config_env_overrides
  local config_file="${NETBIRD_CONFIG_FILE:-}"
  if [[ -z "$config_file" && -n "${NETBIRD_PROFILE:-}" ]]; then
    config_file="$(profile_file "$NETBIRD_PROFILE")"
  fi
  if [[ -z "$config_file" ]]; then
    config_file="$SCRIPT_DIR/netbird-server.env"
  fi
  reset_config_values
  clear_config_env_values
  load_env_file "$config_file"
  restore_config_env_overrides

  INSTALL_DIR="${NETBIRD_INSTALL_DIR:-${INSTALL_DIR:-/root/netbird-docker}}"
  DOMAIN="${NETBIRD_DOMAIN:-${DOMAIN:-netbird.example.com}}"
  DASHBOARD_PORT="${NETBIRD_DASHBOARD_PORT:-${DASHBOARD_PORT:-18084}}"
  SERVER_PORT="${NETBIRD_SERVER_PORT:-${SERVER_PORT:-18085}}"
  STUN_PORT="${NETBIRD_STUN_PORT:-${STUN_PORT:-13478}}"
  BIND_ADDRESS="${NETBIRD_BIND_ADDRESS:-${BIND_ADDRESS:-127.0.0.1}}"
  PUBLIC_SCHEME="${NETBIRD_PUBLIC_SCHEME:-${PUBLIC_SCHEME:-http}}"
  PUBLIC_PORT="${NETBIRD_PUBLIC_PORT:-${PUBLIC_PORT:-$(default_public_port "$PUBLIC_SCHEME")}}"
  normalize_domain_public_parts
  if [[ ${NETBIRD_ADMIN_EMAIL+x} ]]; then
    ADMIN_EMAIL="${NETBIRD_ADMIN_EMAIL:-${ADMIN_EMAIL:-admin@${DOMAIN}}}"
    ADMIN_EMAIL_DERIVED_DEFAULT="false"
  else
    ADMIN_EMAIL="admin@${DOMAIN}"
    ADMIN_EMAIL_DERIVED_DEFAULT="true"
  fi
  DASHBOARD_IMAGE="${NETBIRD_DASHBOARD_IMAGE:-${DASHBOARD_IMAGE:-netbirdio/dashboard:latest}}"
  SERVER_IMAGE="${NETBIRD_SERVER_IMAGE:-${SERVER_IMAGE:-netbirdio/netbird-server:latest}}"
  ONEPANEL_ROOT_CONF="${NETBIRD_1PANEL_ROOT_CONF:-${ONEPANEL_ROOT_CONF:-}}"
  derive_config
}

reload_config_after_cli() {
  normalize_domain_public_parts
  if [[ "${ADMIN_EMAIL_DERIVED_DEFAULT:-false}" == "true" ]]; then
    ADMIN_EMAIL="admin@${DOMAIN}"
  fi
  derive_config
}
