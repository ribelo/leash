Status names not-installed, stopped and restarting without systemd, and a
healthy reply reports version, Chrome, a boolean key and the skill. The probe is
a fixture file; systemctl is not on this PATH.

  $ unset LEASH_INSTALL_FIXTURE
  $ export XDG_CONFIG_HOME="$PWD/config" XDG_RUNTIME_DIR="$PWD/runtime" XDG_STATE_HOME="$PWD/state" HOME="$PWD/empty-home" PATH="$PWD/no-systemd:$PATH"
  $ mkdir -p "$XDG_CONFIG_HOME" "$XDG_RUNTIME_DIR" "$XDG_STATE_HOME" "$HOME" "$PWD/no-systemd"
  $ tmp=$(mktemp -d /tmp/leash-l43-XXXXXX)
  $ case "$tmp" in /tmp/leash-l43-*) ;; *) exit 1;; esac
  $ trap 'rm -rf "${tmp:?}"' EXIT
  $ probe() { printf '%s\n' "$1" > "$tmp/state.fixture"; LEASH_INSTALL_FIXTURE="$tmp/state.fixture" leash status --socket "$tmp/missing.sock" >out 2>err; ./daily_cli_fixture.exe status-down "$2" out err; }

No unit and no binary, no unit with a binary still present, an inactive unit,
an auto-restart, and an active unit whose socket is dead.

  $ probe 'load=not-found
  > active=inactive
  > sub=dead
  > binary=absent' not-installed
  not-installed: unit=false binary=false hint=Leash is not installed; rebuild NixOS so leash.service exists, then `systemctl --user start leash`
  $ probe 'load=not-found
  > active=inactive
  > sub=dead
  > binary=present' not-installed
  not-installed: unit=false binary=true hint=Leash is not installed; rebuild NixOS so leash.service exists, then `systemctl --user start leash`
  $ probe 'load=loaded
  > active=inactive
  > sub=dead
  > binary=present' service-stopped
  service-stopped: unit=true binary=true hint=`systemctl --user start leash`, then `leash status`; a brief service-restarting (75) right after start is normal - retry; tabs and snapshots from before the stop are gone, so re-open them
  $ probe 'load=loaded
  > active=activating
  > sub=auto-restart
  > binary=present' service-restarting
  service-restarting: unit=true binary=true hint=Leash is restarting; retry `leash status` in a few seconds
  $ probe 'load=loaded
  > active=active
  > sub=running
  > binary=present' service-unreachable
  service-unreachable: unit=true binary=true hint=`systemctl --user start leash`, or pass --socket

A service whose Chrome generation is being relaunched is the same restarting
code, with the status fields in the error detail and no pid.

  $ cat > "$tmp/restart.json" <<'JSON'
  > {"version":"0.0.0","generation":4,"pid":99,"headed":true,"chrome":"restarting","tabs":{"open":0,"cap":8},"uptime_s":1.0,"models":null,"api_key":"sk-leash-status-secret"}
  > JSON
  $ rm -f "$tmp/ready"; ./daily_cli_fixture.exe serve-result "$tmp/control.sock" "$tmp/restart.json" "$tmp/ready" & pid=$!
  $ while test ! -f "$tmp/ready"; do kill -0 "$pid" 2>/dev/null || exit 1; sleep 0.01; done
  $ leash status --socket "$tmp/control.sock" >out 2>err
  [75]
  $ ./daily_cli_fixture.exe status-restart out err
  service-restarting: chrome generation relaunch, Leash is restarting; retry `leash status` in a few seconds
  $ wait "$pid"

A running service reports version, generation, pid, headed, key present and
skill, and never the key.

  $ cat > "$tmp/healthy.json" <<'JSON'
  > {"version":"0.0.0","generation":7,"pid":4242,"headed":true,"chrome":"running","tabs":{"open":1,"cap":8},"uptime_s":3.0,"models":{"configured":true,"decision_model":"typesafe/jev","text_model":"helper","systemone_endpoint":"https://openrouter.ai/api/v1/systemone","chat_base_url":"https://openrouter.ai/api/v1"},"OPENROUTER_API_KEY":"sk-leash-status-secret"}
  > JSON
  $ rm -f "$tmp/ready"; ./daily_cli_fixture.exe serve-result "$tmp/control.sock" "$tmp/healthy.json" "$tmp/ready" & pid=$!
  $ while test ! -f "$tmp/ready"; do kill -0 "$pid" 2>/dev/null || exit 1; sleep 0.01; done
  $ leash status --socket "$tmp/control.sock" >out 2>err
  $ ./daily_cli_fixture.exe status-healthy out err
  healthy: version 0.0.0 chrome running generation 7 pid 4242 headed key_present skill missing
  $ wait "$pid"
