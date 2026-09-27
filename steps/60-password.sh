register_step password recommended yes yes

password_choices() {
  printf '%s\n' 1password bitwarden
}

password_status() {
  if pkg_present 1password || pkg_present bitwarden; then echo installed; else echo missing; fi
}

password_install() {
  case "${STEP_CHOICE:-1password}" in
    1password)
      if has_cmd omarchy-install-service-1password; then
        omarchy-install-service-1password
      else
        pkg_add 1password 1password-cli
      fi
      ;;
    bitwarden) pkg_add bitwarden bitwarden-cli ;;
  esac
}

password_remove() {
  pkg_drop 1password 1password-cli bitwarden bitwarden-cli
}
