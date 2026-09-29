# Installing Leash

Leash is a systemd **user** service in the graphical session: `leash.service` runs one
headed Chrome on the dedicated profile of `docs/config.md` and answers the `leash` CLI on
the control socket. The unit comes from `packaging/leash-unit.nix` — the same definition
the home-manager module assigns — so the text installed by hand and the text
home-manager writes never drift (svc-dit8, svc-46f0).

## Build

```sh
nix build .#leash --print-out-paths --no-link            # …-leash-dev
unit="$(nix build .#leash-unit --print-out-paths --no-link)/leash.service"
cat "$unit"
```

`.#leash` is the flake's package with Ox pinned (svc-46f0); `.#leash-unit` is the unit
whose `ExecStart` names that package's binary. The store path changes whenever the
source does, so read it from a fresh build instead of copying it.

```ini
[Unit]
After=graphical-session.target
Description=Leash browser service for coding agents
PartOf=graphical-session.target
StartLimitBurst=5
StartLimitIntervalSec=60

[Service]
Environment=XDG_RUNTIME_DIR=%t
Environment=EIO_BACKEND=posix
ExecStart=/nix/store/…-leash-dev/bin/leash serve
Restart=on-failure
RestartSec=2
SuccessExitStatus=0

[Install]
WantedBy=graphical-session.target
```

- `After`/`PartOf`/`WantedBy=graphical-session.target` — the service belongs to the
  graphical session: Chrome is a window, and the session is where its environment is.
- `Environment=XDG_RUNTIME_DIR=%t` — the control socket's default lives in the user
  manager's runtime directory (`control.socket`, docs/config.md).
- `Environment=EIO_BACKEND=posix` — the backend the sibling services' units use.
- `ExecStart=… serve` — the Door's start subcommand (Ox_app), named `serve` because
  `leash run "<mission>"` runs a mission over the playbooks (run-9ypy); a bare `leash`
  starts the same program.
- `Restart=on-failure`, `RestartSec=2` — a crashed service comes back on its own
  (svc-gxhu). A stop exits 0, so systemd does not count it as a failure.
- `SuccessExitStatus=0` — the Door exits 0 on SIGTERM; this is systemd's default and is
  written down because the restart policy rests on it (svc-dit8).
- `WAYLAND_DISPLAY` and `DISPLAY` are not hardcoded: the unit inherits the user
  manager's environment. This machine's niri session imports it at startup
  (`niri-session-env-import` runs `systemctl --user import-environment DISPLAY
  WAYLAND_DISPLAY …`); on a machine that does not, run that import in the compositor's
  startup hook. `systemctl --user show-environment | grep WAYLAND_DISPLAY` says whether
  it worked.

## Install with home-manager (this machine)

The flake exposes `homeManagerModules.leash` with the package already filled in from
its own `nix build .#leash`, so importing it is the whole install:

```nix
# /home/ribelo/nixos-config/flake.nix, among the inputs
inputs.leash.url = "path:/home/ribelo/projects/ribelo/leash";

# /home/ribelo/nixos-config/home/common/desktop/shell-stack.nix, beside the pie entry
imports = [ inputs.leash.homeManagerModules.leash ];
ribelo.leash.enable = true;
```

```sh
sudo nixos-rebuild switch --flake /home/ribelo/nixos-config#desktop
systemctl --user status leash.service
```

`WantedBy=graphical-session.target` starts it with the next session; for the current
one, `systemctl --user start leash.service`. `ribelo.leash` takes `enable` and
`package`; the module sets only the unit, nothing else in the system.

## Install by hand (no home-manager)

```sh
unit="$(nix build .#leash-unit --print-out-paths --no-link)/leash.service"
install -Dm644 "$unit" ~/.config/systemd/user/leash.service
systemctl --user daemon-reload
systemctl --user enable --now leash.service
```

A hand-installed unit pins the store path it was built from: rebuild, install again,
`systemctl --user restart leash.service`.

## Configuration

```sh
leash config init    # $XDG_CONFIG_HOME/leash/config.toml, every default commented out
leash config check   # validate the file without starting the service
```

Every key and default is in `docs/config.md`; usually only `chrome.binary` matters, and
a bare name is looked up on `PATH`. A first run needs no file at all — the service starts
on the defaults, profile directory included — so `config init` is only how a setting gets
pinned (svc-x8rp). For `drive`, the model key is
`OPENROUTER_API_KEY` in the environment (svc-kzt6): put it in the unit's environment
(`systemctl --user edit leash.service`) or in a wrapper that reads the secret and execs
the binary, the way Pie's `pie-service` wrapper reads `/run/agenix/openrouter-api-key`.
Without a key the service runs, `leash status` reports `models.configured: false`, and
`drive` refuses.

## Health check and logs

```sh
leash status                           # 0 and JSON while the service answers, non-zero when down
systemctl --user status leash.service  # what systemd thinks, restarts included
journalctl --user -u leash.service -f  # follow the service's records
journalctl --user -u leash.service --since "10 min ago" -p warning
```

`leash status` is one request over the control socket (svc-gxhu): the reply carries the
Chrome generation and phase, the tab counts and the models section, and the exit code is
0 only while the service answers, so a script can use it unchanged. Every command logs
its tab, owner and command to the journal (svc-p67t), and a `chrome generation lost`
entry carries Chrome's last stderr lines (svc-qrmc). `systemctl --user restart
leash.service` drops the open tabs and keeps the profile, so the logins survive.

## The niri rule (add by hand; Leash never edits your niri config)

The managed Chrome is launched with `--class=leash`, so its window matches
`app-id="^leash$"`. Add to `~/.config/niri/config.kdl`, beside the other
`window-rule` blocks:

```kdl
window-rule {
    match app-id="^leash$"
    open-on-workspace "leash"
    open-focused false
}
```

niri live-reloads `config.kdl` when the file changes (`niri msg action reload-config`
reloads it on demand), so no restart is needed: the rule puts the browser on the
`leash` workspace (created on demand) and keeps it from stealing focus. Leash knows only the workspace name (`chrome.workspace`, docs/config.md) and
never applies the rule itself.

## Uninstall

```sh
systemctl --user disable --now leash.service
rm ~/.config/systemd/user/leash.service   # a hand install
systemctl --user daemon-reload
```

With home-manager, drop the import and `ribelo.leash.enable` and rebuild. What stays
behind, all safe to delete:

- `$XDG_DATA_HOME/leash/profile` — the Chrome profile, logins included;
- `$XDG_CONFIG_HOME/leash/config.toml` — the configuration file;
- `$XDG_RUNTIME_DIR/leash/` — the control socket and its lock file, which the listener
  removes on a clean stop.

## Verifying the unit without installing it

```sh
scripts/unit-acceptance
```

builds `.#leash-unit`, verifies it with `systemd-analyze --user verify`, runs its exact
`ExecStart` line headless against a temporary config, checks that `leash status`
answers, refuses a second instance (svc-5wm8) and confirms SIGTERM exits 0 (svc-dit8).
It installs, enables and reloads nothing.
