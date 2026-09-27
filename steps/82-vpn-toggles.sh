register_step vpn-toggles optional yes no

vpn_toggles_status() {
  local root="${XDG_CONFIG_HOME:-$HOME/.config}/omarchy/plugins"
  if [[ -d "$root/user.tailscale-toggle" || -d "$root/user.nordvpn-toggle" ]]; then echo installed; else echo missing; fi
}

vpn_toggles_install() { bash "$OS_ROOT/install-vpn-bar-toggles.sh" install; }
vpn_toggles_remove() { bash "$OS_ROOT/install-vpn-bar-toggles.sh" --uninstall; }
