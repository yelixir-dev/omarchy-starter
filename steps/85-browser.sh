register_step browser optional yes yes

browser_choices() {
  printf '%s\n' firefox brave zen
}

browser_package() {
  case "$1" in
    firefox) echo firefox ;;
    brave) echo brave-bin ;;
    zen) echo zen-browser-bin ;;
  esac
}

browser_status() {
  if pkg_present firefox || pkg_present brave-bin || pkg_present zen-browser-bin; then echo installed; else echo missing; fi
}

browser_install() {
  local choice="${STEP_CHOICE:-firefox}"
  if is_omarchy; then
    omarchy install browser "$choice"
  elif [[ "$choice" == firefox ]]; then
    pkg_add firefox
  else
    pkg_aur_add "$(browser_package "$choice")"
  fi
}

browser_remove() {
  pkg_drop firefox brave-bin zen-browser-bin
}
