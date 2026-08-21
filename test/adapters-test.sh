#!/bin/bash

set -euo pipefail

repo_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
test_root=$(mktemp -d)
trap 'rm -rf -- "$test_root"' EXIT

mkdir -p "$test_root/bin" "$test_root/runtime"
cp "$repo_dir/test/fake-omarchy-shell" "$test_root/bin/omarchy-shell"
chmod +x "$test_root/bin/omarchy-shell"

pinentry_output=$(printf 'SETPROMPT Test%%20passphrase\nGETPIN\nBYE\n' \
  | OMARCHY_PATH="$test_root" XDG_RUNTIME_DIR="$test_root/runtime" \
    "$repo_dir/bin/pinentry-omauth")
grep -Fqx 'OK Pleased to meet you' <<<"$pinentry_output"
grep -Fqx 'D test-secret' <<<"$pinentry_output"
grep -Fqx 'OK closing connection' <<<"$pinentry_output"

askpass_output=$(OMARCHY_PATH="$test_root" XDG_RUNTIME_DIR="$test_root/runtime" \
  "$repo_dir/bin/omauth-askpass" 'Password:')
grep -Fqx 'test-secret' <<<"$askpass_output"

echo "adapter tests passed"
