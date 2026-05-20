WIZARD_PROFILE_MODE=""

save_profile_env() {
  local profile="${ACTIVE_PROFILE:-$(derive_profile_name "$DOMAIN")}"
  profile="$(sanitize_profile_name "$profile")"
  ACTIVE_PROFILE="$profile"
  local file
  if [[ -n "${NETBIRD_CONFIG_FILE:-}" ]]; then
    file="$NETBIRD_CONFIG_FILE"
  else
    file="$(profile_file "$profile")"
  fi
  cat > "$TMP_DIR/netbird-server.env" <<EOF
NETBIRD_PROFILE=${profile}
NETBIRD_DOMAIN=${DOMAIN}
NETBIRD_INSTALL_DIR=${INSTALL_DIR}
NETBIRD_DASHBOARD_PORT=${DASHBOARD_PORT}
NETBIRD_SERVER_PORT=${SERVER_PORT}
NETBIRD_STUN_PORT=${STUN_PORT}
NETBIRD_BIND_ADDRESS=${BIND_ADDRESS}
NETBIRD_PUBLIC_SCHEME=${PUBLIC_SCHEME}
NETBIRD_PUBLIC_PORT=${PUBLIC_PORT}
NETBIRD_ADMIN_EMAIL=${ADMIN_EMAIL}
NETBIRD_DASHBOARD_IMAGE=${DASHBOARD_IMAGE}
NETBIRD_SERVER_IMAGE=${SERVER_IMAGE}
NETBIRD_1PANEL_ROOT_CONF=${ONEPANEL_ROOT_CONF}
EOF
  write_file "$file" "$TMP_DIR/netbird-server.env"
  info "$(tf profile_saved "$profile")"
}

# Keep for backwards compatibility with any external callers.
save_env_file() { save_profile_env "$@"; }

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

profile_summary_text() {
  local profile_label="${ACTIVE_PROFILE:-$(derive_profile_name "$DOMAIN")}"
  local onepanel="$ONEPANEL_ROOT_CONF"
  [[ -z "$onepanel" ]] && onepanel="(auto)"
  printf '%-18s %s\n' "$(msg summary_field_profile):" "$profile_label"
  printf '%-18s %s\n' "$(msg summary_field_domain):" "$DOMAIN"
  printf '%-18s %s\n' "$(msg summary_field_public):" "$(public_origin)"
  printf '%-18s %s\n' "$(msg summary_field_admin):" "$ADMIN_EMAIL"
  printf '%-18s %s\n' "$(msg summary_field_install):" "$INSTALL_DIR"
  printf '%-18s %s\n' "$(msg summary_field_dashboard):" "${BIND_ADDRESS}:${DASHBOARD_PORT}"
  printf '%-18s %s\n' "$(msg summary_field_server):" "${BIND_ADDRESS}:${SERVER_PORT}"
  printf '%-18s %s\n' "$(msg summary_field_stun):" "$STUN_PORT"
  printf '%-18s %s\n' "$(msg summary_field_1panel):" "$onepanel"
}

profile_summary_with_notes() {
  profile_summary_text
  if [[ "$PUBLIC_SCHEME" == "https" ]]; then
    printf '%-18s %s\n' "$(msg summary_field_ports):" "$(port_note)"
  else
    printf '%-18s %s\n' "$(msg summary_field_scheme_warning):" "$(msg wizard_http_warning)"
  fi
}

wiz_pick_profile() {
  local profiles=()
  mapfile -t profiles < <(list_profiles)

  if [[ ${#profiles[@]} -eq 0 ]]; then
    WIZARD_PROFILE_MODE="new"
    ACTIVE_PROFILE=""
    NETBIRD_PROFILE=""
    NETBIRD_CONFIG_FILE=""
    reset_config_values
    load_config
    return 0
  fi

  local args=()
  local p
  for p in "${profiles[@]}"; do
    args+=("$p" "$(profile_one_line "$p")")
  done
  args+=("__new__" "$(msg profile_new)")

  local choice
  choice="$(tui_menu "$(msg profile_prompt)" "${args[@]}")" || return 1
  if [[ -z "$choice" || "$choice" == "__new__" ]]; then
    WIZARD_PROFILE_MODE="new"
    ACTIVE_PROFILE=""
    NETBIRD_PROFILE=""
    NETBIRD_CONFIG_FILE=""
    reset_config_values
    load_config
    return 0
  fi

  WIZARD_PROFILE_MODE="existing"
  ACTIVE_PROFILE="$choice"
  NETBIRD_PROFILE="$choice"
  load_config
  info "$(tf profile_loaded "$choice")"
  return 0
}

wiz_review_existing() {
  local summary
  summary="$(profile_summary_with_notes)"
  local choice
  choice="$(tui_radiolist "$(tf review_msg "$summary")" \
    deploy "$(msg review_deploy)" ON \
    edit "$(msg review_edit)" OFF \
    delete "$(msg review_delete)" OFF \
    cancel "$(msg review_cancel)" OFF)" || { printf 'cancel'; return 0; }
  printf '%s' "${choice:-cancel}"
}

wiz_essentials() {
  while true; do
    local previous_domain="$DOMAIN"
    local previous_admin_email="$ADMIN_EMAIL"
    local values message
    message="$(printf '%s\n\n%s' "$(msg wizard_essentials_msg)" "$(msg form_nav_hint)")"
    values="$(tui_form "$(msg wizard_essentials_title)" "$message" \
      "$(msg prompt_domain)" 1 1 "$DOMAIN" 1 32 48 0 \
      "$(msg prompt_public_scheme)" 2 1 "$PUBLIC_SCHEME" 2 32 8 0 \
      "$(msg prompt_install_dir)" 3 1 "$INSTALL_DIR" 3 32 48 0)" || return 1

    local fields
    mapfile -t fields <<< "$values"
    DOMAIN="${fields[0]:-$DOMAIN}"
    PUBLIC_SCHEME="${fields[1]:-$PUBLIC_SCHEME}"
    INSTALL_DIR="${fields[2]:-$INSTALL_DIR}"

    if [[ "${ADMIN_EMAIL_DERIVED_DEFAULT:-false}" == "true" || "$previous_admin_email" == "admin@${previous_domain}" ]]; then
      ADMIN_EMAIL="admin@${DOMAIN}"
      ADMIN_EMAIL_DERIVED_DEFAULT="true"
    fi

    local previous_default current_default
    previous_default="$(default_onepanel_root_conf "$previous_domain")"
    current_default="$(default_onepanel_root_conf "$DOMAIN")"
    if [[ -z "$ONEPANEL_ROOT_CONF" || "$ONEPANEL_ROOT_CONF" == "$previous_default" ]]; then
      ONEPANEL_ROOT_CONF="$current_default"
    fi

    if [[ "$PUBLIC_SCHEME" == "https" ]]; then
      PUBLIC_PORT="${PUBLIC_PORT:-443}"
      [[ "$PUBLIC_PORT" == "80" ]] && PUBLIC_PORT="443"
    elif [[ "$PUBLIC_SCHEME" == "http" ]]; then
      [[ "$PUBLIC_PORT" == "443" ]] && PUBLIC_PORT="80"
    fi
    derive_config

    local err
    if err="$(check_settings)"; then
      return 0
    fi
    tui_msgbox "$(tf wizard_validation_failed "$err")"
  done
}

wiz_advanced_question() {
  tui_yesno_choice "$(msg wizard_advanced_question)" no
}

wiz_advanced() {
  local profile_default="${ACTIVE_PROFILE:-$(derive_profile_name "$DOMAIN")}"
  while true; do
    local values message
    message="$(printf '%s\n\n%s' "$(msg wizard_advanced_msg)" "$(msg form_nav_hint)")"
    values="$(tui_form "$(msg wizard_advanced_title)" "$message" \
      "$(msg prompt_dashboard_port)" 1 1 "$DASHBOARD_PORT" 1 36 8 0 \
      "$(msg prompt_server_port)" 2 1 "$SERVER_PORT" 2 36 8 0 \
      "$(msg prompt_stun_port)" 3 1 "$STUN_PORT" 3 36 8 0 \
      "$(msg prompt_bind_address)" 4 1 "$BIND_ADDRESS" 4 36 16 0 \
      "$(msg prompt_public_port)" 5 1 "$PUBLIC_PORT" 5 36 8 0 \
      "$(msg prompt_admin_email)" 6 1 "$ADMIN_EMAIL" 6 36 48 0 \
      "$(msg prompt_1panel_path)" 7 1 "$ONEPANEL_ROOT_CONF" 7 36 48 0 \
      "$(msg wizard_advanced_profile_label)" 8 1 "$profile_default" 8 36 48 0)" || return 1

    local fields
    mapfile -t fields <<< "$values"
    DASHBOARD_PORT="${fields[0]:-$DASHBOARD_PORT}"
    SERVER_PORT="${fields[1]:-$SERVER_PORT}"
    STUN_PORT="${fields[2]:-$STUN_PORT}"
    BIND_ADDRESS="${fields[3]:-$BIND_ADDRESS}"
    PUBLIC_PORT="${fields[4]:-$PUBLIC_PORT}"
    ADMIN_EMAIL="${fields[5]:-$ADMIN_EMAIL}"
    ADMIN_EMAIL_DERIVED_DEFAULT="false"
    ONEPANEL_ROOT_CONF="${fields[6]:-}"
    derive_config

    local new_profile="${fields[7]:-$profile_default}"
    new_profile="$(sanitize_profile_name "$new_profile")"
    [[ -n "$new_profile" ]] && ACTIVE_PROFILE="$new_profile"

    local err
    if err="$(check_settings)"; then
      return 0
    fi
    tui_msgbox "$(tf wizard_validation_failed "$err")"
  done
}

wiz_summary() {
  if [[ -z "$ACTIVE_PROFILE" ]]; then
    ACTIVE_PROFILE="$(derive_profile_name "$DOMAIN")"
  fi
  local summary
  summary="$(profile_summary_with_notes)"
  local choice
  choice="$(tui_radiolist "${summary}

$(msg wizard_summary_msg)" \
    full "$(msg wizard_summary_full)" ON \
    render "$(msg wizard_summary_render)" OFF \
    save "$(msg wizard_summary_save)" OFF \
    back "$(msg wizard_summary_back)" OFF \
    cancel "$(msg wizard_summary_cancel)" OFF)" || { printf 'cancel'; return 0; }
  printf '%s' "${choice:-cancel}"
}

show_openresty_preview() {
  render_openresty_root_conf > "$TMP_DIR/root-preview.conf"
  tui_textbox "$TMP_DIR/root-preview.conf" "$(msg menu_1panel_preview)"
}

wiz_execute() {
  local action="$1"
  local err
  if ! err="$(check_settings)"; then
    tui_msgbox "$(tf wizard_validation_failed "$err")"
    return 1
  fi
  info "$(msg wizard_executing)"
  case "$action" in
    full)
      progress_step 1 7 "$(msg progress_save_profile)"
      save_profile_env
      progress_step 2 7 "$(msg progress_render_files)"
      render_files
      progress_step 3 7 "$(msg progress_apply_1panel)"
      apply_1panel_conf
      progress_step 4 7 "$(msg progress_firewall_short)"
      open_firewall_ports || true
      progress_step 5 7 "$(msg progress_start_services_short)"
      start_services
      progress_step 6 7 "$(msg progress_setup_admin)"
      setup_initial_admin || true
      progress_step 7 7 "$(msg progress_status_checks)"
      show_status || true
      ;;
    render)
      progress_step 1 2 "$(msg progress_save_profile)"
      save_profile_env
      progress_step 2 2 "$(msg progress_render_files)"
      render_files
      ;;
    save)
      progress_step 1 1 "$(msg progress_save_profile)"
      save_profile_env
      ;;
  esac
  info "$(msg wizard_done)"
  info "$(msg wizard_next_hint)"
}

wiz_delete_current() {
  [[ -z "$ACTIVE_PROFILE" ]] && return 0
  if tui_yesno "$(tf review_delete_confirm "$ACTIVE_PROFILE")"; then
    local deleted_profile="$ACTIVE_PROFILE"
    delete_profile "$ACTIVE_PROFILE"
    info "$(tf profile_deleted "$deleted_profile")"
    ACTIVE_PROFILE=""
    NETBIRD_PROFILE=""
    reset_config_values
    load_config
    return 0
  fi
  return 1
}

setup_wizard() {
  if ! has_tui; then
    warn "$(msg wizard_interactive_required)"
    return 1
  fi

  local state="pick"
  while true; do
    case "$state" in
      pick)
        if ! wiz_pick_profile; then
          return 0
        fi
        if [[ "$WIZARD_PROFILE_MODE" == "existing" ]]; then
          state="review"
        else
          state="essentials"
        fi
        ;;
      review)
        local choice
        choice="$(wiz_review_existing)"
        case "$choice" in
          deploy) wiz_execute full && return 0; state="essentials" ;;
          edit) state="essentials" ;;
          delete) wiz_delete_current || true; state="pick" ;;
          cancel|*) return 0 ;;
        esac
        ;;
      essentials)
        if wiz_essentials; then
          state="advanced_question"
        else
          if [[ "$WIZARD_PROFILE_MODE" == "existing" ]]; then
            state="review"
          else
            return 0
          fi
        fi
        ;;
      advanced_question)
        local answer
        answer="$(wiz_advanced_question)" || answer="cancel"
        case "$answer" in
          yes) state="advanced" ;;
          no) state="summary" ;;
          cancel|*) state="essentials" ;;
        esac
        ;;
      advanced)
        if wiz_advanced; then
          state="summary"
        else
          state="essentials"
        fi
        ;;
      summary)
        local action
        action="$(wiz_summary)"
        case "$action" in
          full|render|save) wiz_execute "$action" && return 0; state="essentials" ;;
          back) state="essentials" ;;
          cancel|*) return 0 ;;
        esac
        ;;
    esac
  done
}
