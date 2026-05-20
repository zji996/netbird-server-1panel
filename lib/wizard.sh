save_env_file() {
  local file="${NETBIRD_CONFIG_FILE:-$SCRIPT_DIR/netbird-server.env}"
  cat > "$TMP_DIR/netbird-server.env" <<EOF
NETBIRD_DOMAIN=${DOMAIN}
NETBIRD_INSTALL_DIR=${INSTALL_DIR}
NETBIRD_DASHBOARD_PORT=${DASHBOARD_PORT}
NETBIRD_SERVER_PORT=${SERVER_PORT}
NETBIRD_STUN_PORT=${STUN_PORT}
NETBIRD_BIND_ADDRESS=${BIND_ADDRESS}
NETBIRD_PUBLIC_SCHEME=${PUBLIC_SCHEME}
NETBIRD_PUBLIC_PORT=${PUBLIC_PORT}
NETBIRD_DASHBOARD_IMAGE=${DASHBOARD_IMAGE}
NETBIRD_SERVER_IMAGE=${SERVER_IMAGE}
NETBIRD_1PANEL_ROOT_CONF=${ONEPANEL_ROOT_CONF}
EOF
  write_file "$file" "$TMP_DIR/netbird-server.env"
  info "$(tf save_env_done "$file")"
}

port_note() {
  local notes=()
  if port_is_free "0.0.0.0" 80; then
    notes+=("80 OK")
  else
    notes+=("80 busy")
  fi
  if port_is_free "0.0.0.0" 443; then
    notes+=("443 OK")
  else
    notes+=("443 busy")
  fi
  (IFS=", "; echo "${notes[*]}")
}

wizard_form() {
  local values
  values="$(tui_form "$(msg wizard_title)" "$(msg wizard_form_msg)" \
    "$(msg prompt_domain)" 1 1 "$DOMAIN" 1 32 42 0 \
    "$(msg prompt_install_dir)" 2 1 "$INSTALL_DIR" 2 32 42 0 \
    "$(msg prompt_public_scheme)" 3 1 "$PUBLIC_SCHEME" 3 32 8 0 \
    "$(msg prompt_public_port)" 4 1 "$PUBLIC_PORT" 4 32 8 0 \
    "$(msg prompt_bind_address)" 5 1 "$BIND_ADDRESS" 5 32 16 0 \
    "$(msg prompt_dashboard_port)" 6 1 "$DASHBOARD_PORT" 6 32 8 0 \
    "$(msg prompt_server_port)" 7 1 "$SERVER_PORT" 7 32 8 0 \
    "$(msg prompt_stun_port)" 8 1 "$STUN_PORT" 8 32 8 0 \
    "$(msg prompt_1panel_path)" 9 1 "$ONEPANEL_ROOT_CONF" 9 32 42 0)" || return 1

  mapfile -t fields <<< "$values"
  DOMAIN="${fields[0]}"
  INSTALL_DIR="${fields[1]}"
  PUBLIC_SCHEME="${fields[2]}"
  PUBLIC_PORT="${fields[3]}"
  BIND_ADDRESS="${fields[4]}"
  DASHBOARD_PORT="${fields[5]}"
  SERVER_PORT="${fields[6]}"
  STUN_PORT="${fields[7]}"
  ONEPANEL_ROOT_CONF="${fields[8]}"
  validate_settings
}

wizard_actions() {
  tui_checklist "$(msg wizard_actions_msg)" \
    save "$(msg wizard_save_env)" ON \
    generate "$(msg wizard_generate)" ON \
    preview "$(msg wizard_preview)" ON \
    apply1panel "$(msg wizard_apply_1panel)" OFF \
    start "$(msg wizard_start)" OFF
}

show_openresty_preview() {
  render_openresty_root_conf > "$TMP_DIR/root-preview.conf"
  tui_textbox "$TMP_DIR/root-preview.conf" "$(msg menu_1panel_preview)"
}

setup_wizard() {
  if ! has_tui; then
    install_flow
    return 0
  fi

  wizard_form || return 0

  local note
  note="$(port_note)"
  warn "$(tf wizard_ports_warning "$note")"
  if [[ "$PUBLIC_SCHEME" == "http" ]]; then
    warn "$(msg wizard_http_warning)"
    tui_yesno "$(msg wizard_http_warning)" || return 0
  fi

  local selected
  selected="$(wizard_actions)" || return 0
  [[ "$selected" == *save* ]] && save_env_file
  [[ "$selected" == *generate* ]] && render_files
  [[ "$selected" == *preview* ]] && show_openresty_preview
  [[ "$selected" == *apply1panel* ]] && apply_1panel_conf
  [[ "$selected" == *start* ]] && start_services

  info "$(msg wizard_done)"
}
