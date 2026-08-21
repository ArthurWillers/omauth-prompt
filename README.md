# omauth-prompt

`omauth-prompt` is a theme-aware authentication surface for Omarchy. It keeps
the visual prompt inside the existing long-running `omarchy-shell` process and
lets command-line adapters exchange the secret through a private file in
`$XDG_RUNTIME_DIR`.

The first release includes adapters for:

- GnuPG's Assuan `pinentry` protocol (`bin/pinentry-omauth`)
- OpenSSH's `SSH_ASKPASS` protocol (`bin/omauth-askpass`)

It also includes a terminal-native setup wizard powered by Omarchy's existing
`gum` dependency. The wizard runs in the terminal where it is started; it
does not open a floating terminal and never needs `pkexec`.

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

Setup is intentionally explicit: installing the plugin does not silently edit
your GnuPG configuration, shell environment, or sudo behavior. Run the setup
wizard only for the integrations you want to use.

## Requirements

- Omarchy Quattro with third-party shell plugins enabled
- GnuPG and `gpg-agent` for the pinentry adapter
- OpenSSH for the optional `SSH_ASKPASS` adapter
- `jq` and Python 3, which are used by the included adapters
- `gum`, included with Omarchy, for the interactive setup wizard

## Terminal setup wizard

The plugin cannot add a new top-level `omarchy` command because Omarchy plugins
are loaded by the shell rather than installed into `/usr/share/omarchy/bin`.
Install the short launcher once through the shell IPC:

```bash
omarchy-shell omauth install
```

After that, use the short command directly in your current terminal. The
wizard lets you select GnuPG/PGP, SSH/Git askpass, and optional sudo askpass
support:

```bash
omauth-prompt setup
```

Non-interactive variants are available for scripts:

```bash
omauth-prompt setup --gpg
omauth-prompt setup --askpass
omauth-prompt setup --sudo
omauth-prompt setup --all
```

The setup only changes user-owned files. It does not use `pkexec`, request root
access, or silently enable graphical sudo authentication.

## GnuPG pinentry

The wizard can point GnuPG at the adapter installed with the plugin. The
non-interactive equivalent is:

```bash
"$plugin_dir/bin/omauth-prompt" setup-gpg
```

The existing `gpg-agent` starts the adapter on demand. The adapter speaks the
standard Assuan protocol and preserves GnuPG's normal cancellation and timeout
behavior. Setup is idempotent, backs up `gpg-agent.conf` before changing it,
and refuses to overwrite a different existing `pinentry-program` entry.

## SSH askpass

The wizard writes a sourceable environment file for commands that need an
interactive SSH password, key passphrase, or Git credential:

```bash
source "$HOME/.config/omauth-prompt/env"
```

This enables `SSH_ASKPASS`, `GIT_ASKPASS`, and their corresponding settings.
The optional sudo integration adds `SUDO_ASKPASS`; use it explicitly with
`sudo -A command`. SSH agents are usually preferable for keys, and the
askpass adapter is for callers that genuinely need a prompt.

## Updating

Omarchy installs plugins as git checkouts. Update the plugin and restart the
shell so already-loaded QML uses the new checkout:

```bash
omarchy plugin update io.github.arthurwillers.omauth-prompt --yes
omarchy restart shell
```

## Generic adapter contract

Adapters call the already-loaded panel through Omarchy shell IPC:

```bash
omarchy-shell omauth prompt "$payload"
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

## Plugin commands

```bash
plugin_id="io.github.arthurwillers.omauth-prompt"
plugin_dir="$HOME/.config/omarchy/plugins/$plugin_id"

omarchy plugin list
omarchy plugin update io.github.arthurwillers.omauth-prompt
omarchy plugin disable io.github.arthurwillers.omauth-prompt
omarchy plugin enable io.github.arthurwillers.omauth-prompt
omarchy-shell omauth install
omauth-prompt status
omauth-prompt doctor
```

## Remove

If GnuPG is using the adapter, remove its configuration before removing the
plugin. The plugin includes an explicit cleanup command that preserves a
backup and removes only its own exact line:

```bash
plugin_id="io.github.arthurwillers.omauth-prompt"
plugin_dir="$HOME/.config/omarchy/plugins/$plugin_id"

omarchy plugin disable "$plugin_id" 2>/dev/null || true
omauth-prompt remove-gpg
omauth-prompt remove-askpass
omarchy-shell omauth uninstall
omarchy plugin remove "$plugin_id"
```

If you sourced the generated environment file in a shell profile, remove that
source line from the profile. For the current shell only:

```bash
unset SSH_ASKPASS SSH_ASKPASS_REQUIRE GIT_ASKPASS GIT_TERMINAL_PROMPT SUDO_ASKPASS
```

## Limitations

This plugin is an authentication prompt surface, not a replacement for every
authentication backend. Polkit already has its own Omarchy agent, and `sudo`
normally expects a terminal/PAM conversation. The optional `SUDO_ASKPASS`
integration is opt-in and only applies when a command uses `sudo -A`.

## Development

Validate the plugin against the installed Omarchy shell sources:

```bash
omarchy plugin validate .
qmllint -I "$OMARCHY_PATH/shell" AuthPrompt.qml PasswordPrompt.qml
bash -n bin/omauth-prompt bin/pinentry-omauth bin/omauth-askpass lib/omauth-bridge.sh
test/adapters-test.sh
test/command-test.sh
```

## License

MIT. See [LICENSE](LICENSE).
