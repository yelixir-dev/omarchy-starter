register_step kakaotalk optional yes yes

KAKAO_BOTTLE_DIR="$HOME/.var/app/com.usebottles.bottles/data/bottles/bottles/kakaotalk"

kakaotalk_choices() {
  printf '%s\n' bottles wine both
}

kakaotalk_has_bottles() { [[ -d "$KAKAO_BOTTLE_DIR" ]]; }
kakaotalk_has_wine() { pkg_present kakaotalk; }

kakaotalk_status() {
  if kakaotalk_has_bottles || kakaotalk_has_wine; then echo installed; else echo missing; fi
}

kakaotalk_install() {
  case "${STEP_CHOICE:-bottles}" in
    bottles) bash "$OS_ROOT/install-kakaotalk-bottles.sh" install ;;
    wine) kakaotalk_install_wine ;;
    both)
      bash "$OS_ROOT/install-kakaotalk-bottles.sh" install
      kakaotalk_install_wine
      ;;
  esac
}

kakaotalk_install_wine() {
  pkg_aur_add kakaotalk
  log "$(t kakaotalk.wine_hint)"
}

kakaotalk_remove() {
  kakaotalk_has_bottles && bash "$OS_ROOT/install-kakaotalk-bottles.sh" --uninstall
  if kakaotalk_has_wine; then
    pkg_drop kakaotalk
    [[ -d "$HOME/.local/share/kakaotalk" ]] && log "$(t kakaotalk.wine_data): $HOME/.local/share/kakaotalk"
  fi
  return 0
}
