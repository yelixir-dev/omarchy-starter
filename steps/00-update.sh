register_step update required no yes install

update_status() {
  local db=/var/lib/pacman/sync/core.db age
  [[ -f "$db" ]] || { echo outdated; return; }
  age=$(( $(date +%s) - $(stat -c %Y "$db") ))
  ((age < 86400)) && echo installed || echo outdated
}

update_install() {
  if is_omarchy; then
    omarchy update
  else
    sudo pacman -Syu
  fi
}
