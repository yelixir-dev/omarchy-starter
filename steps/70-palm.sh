register_step palm optional yes yes

palm_visible() { [[ -n "${OMARCHY_STARTER_FORCE_MAC:-}" ]] || is_intel_mac; }

palm_status() {
  [[ -f /etc/udev/hwdb.d/70-apple-internal-touchpad.hwdb ]] && echo installed || echo missing
}

palm_install() {
  bash "$OS_ROOT/install-intel-mac-palm-rejection.sh" --dry-run
  bash "$OS_ROOT/install-intel-mac-palm-rejection.sh"
}

palm_remove() { bash "$OS_ROOT/install-intel-mac-palm-rejection.sh" --uninstall; }
