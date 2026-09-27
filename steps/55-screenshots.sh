register_step screenshots recommended yes no

screenshots_status() {
  grep -q 'SUPER + SHIFT + 9' "$HOME/.config/hypr/bindings.lua" 2>/dev/null && echo installed || echo missing
}

screenshots_install() { bash "$OS_ROOT/install-screenshot-shortcuts.sh" install; }
screenshots_remove() { bash "$OS_ROOT/install-screenshot-shortcuts.sh" --uninstall; }
