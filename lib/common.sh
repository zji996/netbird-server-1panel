info() { printf '[INFO] %s\n' "$*"; }
warn() { printf '[WARN] %s\n' "$*" >&2; }
die() { printf '[ERROR] %s\n' "$*" >&2; exit 1; }

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
