#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=../scripts/lib/reload-auth.sh
source "$REPO_ROOT/scripts/lib/reload-auth.sh"

assert_mode() {
  local expected="$1"
  local tag="$2"
  local explicit_mode="${3:-}"
  local actual
  actual="$(cmux_reload_resolve_auth_mode "$tag" "$explicit_mode")"
  if [[ "$actual" != "$expected" ]]; then
    echo "expected '$expected' for tag '$tag' and explicit mode '$explicit_mode', got '$actual'" >&2
    exit 1
  fi
}

for tag in dev-bdec dev-bdec7 dev-bdec123; do
  assert_mode production "$tag"
done

for tag in dev-bdecx dev-bdec-2 dev-bdec2a dev-bdeC xdev-bdec bdec ""; do
  assert_mode development "$tag"
done

assert_mode production feature-x production
assert_mode development dev-bdec development

selected="$(cmux_reload_select_auth_mode "" production)"
[[ "$selected" == "production" ]]
selected="$(cmux_reload_select_auth_mode production production)"
[[ "$selected" == "production" ]]

if cmux_reload_select_auth_mode production development >/dev/null 2>&1; then
  echo "expected conflicting explicit auth modes to fail" >&2
  exit 1
fi

for script in "$REPO_ROOT/scripts/reload.sh" "$REPO_ROOT/ios/scripts/reload.sh"; do
  bash -n "$script"
  help="$("$script" --help)"
  [[ "$help" == *"--prod-auth"* ]]
  [[ "$help" == *"--dev-auth"* ]]
  if "$script" --tag dev-bdec --prod-auth --dev-auth >/dev/null 2>&1; then
    echo "expected conflicting auth flags to fail for $script" >&2
    exit 1
  fi
done

echo "test_reload_auth_defaults: ok"
