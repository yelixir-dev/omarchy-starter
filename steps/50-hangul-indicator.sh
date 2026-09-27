register_step hangul-indicator recommended yes no

hangul_indicator_status() {
  [[ -f "${XDG_CONFIG_HOME:-$HOME/.config}/omarchy/plugins/user.fcitx-state/manifest.json" ]] && echo installed || echo missing
}

hangul_indicator_install() { bash "$OS_ROOT/install-fcitx5-bar-indicator.sh" install; }
hangul_indicator_remove() { bash "$OS_ROOT/install-fcitx5-bar-indicator.sh" --uninstall; }
