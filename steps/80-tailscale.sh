register_step tailscale optional yes yes

tailscale_status() {
  pkg_present tailscale || { echo missing; return; }
  systemctl is-enabled --quiet tailscaled 2>/dev/null && echo installed || echo outdated
}

tailscale_install() {
  pkg_add tailscale
  sudo systemctl enable --now tailscaled
  sudo tailscale up --accept-routes=false
  sudo tailscale set --operator="$USER"
  tailscale status || true
}

tailscale_remove() {
  sudo tailscale down || true
  sudo systemctl disable --now tailscaled || true
  pkg_drop tailscale
}
