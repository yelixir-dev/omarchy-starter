register_step sync optional yes yes

sync_status() {
  pkg_present syncthing || { echo missing; return; }
  systemctl --user is-enabled --quiet syncthing.service 2>/dev/null && echo installed || echo outdated
}

sync_install() {
  pkg_add syncthing
  systemctl --user enable --now syncthing.service
  log "$(t sync.done)"
}

sync_remove() {
  systemctl --user disable --now syncthing.service || true
  pkg_drop syncthing
}
