register_step korean required yes yes

KOREAN_PROFILE="${XDG_CONFIG_HOME:-$HOME/.config}/fcitx5/profile"

korean_status() {
  pkg_present fcitx5-hangul || { echo missing; return; }
  grep -q '^Name=hangul' "$KOREAN_PROFILE" 2>/dev/null && echo installed || echo outdated
}

korean_install() {
  bash "$OS_ROOT/install-fcitx5-hangul.sh"
}

korean_remove() {
  if busctl --user status org.fcitx.Fcitx5 >/dev/null 2>&1; then
    busctl --user call org.fcitx.Fcitx5 /controller org.fcitx.Fcitx.Controller1 \
      SetInputMethodGroupInfo 'ssa(ss)' Default us 1 keyboard-us ''
    busctl --user call org.fcitx.Fcitx5 /controller org.fcitx.Fcitx.Controller1 Save
  fi
  pkg_drop fcitx5-hangul
}
