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
  bash "$SCRIPT_PATH" --noninteractive --install-dir "$sandbox" --domain test.example.invalid --dashboard-port 28084 --server-port 28085 --stun-port 23478 render

  bash -n "$SCRIPT_PATH"
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
  bash "$SCRIPT_PATH" --noninteractive --install-dir "$sandbox" --domain test.example.invalid --dashboard-port 28084 --server-port 28085 --stun-port 23478 --1panel-root-conf "$sandbox/root.conf" 1panel-apply
  rg -n "127\\.0\\.0\\.1:28085|127\\.0\\.0\\.1:28084|grpc_pass" "$sandbox/root.conf" >/dev/null
  info "Self-test passed"
}
