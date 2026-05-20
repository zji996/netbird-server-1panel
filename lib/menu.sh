main_menu() {
  while true; do
    local choice
    choice="$(tui_menu "Select operation" \
      install "Render config and start services" \
      render "Render or update generated files" \
      start "Start services" \
      stop "Stop services" \
      restart "Restart services" \
      status "Show status and endpoint checks" \
      logs "Show recent logs" \
      onepanel-preview "Preview 1Panel OpenResty config" \
      onepanel-apply "Apply 1Panel OpenResty config" \
      onepanel-check "Check and optionally reload OpenResty" \
      backup "Backup config and data" \
      uninstall "Uninstall services/config" \
      self-test "Run local behavior tests" \
      quit "Exit")" || exit 0
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
      read -r -p "Press Enter to continue..." _
    fi
  done
}
