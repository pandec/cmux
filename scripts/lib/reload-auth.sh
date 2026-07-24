# shellcheck shell=bash
# Shared auth-mode resolution for the macOS and iOS tagged reload scripts.

cmux_reload_select_auth_mode() {
  local current_mode="${1:-}"
  local requested_mode="${2:-}"

  case "$requested_mode" in
    production|development) ;;
    *)
      echo "error: invalid reload auth mode '$requested_mode'" >&2
      return 2
      ;;
  esac

  if [[ -n "$current_mode" && "$current_mode" != "$requested_mode" ]]; then
    echo "error: --prod-auth and --dev-auth cannot be used together" >&2
    return 2
  fi

  printf '%s' "$requested_mode"
}

cmux_reload_resolve_auth_mode() {
  local tag="${1:-}"
  local explicit_mode="${2:-}"

  case "$explicit_mode" in
    production|development)
      printf '%s' "$explicit_mode"
      return 0
      ;;
    "")
      ;;
    *)
      echo "error: invalid reload auth mode '$explicit_mode'" >&2
      return 2
      ;;
  esac

  if [[ "$tag" =~ ^dev-bdec[0-9]*$ ]]; then
    printf '%s' "production"
  else
    printf '%s' "development"
  fi
}
