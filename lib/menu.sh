main_menu() {
  while true; do
    local choice
    choice="$(tui_menu "$(msg menu_title)" \
      install "$(msg menu_install)" \
      render "$(msg menu_render)" \
      start "$(msg menu_start)" \
      stop "$(msg menu_stop)" \
      restart "$(msg menu_restart)" \
      status "$(msg menu_status)" \
      logs "$(msg menu_logs)" \
      onepanel-preview "$(msg menu_1panel_preview)" \
      onepanel-apply "$(msg menu_1panel_apply)" \
      onepanel-check "$(msg menu_1panel_check)" \
      backup "$(msg menu_backup)" \
      uninstall "$(msg menu_uninstall)" \
      self-test "$(msg menu_self_test)" \
      quit "$(msg menu_quit)")" || exit 0
    case "$choice" in
      install) install_flow ;;
      render) prompt_settings; render_files ;;
      start) start_services ;;
      stop) stop_services ;;
      restart) restart_services ;;
      status) show_status ;;
      logs) show_logs ;;
      onepanel-preview) render_openresty_root_conf | ${PAGER:-less} ;;
      onepanel-apply) prompt_settings; apply_1panel_conf ;;
      onepanel-check) check_1panel ;;
      backup) backup_installation ;;
      uninstall) uninstall_installation ;;
      self-test) self_test ;;
      quit) exit 0 ;;
    esac
    if [[ -t 0 ]]; then
      read -r -p "$(msg press_enter)" _
    fi
  done
}
