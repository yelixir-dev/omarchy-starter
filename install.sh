#!/usr/bin/env bash
set -uo pipefail

OS_REPO_URL="${OMARCHY_STARTER_REPO:-https://github.com/yelixir-dev/omarchy-starter.git}"
OS_CLONE_DIR="${OMARCHY_STARTER_DIR:-$HOME/.local/share/omarchy-starter}"

os_self_dir() {
  local src="${BASH_SOURCE[0]:-}"
  [[ -n "$src" && -f "$src" ]] || return 1
  cd -- "$(dirname -- "$src")" && pwd
}

if ! OS_ROOT="$(os_self_dir)" || [[ ! -f "$OS_ROOT/lib/common.sh" ]]; then
  command -v git >/dev/null 2>&1 || { echo "[x] git is required" >&2; exit 1; }
  if [[ -d "$OS_CLONE_DIR/.git" ]]; then
    git -C "$OS_CLONE_DIR" pull --ff-only --quiet || echo "[!] git pull failed; using the existing copy" >&2
  else
    git clone --quiet "$OS_REPO_URL" "$OS_CLONE_DIR" || { echo "[x] git clone failed" >&2; exit 1; }
  fi
  if [[ -r /dev/tty ]]; then
    exec bash "$OS_CLONE_DIR/install.sh" "$@" </dev/tty
  fi
  exec bash "$OS_CLONE_DIR/install.sh" "$@"
fi
export OS_ROOT

OS_LANG="${OMARCHY_STARTER_LANG:-ko}"
MODE=interactive
DRY_RUN=0
ASSUME_YES=0
ONLY=""
REMOVE_LIST=""
declare -A CHOICE=()

usage() {
  cat <<'EOF'
install.sh [--lang ko|en] [--list] [--dry-run] [--all] [--only a,b] [--remove a,b]
           [--choice step=value] [--yes]
EOF
}

while (($#)); do
  case "$1" in
    --lang) OS_LANG="${2:-}"; shift 2 ;;
    --lang=*) OS_LANG="${1#*=}"; shift ;;
    --list) MODE=list; shift ;;
    --dry-run) DRY_RUN=1; shift ;;
    --all) MODE=all; shift ;;
    --only) MODE=explicit; ONLY="${2:-}"; shift 2 ;;
    --remove) MODE=explicit; REMOVE_LIST="${2:-}"; shift 2 ;;
    --choice) CHOICE["${2%%=*}"]="${2#*=}"; shift 2 ;;
    -y | --yes) ASSUME_YES=1; shift ;;
    -h | --help) usage; exit 0 ;;
    *) echo "[x] unknown option: $1" >&2; usage >&2; exit 2 ;;
  esac
done

[[ "$OS_LANG" == ko || "$OS_LANG" == en ]] || { echo "[x] --lang must be ko or en" >&2; exit 2; }

declare -A T=()
# shellcheck source=i18n/ko.sh
source "$OS_ROOT/i18n/$OS_LANG.sh"
source "$OS_ROOT/lib/common.sh"
source "$OS_ROOT/lib/ui.sh"

IDS=()
ROWS=()
declare -A CAT=() STATUS=() ACTION=() REMOVABLE=() SUDO=() OUTDATED_DEFAULT=()

register_step() {
  local id="$1"
  CAT[$id]="$2"
  REMOVABLE[$id]="$3"
  SUDO[$id]="$4"
  OUTDATED_DEFAULT[$id]="${5:-keep}"
  IDS+=("$id")
}

step_fn() { printf '%s_%s' "${1//-/_}" "$2"; }
step_has() { [[ -n "$(declare -F "$(step_fn "$1" "$2")")" ]]; }

for f in "${OMARCHY_STARTER_STEPS_DIR:-$OS_ROOT/steps}"/[0-9]*.sh; do
  # shellcheck disable=SC1090
  source "$f"
done

for cat in required recommended optional; do
  for id in "${IDS[@]}"; do
    [[ "${CAT[$id]}" == "$cat" ]] || continue
    if step_has "$id" visible && ! "$(step_fn "$id" visible)"; then
      continue
    fi
    ROWS+=("$id")
  done
done

for id in "${ROWS[@]}"; do
  STATUS[$id]="$("$(step_fn "$id" status)" 2>/dev/null || echo missing)"
  case "${STATUS[$id]}" in installed | outdated | missing) ;; *) STATUS[$id]=missing ;; esac
done

apply_default_actions() {
  local id
  for id in "${ROWS[@]}"; do
    if [[ "${STATUS[$id]}" == outdated ]]; then
      ACTION[$id]="${OUTDATED_DEFAULT[$id]}"
    elif [[ "${STATUS[$id]}" == installed ]]; then
      ACTION[$id]=keep
    elif [[ "${CAT[$id]}" == optional ]]; then
      ACTION[$id]=none
    else
      ACTION[$id]=install
    fi
  done
}

is_row() {
  local x
  for x in "${ROWS[@]}"; do [[ "$x" == "$1" ]] && return 0; done
  return 1
}

apply_default_actions

if [[ "$MODE" == explicit ]]; then
  for id in "${ROWS[@]}"; do
    [[ "${STATUS[$id]}" == missing ]] && ACTION[$id]=none || ACTION[$id]=keep
  done
  IFS=, read -ra _only <<<"$ONLY"
  for id in "${_only[@]}"; do
    [[ -z "$id" ]] && continue
    is_row "$id" || die "$(t err.unknown_step): $id"
    ACTION[$id]=install
  done
  IFS=, read -ra _rm <<<"$REMOVE_LIST"
  for id in "${_rm[@]}"; do
    [[ -z "$id" ]] && continue
    is_row "$id" || die "$(t err.unknown_step): $id"
    [[ "${REMOVABLE[$id]}" == yes ]] || die "$(t err.not_removable): $id"
    ACTION[$id]=remove
  done
fi

if [[ "$MODE" == list ]]; then
  for id in "${ROWS[@]}"; do
    printf '%-17s %-12s %-10s %-8s %s\n' "$id" "${CAT[$id]}" "${STATUS[$id]}" "${ACTION[$id]}" "$(t "$id.name")"
  done
  exit 0
fi

if [[ "$MODE" == interactive ]]; then
  if ! { : </dev/tty; } 2>/dev/null; then
    die "$(t err.notty)"
  fi
  ui_checklist || { echo "$(t ui.cancel)"; exit 0; }
fi

choose_options() {
  local id="$1" fn
  fn="$(step_fn "$id" choices)"
  "$fn"
}

for id in "${ROWS[@]}"; do
  [[ "${ACTION[$id]}" == install ]] || continue
  step_has "$id" choices || continue
  [[ -n "${CHOICE[$id]:-}" ]] && continue
  mapfile -t _opts < <(choose_options "$id")
  if [[ "$MODE" == interactive ]]; then
    _args=()
    for o in "${_opts[@]}"; do _args+=("$o" "$(t "$id.choice.$o")"); done
    CHOICE[$id]="$(ui_select_one "$(t "$id.choice.title")" 0 "${_args[@]}")" || { echo "$(t ui.cancel)"; exit 0; }
  else
    CHOICE[$id]="${_opts[0]}"
  fi
done

INSTALLS=()
REMOVES=()
KEEPS=()
for id in "${ROWS[@]}"; do
  case "${ACTION[$id]}" in
    install) INSTALLS+=("$id") ;;
    remove) REMOVES+=("$id") ;;
    keep) KEEPS+=("$id") ;;
  esac
done

print_plan() {
  local id label
  printf '%s\n' "$(t ui.summary.title)"
  for id in "${REMOVES[@]}"; do printf '  [x] %s\n' "$(t "$id.name")"; done
  for id in "${INSTALLS[@]}"; do
    label="$(t "$id.name")"
    [[ -n "${CHOICE[$id]:-}" ]] && label="$label ($(t "$id.choice.${CHOICE[$id]}"))"
    printf '  [v] %s\n' "$label"
  done
  for id in "${KEEPS[@]}"; do printf '  [-] %s\n' "$(t "$id.name")"; done
  printf '%s\n' "$(t ui.summary.counts | sed "s/{i}/${#INSTALLS[@]}/; s/{r}/${#REMOVES[@]}/; s/{k}/${#KEEPS[@]}/")"
}

print_plan

if ((${#INSTALLS[@]} + ${#REMOVES[@]} == 0)); then
  echo "$(t ui.nothing)"
  exit 0
fi

if ((DRY_RUN)); then
  echo "$(t ui.dry_run)"
  exit 0
fi

if [[ "$MODE" == interactive ]] && ((!ASSUME_YES)); then
  if ((${#REMOVES[@]})); then
    ui_confirm "$(t ui.confirm.remove)" || { echo "$(t ui.cancel)"; exit 0; }
  else
    ui_confirm "$(t ui.confirm.run)" || { echo "$(t ui.cancel)"; exit 0; }
  fi
fi

needs_sudo=0
for id in "${INSTALLS[@]}" "${REMOVES[@]}"; do
  [[ "${SUDO[$id]}" == yes ]] && needs_sudo=1
done
((needs_sudo)) && { sudo -v || die "$(t err.sudo)"; }

mkdir -p -- "$OS_STATE_DIR/logs"
LOG_FILE="$OS_STATE_DIR/logs/$(date +%Y%m%d-%H%M%S).log"
declare -A RESULT=()

run_step() {
  local id="$1" verb="$2" rc
  printf '\n== %s: %s ==\n' "$(t "run.$verb")" "$(t "$id.name")"
  (
    set -e
    STEP_CHOICE="${CHOICE[$id]:-}"
    export STEP_CHOICE
    "$(step_fn "$id" "$verb")"
  )
  rc=$?
  if ((rc == 0)); then RESULT[$id]=ok; else RESULT[$id]=fail; fi
  printf '%s %s %s rc=%s\n' "$(date -Is)" "$verb" "$id" "$rc" >>"$LOG_FILE"
}

for ((i = ${#REMOVES[@]} - 1; i >= 0; i--)); do run_step "${REMOVES[$i]}" remove; done
for id in "${INSTALLS[@]}"; do run_step "$id" install; done

printf '\n%s\n' "$(t results.title)"
failed=0
for id in "${REMOVES[@]}" "${INSTALLS[@]}"; do
  if [[ "${RESULT[$id]}" == ok ]]; then
    printf '  %s  %s\n' "$(t results.ok)" "$(t "$id.name")"
  else
    printf '  %s  %s\n' "$(t results.fail)" "$(t "$id.name")"
    failed=1
  fi
done
printf '%s %s\n' "$(t results.log)" "$LOG_FILE"
exit "$failed"
