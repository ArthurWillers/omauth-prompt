#!/bin/bash

set -euo pipefail

repo_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
test_root=$(mktemp -d)
trap 'rm -rf -- "$test_root"' EXIT

mkdir -p "$test_root/plugin/bin" "$test_root/fake-bin"
cp "$repo_dir/bin/omauth-prompt" "$test_root/plugin/bin/omauth-prompt"
cp "$repo_dir/bin/pinentry-omauth" "$test_root/plugin/bin/pinentry-omauth"
chmod +x "$test_root/plugin/bin/omauth-prompt" "$test_root/plugin/bin/pinentry-omauth"

cat >"$test_root/fake-bin/gpgconf" <<'EOF'
#!/bin/bash
printf '%s\n' "$*" >>"${OMA_AUTH_GPGCONF_LOG}"
EOF
chmod +x "$test_root/fake-bin/gpgconf"

export HOME="$test_root/home"
unset GNUPGHOME || true
export PATH="$test_root/fake-bin:$PATH"
export OMA_AUTH_GPGCONF_LOG="$test_root/gpgconf.log"
mkdir -p "$HOME"

command="$test_root/plugin/bin/omauth-prompt"
[[ "$($command status)" == "not configured" ]]
$command setup-gpg
grep -Fqx "pinentry-program $test_root/plugin/bin/pinentry-omauth" "$HOME/.gnupg/gpg-agent.conf"
[[ "$($command status)" == "configured" ]]
$command setup-gpg
$command remove-gpg
! grep -Fq "pinentry-program $test_root/plugin/bin/pinentry-omauth" "$HOME/.gnupg/gpg-agent.conf"
[[ "$($command status)" == "not configured" ]]
grep -Fqx -- '--kill gpg-agent' "$OMA_AUTH_GPGCONF_LOG"

echo "command tests passed"
