# omauth-prompt

`omauth-prompt` is a small, theme-aware authentication surface for Omarchy.
It keeps the visual prompt inside the existing long-running `omarchy-shell`
process and lets command-line adapters exchange the secret through a private
file in `$XDG_RUNTIME_DIR`.

The first release includes adapters for:

- GnuPG's Assuan `pinentry` protocol (`bin/pinentry-omauth`)
- OpenSSH's `SSH_ASKPASS` protocol (`bin/omauth-askpass`)

The UI is intentionally independent of both. A future adapter only needs to
send a request to the `omauth-prompt` panel and read its JSON response.

## Install

Use the Omarchy plugin commands so the shell can review, enable, update, and
remove the plugin as a normal third-party plugin:

```bash
omarchy plugin add https://github.com/ArthurWillers/omauth-prompt.git --enable
```

Third-party plugins run as unsandboxed code inside `omarchy-shell`. Review the
repository before enabling it, especially because this plugin handles secrets.

## GnuPG

Point GnuPG at the adapter installed with the plugin:

```bash
mkdir -p "$HOME/.gnupg"
pinentry="$HOME/.config/omarchy/plugins/io.github.arthurwillers.omauth-prompt/bin/pinentry-omauth"
grep -Fqx "pinentry-program $pinentry" "$HOME/.gnupg/gpg-agent.conf" 2>/dev/null \
  || printf 'pinentry-program %s\n' "$pinentry" >> "$HOME/.gnupg/gpg-agent.conf"
gpgconf --kill gpg-agent
```

The existing `gpg-agent` starts the adapter on demand. The adapter speaks the
standard Assuan protocol and preserves GnuPG's normal cancellation and timeout
behavior.

## SSH

For commands that need an interactive SSH password or key passphrase, point
`SSH_ASKPASS` at the included adapter and force OpenSSH to use it when no TTY
is available:

```bash
export SSH_ASKPASS="$HOME/.config/omarchy/plugins/io.github.arthurwillers.omauth-prompt/bin/omauth-askpass"
export SSH_ASKPASS_REQUIRE=force
```

For a persistent setup, place those exports in the environment that launches
the relevant application or service. SSH agents are usually preferable for
keys; the adapter is for callers that genuinely need a prompt.

## Generic adapter contract

Adapters call the already-loaded panel through Omarchy shell IPC:

```bash
omarchy-shell shell call io.github.arthurwillers.omauth-prompt open "$payload"
```

The JSON payload is:

```json
{
  "responsePath": "/run/user/1000/omauth-prompt.abc/result.json",
  "title": "Application authentication",
  "description": "A passphrase is required",
  "prompt": "Enter passphrase",
  "error": "",
  "timeoutMs": 120000
}
```

`responsePath` must point to a file below `$XDG_RUNTIME_DIR`. The panel writes:

```json
{"status":"ok","secret":"..."}
```

or a cancellation response. The path and its parent directory should be
private (`0700` directory, `0600` file). Never put the secret in an IPC
argument, environment variable, log, clipboard, or command line.

## Omarchy commands

```bash
omarchy plugin list
omarchy plugin update io.github.arthurwillers.omauth-prompt
omarchy plugin disable io.github.arthurwillers.omauth-prompt
omarchy plugin enable io.github.arthurwillers.omauth-prompt
omarchy plugin remove io.github.arthurwillers.omauth-prompt
```

Removing the plugin does not change GnuPG configuration. If it was configured
as the pinentry, remove that exact `pinentry-program .../pinentry-omauth` line
and run `gpgconf --kill gpg-agent` before removing the plugin.

## Scope

This plugin is an authentication prompt surface, not a replacement for every
authentication backend. Polkit already has its own Omarchy agent and `sudo`
normally expects a terminal/PAM conversation; replacing either globally would
require a separate integration and would risk competing authentication agents.

## Development

Validate the plugin against the installed Omarchy shell sources:

```bash
omarchy plugin validate .
qmllint -I "$OMARCHY_PATH/shell" AuthPrompt.qml PasswordPrompt.qml
bash -n bin/pinentry-omauth bin/omauth-askpass lib/omauth-bridge.sh
```

## License

MIT. See [LICENSE](LICENSE).
