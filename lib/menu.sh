main_menu() {
  while true; do
    local choice
    choice="$(tui_menu "$(msg menu_title)" \
      wizard "$(msg menu_wizard)" \
      doctor "$(msg menu_doctor)" \
      status "$(msg menu_status)" \
      advanced "$(msg menu_advanced)" \
      quit "$(msg menu_quit)")" || exit 0
    case "$choice" in
      wizard) setup_wizard ;;
      doctor) doctor_check ;;
      status) show_status ;;
      advanced) advanced_menu ;;
      quit) exit 0 ;;
    esac
    if [[ -t 0 ]]; then
      read -r -p "$(msg press_enter)" _
    fi
  done
}

advanced_menu() {
  while true; do
    local choice
    choice="$(tui_menu "$(msg advanced_title)" \
      install "$(msg menu_install)" \
      render "$(msg menu_render)" \
      start "$(msg menu_start)" \
      stop "$(msg menu_stop)" \
      restart "$(msg menu_restart)" \
      logs "$(msg menu_logs)" \
      onepanel-preview "$(msg menu_1panel_preview)" \
      onepanel-apply "$(msg menu_1panel_apply)" \
      onepanel-check "$(msg menu_1panel_check)" \
      backup "$(msg menu_backup)" \
      uninstall "$(msg menu_uninstall)" \
      self-test "$(msg menu_self_test)" \
      back "$(msg menu_back)")" || return 0
    case "$choice" in
      install) install_flow ;;
      render) render_files ;;
      start) start_services ;;
      stop) stop_services ;;
      restart) restart_services ;;
      logs) show_logs ;;
      onepanel-preview) show_openresty_preview ;;
      onepanel-apply) apply_1panel_conf ;;
      onepanel-check) check_1panel ;;
      backup) backup_installation ;;
      uninstall) uninstall_installation ;;
      self-test) self_test ;;
      back) return 0 ;;
    esac
    if [[ -t 0 ]]; then
      read -r -p "$(msg press_enter)" _
    fi
  done
}
