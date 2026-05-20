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
  [[ -t 0 && "$NONINTERACTIVE" != "true" ]]
}

progress_step() {
  local current="$1"
  local total="$2"
  local label="$3"
  info "$(tf progress_step "$current" "$total" "$label")"
}

tui_menu() {
  local title="$1"; shift
  has_tui || return 1
  local tags=() labels=()
  while [[ $# -gt 0 ]]; do
    tags+=("$1")
    labels+=("${2:-}")
    shift 2
  done
  ((${#tags[@]} > 0)) || return 1

  local i answer default=1
  while true; do
    printf '\n== %s ==\n' "$title" >&2
    for i in "${!tags[@]}"; do
      printf '  %d) %s  %s\n' "$((i + 1))" "${tags[$i]}" "${labels[$i]}" >&2
    done
    printf '%s' "$(tf tui_choice_prompt "$default")" >&2
    IFS= read -r answer || return 1
    answer="${answer:-$default}"
    if [[ "$answer" =~ ^[0-9]+$ ]] && ((answer >= 1 && answer <= ${#tags[@]})); then
      printf '%s\n' "${tags[$((answer - 1))]}"
      return 0
    fi
    warn "$(tf tui_invalid_choice "1-${#tags[@]}")"
  done
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
  has_tui || return 1
  local answer hint
  if [[ "$default" == "yes" ]]; then
    hint="Y/n"
  else
    hint="y/N"
  fi
  while true; do
    printf '\n%s [%s] ' "$message" "$hint" >&2
    IFS= read -r answer || return 1
    answer="${answer:-$default}"
    case "$answer" in
      y|Y|yes|YES) printf 'yes'; return 0 ;;
      n|N|no|NO) printf 'no'; return 0 ;;
      *) warn "$(msg tui_invalid_yesno)" ;;
    esac
  done
}

tui_input() {
  local prompt="$1"
  local default="$2"
  if [[ "$NONINTERACTIVE" == "true" ]]; then
    printf '%s\n' "$default"
    return 0
  fi
  has_tui || return 1
  printf '%s [%s]\n> ' "$prompt" "$default" >&2
  IFS= read -r answer || return 1
  printf '%s\n' "${answer:-$default}"
}

tui_form() {
  local title="$1"
  local message="$2"
  shift 2
  has_tui || return 1
  printf '\n== %s ==\n%s\n\n' "$title" "$message" >&2
  local answers=() label default value
  while [[ $# -gt 0 ]]; do
    label="$1"
    default="$4"
    value="$(tui_input "$label" "$default")" || return 1
    answers+=("$value")
    shift 8
  done
  printf '%s\n' "${answers[@]}"
}

tui_checklist() {
  local message="$1"; shift
  has_tui || return 1
  printf '\n%s\n' "$message" >&2
  local selected=() tag label status default choice
  while [[ $# -gt 0 ]]; do
    tag="$1"
    label="$2"
    status="${3:-OFF}"
    default="no"
    [[ "$status" == "ON" ]] && default="yes"
    choice="$(tui_yesno_choice "$tag  $label" "$default")" || return 1
    [[ "$choice" == "yes" ]] && selected+=("$tag")
    shift 3
  done
  printf '%s\n' "${selected[@]}"
}

tui_radiolist() {
  local message="$1"; shift
  has_tui || return 1
  local tags=() labels=() default=1 index=1
  while [[ $# -gt 0 ]]; do
    tags+=("$1")
    labels+=("$2")
    [[ "${3:-OFF}" == "ON" ]] && default="$index"
    index=$((index + 1))
    shift 3
  done
  ((${#tags[@]} > 0)) || return 1

  local i answer
  while true; do
    printf '\n%s\n' "$message" >&2
    for i in "${!tags[@]}"; do
      printf '  %d) %s  %s\n' "$((i + 1))" "${tags[$i]}" "${labels[$i]}" >&2
    done
    printf '%s' "$(tf tui_choice_prompt "$default")" >&2
    IFS= read -r answer || return 1
    answer="${answer:-$default}"
    if [[ "$answer" =~ ^[0-9]+$ ]] && ((answer >= 1 && answer <= ${#tags[@]})); then
      printf '%s\n' "${tags[$((answer - 1))]}"
      return 0
    fi
    warn "$(tf tui_invalid_choice "1-${#tags[@]}")"
  done
}

tui_msgbox() {
  local message="$1"
  if [[ "$NONINTERACTIVE" == "true" ]]; then
    info "$message"
    return 0
  fi
  printf '\n%s\n' "$message" >&2
  if has_tui; then
    read -r -p "$(msg press_enter)" _
  fi
}

tui_textbox() {
  local file="$1"
  local title="${2:-$APP_NAME}"
  printf '\n== %s ==\n' "$title" >&2
  cat "$file" >&2
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
