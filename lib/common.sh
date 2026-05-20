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
  command -v "$1" >/dev/null 2>&1 || die "$(tf err_missing_cmd "$1")"
}

has_tui() {
  [[ -t 0 && "$NONINTERACTIVE" != "true" ]] && { command -v whiptail >/dev/null 2>&1 || command -v dialog >/dev/null 2>&1 || command -v fzf >/dev/null 2>&1; }
}

has_form_tui() {
  [[ -t 0 && "$NONINTERACTIVE" != "true" ]] && command -v dialog >/dev/null 2>&1
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
  local default="${2:-yes}"
  local choice
  choice="$(tui_yesno_choice "$message" "$default")" || return 1
  [[ "$choice" == "yes" ]]
}

tui_yesno_choice() {
  local message="$1"
  local default="${2:-yes}"
  local rc
  if [[ "$NONINTERACTIVE" == "true" ]]; then
    if [[ "$default" == "yes" ]]; then
      printf 'yes'
    else
      printf 'no'
    fi
    return 0
  fi
  if command -v whiptail >/dev/null 2>&1; then
    local args=(--title "$APP_NAME")
    [[ "$default" == "no" ]] && args+=(--defaultno)
    whiptail "${args[@]}" --yesno "$message" 12 72
    rc=$?
  elif command -v dialog >/dev/null 2>&1; then
    local args=(--title "$APP_NAME")
    [[ "$default" == "no" ]] && args+=(--defaultno)
    dialog "${args[@]}" --yesno "$message" 12 72
    rc=$?
  else
    read -r -p "$message [y/N] " answer
    if [[ "$answer" =~ ^[Yy]$ ]]; then
      printf 'yes'
    else
      printf 'no'
    fi
    return 0
  fi
  case "$rc" in
    0) printf 'yes' ;;
    1) printf 'no' ;;
    *) printf 'cancel'; return 1 ;;
  esac
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

tui_form() {
  local title="$1"
  local message="$2"
  shift 2
  if command -v dialog >/dev/null 2>&1; then
    dialog --title "$APP_NAME" --form "$message" 24 92 14 "$@" 3>&1 1>&2 2>&3
  else
    return 1
  fi
}

tui_checklist() {
  local message="$1"; shift
  if command -v whiptail >/dev/null 2>&1; then
    whiptail --title "$APP_NAME" --checklist "$message" 18 82 8 "$@" 3>&1 1>&2 2>&3
  elif command -v dialog >/dev/null 2>&1; then
    dialog --title "$APP_NAME" --checklist "$message" 18 82 8 "$@" 3>&1 1>&2 2>&3
  else
    return 1
  fi
}

tui_radiolist() {
  local message="$1"; shift
  if command -v whiptail >/dev/null 2>&1; then
    whiptail --title "$APP_NAME" --radiolist "$message" 22 84 10 "$@" 3>&1 1>&2 2>&3
  elif command -v dialog >/dev/null 2>&1; then
    dialog --title "$APP_NAME" --radiolist "$message" 22 84 10 "$@" 3>&1 1>&2 2>&3
  else
    return 1
  fi
}

tui_msgbox() {
  local message="$1"
  if [[ "$NONINTERACTIVE" == "true" ]]; then
    info "$message"
    return 0
  fi
  if command -v whiptail >/dev/null 2>&1; then
    whiptail --title "$APP_NAME" --msgbox "$message" 14 76
  elif command -v dialog >/dev/null 2>&1; then
    dialog --title "$APP_NAME" --msgbox "$message" 14 76
  else
    printf '%s\n' "$message"
  fi
}

tui_textbox() {
  local file="$1"
  local title="${2:-$APP_NAME}"
  if command -v whiptail >/dev/null 2>&1; then
    whiptail --title "$title" --textbox "$file" 28 100
  elif command -v dialog >/dev/null 2>&1; then
    dialog --title "$title" --textbox "$file" 28 100
  else
    ${PAGER:-less} "$file"
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
  cmd="$(compose_cmd)" || die "$(msg err_compose_required)"
  (cd "$INSTALL_DIR" && $cmd "$@")
}

random_secret() {
  openssl rand -base64 32 | tr -d '\n'
}

random_password() {
  openssl rand -base64 24 | tr -d '\n' | tr '/+' '_-'
}

valid_port() {
  [[ "$1" =~ ^[0-9]+$ ]] && (( "$1" >= 1 && "$1" <= 65535 ))
}

valid_email() {
  [[ "$1" =~ ^[^[:space:]@]+@[^[:space:]@]+\.[^[:space:]@]+$ ]]
}

check_settings() {
  local errs=()
  [[ -n "$DOMAIN" ]] || errs+=("$(msg err_empty_domain)")
  valid_port "$DASHBOARD_PORT" || errs+=("$(tf err_dashboard_port "$DASHBOARD_PORT")")
  valid_port "$SERVER_PORT" || errs+=("$(tf err_server_port "$SERVER_PORT")")
  valid_port "$STUN_PORT" || errs+=("$(tf err_stun_port "$STUN_PORT")")
  valid_port "$PUBLIC_PORT" || errs+=("$(tf err_public_port "$PUBLIC_PORT")")
  [[ "$DASHBOARD_PORT" != "$SERVER_PORT" ]] || errs+=("$(msg err_same_ports)")
  [[ "$PUBLIC_SCHEME" == "http" || "$PUBLIC_SCHEME" == "https" ]] || errs+=("$(tf err_public_scheme "$PUBLIC_SCHEME")")
  valid_email "$ADMIN_EMAIL" || errs+=("$(tf err_admin_email "$ADMIN_EMAIL")")
  if (( ${#errs[@]} > 0 )); then
    printf '%s\n' "${errs[@]}"
    return 1
  fi
  return 0
}

validate_settings() {
  local err
  if ! err="$(check_settings)"; then
    die "$err"
  fi
}

prompt_settings() {
  DOMAIN="$(tui_input "$(msg prompt_domain)" "$DOMAIN")"
  INSTALL_DIR="$(tui_input "$(msg prompt_install_dir)" "$INSTALL_DIR")"
  DASHBOARD_PORT="$(tui_input "$(msg prompt_dashboard_port)" "$DASHBOARD_PORT")"
  SERVER_PORT="$(tui_input "$(msg prompt_server_port)" "$SERVER_PORT")"
  STUN_PORT="$(tui_input "$(msg prompt_stun_port)" "$STUN_PORT")"
  BIND_ADDRESS="$(tui_input "$(msg prompt_bind_address)" "$BIND_ADDRESS")"
  PUBLIC_SCHEME="$(tui_input "$(msg prompt_public_scheme)" "$PUBLIC_SCHEME")"
  PUBLIC_PORT="$(tui_input "$(msg prompt_public_port)" "$PUBLIC_PORT")"
  ADMIN_EMAIL="$(tui_input "$(msg prompt_admin_email)" "$ADMIN_EMAIL")"
  ONEPANEL_ROOT_CONF="$(tui_input "$(msg prompt_1panel_path)" "$ONEPANEL_ROOT_CONF")"
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

admin_credentials_file() {
  printf '%s/admin-credentials.txt' "$INSTALL_DIR"
}

existing_admin_password_or_new() {
  local file
  file="$(admin_credentials_file)"
  if [[ -f "$file" ]]; then
    local existing_password
    existing_password="$(awk -F': ' '$1 == "Password" {print $2; exit}' "$file" 2>/dev/null || true)"
    if [[ -n "$existing_password" ]]; then
      printf '%s' "$existing_password"
      return 0
    fi
  fi
  random_password
}

admin_password_from_credentials() {
  local file
  file="$(admin_credentials_file)"
  [[ -f "$file" ]] || return 0
  awk -F': ' '$1 == "Password" {print $2; exit}' "$file" 2>/dev/null || true
}

write_admin_credentials() {
  local password="$1"
  local file
  file="$(admin_credentials_file)"
  local existed="false"
  [[ -f "$file" ]] && existed="true"

  local old_umask
  old_umask="$(umask)"
  umask 077
  cat > "$TMP_DIR/admin-credentials.txt" <<EOF
NetBird admin account

URL: ${PUBLIC_SCHEME}://${DOMAIN}
Email: ${ADMIN_EMAIL}
Password: ${password}
EOF
  umask "$old_umask"
  write_file "$file" "$TMP_DIR/admin-credentials.txt"
  chmod 600 "$file" 2>/dev/null || true
  if [[ "$existed" == "true" ]]; then
    info "$(tf admin_credentials_reused "$file")"
  else
    info "$(tf admin_credentials_created "$file" "$ADMIN_EMAIL")"
  fi
}

backup_file_if_exists() {
  local file="$1"
  [[ -e "$file" ]] || return 0
  local backup="${file}.bak.$(date +%Y%m%d%H%M%S)"
  info "$(tf backup_file "$file" "$backup")"
  cp -a "$file" "$backup"
}

write_file() {
  local target="$1"
  local tmp="$2"
  if [[ "$DRY_RUN" == "true" ]]; then
    info "$(tf dry_run_write "$target")"
    cat "$tmp"
    return 0
  fi
  mkdir -p "$(dirname "$target")"
  backup_file_if_exists "$target"
  cp "$tmp" "$target"
}
