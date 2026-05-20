self_test() {
  require_cmd bash
  require_cmd python3
  require_cmd openssl
  local sandbox="$TMP_DIR/self-test-install"
  rm -rf "$sandbox"
  mkdir -p "$sandbox"
  cat > "$sandbox/netbird-server.env" <<'EOF'
NETBIRD_DOMAIN=test.example.invalid
NETBIRD_INSTALL_DIR=/tmp/netbird-server-tui/self-test-install
NETBIRD_DASHBOARD_PORT=28084
NETBIRD_SERVER_PORT=28085
NETBIRD_STUN_PORT=23478
NETBIRD_BIND_ADDRESS=127.0.0.1
NETBIRD_PUBLIC_SCHEME=https
NETBIRD_PUBLIC_PORT=443
NETBIRD_ADMIN_EMAIL=admin@test.example.invalid
NETBIRD_1PANEL_ROOT_CONF=/tmp/netbird-server-tui/self-test-install/root.conf
EOF
  info "$(tf self_test_start "$sandbox")"
  bash "$SCRIPT_PATH" --noninteractive --config "$sandbox/netbird-server.env" render

  bash -n "$SCRIPT_PATH"
  python3 - "$sandbox" <<'PY'
import pathlib
import sys
root = pathlib.Path(sys.argv[1])
required = ["docker-compose.yml", "config/config.yaml", "dashboard.env", "admin-credentials.txt"]
missing = [name for name in required if not (root / name).exists()]
if missing:
    raise SystemExit(f"missing files: {missing}")
compose = (root / "docker-compose.yml").read_text()
config = (root / "config/config.yaml").read_text()
env = (root / "dashboard.env").read_text()
checks = [
    ("127.0.0.1:28084:80", compose),
    ("127.0.0.1:28085:80", compose),
    ("23478:23478/udp", compose),
    ("./config:/etc/netbird:ro", compose),
    ('exposedAddress: "https://test.example.invalid:443"', config),
    ("- 23478", config),
    ("AUTH_AUTHORITY=https://test.example.invalid/oauth2", env),
]
for needle, haystack in checks:
    if needle not in haystack:
        raise SystemExit(f"missing expected content: {needle}")
creds = (root / "admin-credentials.txt").read_text()
if "Email: admin@test.example.invalid" not in creds or "Password: " not in creds:
    raise SystemExit("admin credentials file is incomplete")
password_line = next(line for line in creds.splitlines() if line.startswith("Password: "))
password = password_line.split(": ", 1)[1]
if password in config or "owner:" in config or "password:" in config:
    raise SystemExit("admin credential material leaked into config.yaml")
mode = (root / "admin-credentials.txt").stat().st_mode & 0o777
if mode & 0o077:
    raise SystemExit(f"admin credentials file is too open: {oct(mode)}")
print("render assertions passed")
PY
  local first_admin_password
  first_admin_password="$(awk -F': ' '$1 == "Password" {print $2; exit}' "$sandbox/admin-credentials.txt")"
  bash "$SCRIPT_PATH" --noninteractive --config "$sandbox/netbird-server.env" render
  [[ "$first_admin_password" == "$(awk -F': ' '$1 == "Password" {print $2; exit}' "$sandbox/admin-credentials.txt")" ]]
  rm -rf "$sandbox/config/config.yaml"
  mkdir -p "$sandbox/config/config.yaml"
  bash "$SCRIPT_PATH" --noninteractive --config "$sandbox/netbird-server.env" render
  [[ -f "$sandbox/config/config.yaml" ]]
  bash "$SCRIPT_PATH" --noninteractive --config "$sandbox/netbird-server.env" 1panel-apply
  rg -n "127\\.0\\.0\\.1:28085|127\\.0\\.0\\.1:28084|grpc_pass" "$sandbox/root.conf" >/dev/null

  local profile_sandbox="$TMP_DIR/self-test-profiles"
  rm -rf "$profile_sandbox"
  mkdir -p "$profile_sandbox/first" "$profile_sandbox/second"
  mkdir -p "$profile_sandbox/https-no-port"
  cat > "$profile_sandbox/first/profile.env" <<'EOF'
NETBIRD_DOMAIN=first.example.invalid
NETBIRD_INSTALL_DIR=/tmp/netbird-server-tui/first-install
NETBIRD_DASHBOARD_PORT=30084
NETBIRD_SERVER_PORT=30085
NETBIRD_STUN_PORT=30086
NETBIRD_BIND_ADDRESS=127.0.0.1
NETBIRD_PUBLIC_SCHEME=https
NETBIRD_PUBLIC_PORT=443
NETBIRD_ADMIN_EMAIL=admin@first.example.invalid
NETBIRD_1PANEL_ROOT_CONF=/tmp/netbird-server-tui/first-root.conf
EOF
  cat > "$profile_sandbox/second/profile.env" <<'EOF'
NETBIRD_DOMAIN=second.example.invalid
NETBIRD_INSTALL_DIR=/tmp/netbird-server-tui/second-install
NETBIRD_DASHBOARD_PORT=31084
NETBIRD_SERVER_PORT=31085
NETBIRD_STUN_PORT=31086
NETBIRD_BIND_ADDRESS=127.0.0.1
NETBIRD_PUBLIC_SCHEME=http
NETBIRD_PUBLIC_PORT=80
NETBIRD_ADMIN_EMAIL=admin@second.example.invalid
EOF
  cat > "$profile_sandbox/https-no-port/profile.env" <<'EOF'
NETBIRD_DOMAIN=https-no-port.example.invalid
NETBIRD_INSTALL_DIR=/tmp/netbird-server-tui/https-no-port-install
NETBIRD_DASHBOARD_PORT=32084
NETBIRD_SERVER_PORT=32085
NETBIRD_STUN_PORT=32086
NETBIRD_BIND_ADDRESS=127.0.0.1
NETBIRD_PUBLIC_SCHEME=https
EOF
  NETBIRD_PROFILE_DIR="$profile_sandbox" bash -s -- "$SCRIPT_DIR" <<'EOF'
set -Eeuo pipefail
SCRIPT_DIR="$1"
APP_NAME="NetBird Server TUI"
TMP_DIR="${TMPDIR:-/tmp}/netbird-server-tui"
NONINTERACTIVE="true"
DRY_RUN="false"
source "$SCRIPT_DIR/lib/common.sh"
source "$SCRIPT_DIR/lib/config.sh"
source "$SCRIPT_DIR/lib/i18n.sh"
source "$SCRIPT_DIR/lib/render.sh"
source "$SCRIPT_DIR/lib/actions.sh"
source "$SCRIPT_DIR/lib/wizard.sh"
NETBIRD_PROFILE=first
load_config
[[ "$DOMAIN" == "first.example.invalid" ]]
[[ "$PUBLIC_SCHEME" == "https" ]]
[[ "$ONEPANEL_ROOT_CONF" == "/tmp/netbird-server-tui/first-root.conf" ]]
[[ "$ADMIN_EMAIL" == "admin@first.example.invalid" ]]
NETBIRD_PROFILE=second
load_config
[[ "$DOMAIN" == "second.example.invalid" ]]
[[ "$PUBLIC_SCHEME" == "http" ]]
[[ "$PUBLIC_PORT" == "80" ]]
[[ "$ADMIN_EMAIL" == "admin@second.example.invalid" ]]
[[ "$ONEPANEL_ROOT_CONF" == "/opt/1panel/apps/openresty/openresty/www/sites/second.example.invalid/proxy/root.conf" ]]
[[ "$(profile_one_line second)" == "second.example.invalid" ]]
NETBIRD_PROFILE=https-no-port
load_config
[[ "$PUBLIC_SCHEME" == "https" ]]
[[ "$PUBLIC_PORT" == "443" ]]
NETBIRD_PROFILE=""
NETBIRD_CONFIG_FILE=""
reset_config_values
load_config
[[ "$DOMAIN" == "netbird.example.com" ]]
[[ "$PUBLIC_SCHEME" == "http" ]]
[[ "$PUBLIC_PORT" == "80" ]]
[[ "$ADMIN_EMAIL" == "admin@netbird.example.com" ]]
DOMAIN="cli-domain.example.invalid"
reload_config_after_cli
[[ "$ADMIN_EMAIL" == "admin@cli-domain.example.invalid" ]]
ADMIN_EMAIL="manual-admin@example.invalid"
ADMIN_EMAIL_DERIVED_DEFAULT="false"
DOMAIN="manual-domain.example.invalid"
reload_config_after_cli
[[ "$ADMIN_EMAIL" == "manual-admin@example.invalid" ]]
[[ "$(derive_profile_name "netbird.example.com")" == "netbird-example-com" ]]
delete_profile "../second"
[[ -d "$NETBIRD_PROFILE_DIR/second" ]]
delete_profile "second"
[[ ! -d "$NETBIRD_PROFILE_DIR/second" ]]
NETBIRD_PROFILE_DIR="$NETBIRD_PROFILE_DIR/empty"
mkdir -p "$NETBIRD_PROFILE_DIR"
wiz_pick_profile
[[ "$WIZARD_PROFILE_MODE" == "new" ]]
[[ -z "$ACTIVE_PROFILE" ]]
EOF

  local setup_sandbox="$TMP_DIR/self-test-admin-setup"
  rm -rf "$setup_sandbox"
  mkdir -p "$setup_sandbox"
  NETBIRD_TEST_SETUP_DIR="$setup_sandbox" bash -s -- "$SCRIPT_DIR" <<'EOF'
set -Eeuo pipefail
SCRIPT_DIR="$1"
APP_NAME="NetBird Server TUI"
TMP_DIR="${TMPDIR:-/tmp}/netbird-server-tui"
NONINTERACTIVE="true"
DRY_RUN="false"
INSTALL_DIR="$NETBIRD_TEST_SETUP_DIR"
DOMAIN="setup.example.invalid"
PUBLIC_SCHEME="http"
PUBLIC_PORT="80"
ADMIN_EMAIL="setup-admin@example.invalid"
BIND_ADDRESS="127.0.0.1"
SERVER_PORT="28085"
source "$SCRIPT_DIR/lib/i18n.sh"
source "$SCRIPT_DIR/lib/common.sh"
source "$SCRIPT_DIR/lib/actions.sh"
PUBLIC_SCHEME=http
PUBLIC_PORT=80
STUN_PORT=13478
[[ "$(firewall_tcp_ports_label)" == "80" ]]
PUBLIC_SCHEME=https
PUBLIC_PORT=443
[[ "$(firewall_tcp_ports_label)" == "443, 80" ]]
PUBLIC_PORT=8443
[[ "$(firewall_tcp_ports_label)" == "8443, 80" ]]
cat > "$INSTALL_DIR/admin-credentials.txt" <<'CREDS'
NetBird admin account

URL: http://setup.example.invalid
Email: setup-admin@example.invalid
Password: SetupPass123!
CREDS
curl() {
  case "$*" in
    *"/api/instance"*) printf '{"setup_required":true}'; return 0 ;;
    *"/api/setup"*)
      printf '%s\n' "$*" > "$INSTALL_DIR/curl-args.txt"
      local arg next_is_data="false"
      : > "$INSTALL_DIR/setup-payload.json"
      for arg in "$@"; do
        if [[ "$next_is_data" == "true" ]]; then
          printf '%s' "$arg" > "$INSTALL_DIR/setup-payload.json"
          next_is_data="false"
        elif [[ "$arg" == "-d" ]]; then
          next_is_data="true"
        fi
      done
      printf '200'
      return 0
      ;;
    *) return 1 ;;
  esac
}
setup_initial_admin
python3 - "$INSTALL_DIR/setup-payload.json" <<'PY'
import json
import sys
payload = json.load(open(sys.argv[1], encoding="utf-8"))
assert payload["email"] == "setup-admin@example.invalid"
assert payload["password"] == "SetupPass123!"
assert payload["name"] == "NetBird Admin"
assert payload["create_pat"] is False
PY
EOF

  local uninstall_sandbox="$TMP_DIR/self-test-uninstall"
  rm -rf "$uninstall_sandbox"
  mkdir -p "$uninstall_sandbox/data"
  NETBIRD_TEST_UNINSTALL_DIR="$uninstall_sandbox" bash -s -- "$SCRIPT_DIR" <<'EOF'
set -Eeuo pipefail
SCRIPT_DIR="$1"
APP_NAME="NetBird Server TUI"
TMP_DIR="${TMPDIR:-/tmp}/netbird-server-tui"
NONINTERACTIVE="true"
DRY_RUN="false"
INSTALL_DIR="$NETBIRD_TEST_UNINSTALL_DIR"
ONEPANEL_ROOT_CONF="$INSTALL_DIR/root.conf"
source "$SCRIPT_DIR/lib/i18n.sh"
source "$SCRIPT_DIR/lib/common.sh"
source "$SCRIPT_DIR/lib/actions.sh"
run_compose() {
  printf '%s' "$*" > "$INSTALL_DIR/compose-called.txt"
}
mkdir -p "$INSTALL_DIR/config"
touch "$INSTALL_DIR/docker-compose.yml" "$INSTALL_DIR/config/config.yaml" "$INSTALL_DIR/config.yaml" "$INSTALL_DIR/dashboard.env" "$INSTALL_DIR/admin-credentials.txt" "$INSTALL_DIR/data/state.db" "$ONEPANEL_ROOT_CONF"
touch "$INSTALL_DIR/docker-compose.yml.bak.20260520120000" "$INSTALL_DIR/config.bak.20260520120000" "$INSTALL_DIR/config.yaml.bak.20260520120000" "$INSTALL_DIR/dashboard.env.bak.20260520120000" "$INSTALL_DIR/admin-credentials.txt.bak.20260520120000"
uninstall_installation
[[ -f "$INSTALL_DIR/compose-called.txt" ]]
[[ ! -e "$INSTALL_DIR/docker-compose.yml" ]]
[[ ! -e "$INSTALL_DIR/config" ]]
[[ ! -e "$INSTALL_DIR/config.yaml" ]]
[[ ! -e "$INSTALL_DIR/dashboard.env" ]]
[[ ! -e "$INSTALL_DIR/admin-credentials.txt" ]]
[[ ! -e "$INSTALL_DIR/docker-compose.yml.bak.20260520120000" ]]
[[ ! -e "$INSTALL_DIR/config.bak.20260520120000" ]]
[[ ! -e "$INSTALL_DIR/config.yaml.bak.20260520120000" ]]
[[ ! -e "$INSTALL_DIR/dashboard.env.bak.20260520120000" ]]
[[ ! -e "$INSTALL_DIR/admin-credentials.txt.bak.20260520120000" ]]
[[ ! -d "$INSTALL_DIR/data" ]]
[[ -f "$ONEPANEL_ROOT_CONF" ]]
uninstall_installation
EOF
  info "$(msg self_test_passed)"
}
