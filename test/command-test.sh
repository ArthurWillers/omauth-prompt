#!/bin/bash

set -euo pipefail

repo_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
test_root=$(mktemp -d)
trap 'rm -rf -- "$test_root"' EXIT

mkdir -p "$test_root/plugin/bin" "$test_root/fake-bin"
cp "$repo_dir/bin/omauth-prompt" "$test_root/plugin/bin/omauth-prompt"
cp "$repo_dir/bin/pinentry-omauth" "$test_root/plugin/bin/pinentry-omauth"
cp "$repo_dir/bin/omauth-askpass" "$test_root/plugin/bin/omauth-askpass"
chmod +x \
  "$test_root/plugin/bin/omauth-prompt" \
  "$test_root/plugin/bin/pinentry-omauth" \
  "$test_root/plugin/bin/omauth-askpass"

cat >"$test_root/fake-bin/gpgconf" <<'EOF'
#!/bin/bash
printf '%s\n' "$*" >>"${OMA_AUTH_GPGCONF_LOG}"
EOF
chmod +x "$test_root/fake-bin/gpgconf"

export HOME="$test_root/home"
unset GNUPGHOME || true
unset XDG_CONFIG_HOME || true
export PATH="$test_root/fake-bin:$PATH"
export OMA_AUTH_GPGCONF_LOG="$test_root/gpgconf.log"
mkdir -p "$HOME"

command="$test_root/plugin/bin/omauth-prompt"
status_output=$("$command" status)
grep -Fqx 'GnuPG / PGP: not configured' <<<"$status_output"
grep -Fqx 'SSH / Git askpass: not configured' <<<"$status_output"
grep -Fqx 'Sudo askpass: not configured' <<<"$status_output"
$command setup-gpg
grep -Fqx "pinentry-program $test_root/plugin/bin/pinentry-omauth" "$HOME/.gnupg/gpg-agent.conf"
grep -Fqx 'GnuPG / PGP: configured' <<<"$($command status)"
$command setup-gpg
$command configure --askpass
grep -Fqx "export SSH_ASKPASS=$test_root/plugin/bin/omauth-askpass" "$HOME/.config/omauth-prompt/env"
grep -Fqx 'export SSH_ASKPASS_REQUIRE=force' "$HOME/.config/omauth-prompt/env"
grep -Fqx "export GIT_ASKPASS=$test_root/plugin/bin/omauth-askpass" "$HOME/.config/omauth-prompt/env"
$command configure --sudo
grep -Fqx "export SUDO_ASKPASS=$test_root/plugin/bin/omauth-askpass" "$HOME/.config/omauth-prompt/env"
grep -Fqx 'SSH / Git askpass: configured' <<<"$($command status)"
grep -Fqx 'Sudo askpass: configured' <<<"$($command status)"
$command remove-askpass
grep -Fqx 'SSH / Git askpass: not configured' <<<"$($command status)"
$command remove-gpg
! grep -Fq "pinentry-program $test_root/plugin/bin/pinentry-omauth" "$HOME/.gnupg/gpg-agent.conf"
grep -Fqx 'GnuPG / PGP: not configured' <<<"$($command status)"
grep -Fqx -- '--kill gpg-agent' "$OMA_AUTH_GPGCONF_LOG"

echo "command tests passed"
