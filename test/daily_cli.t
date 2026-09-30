Daily CLI failures are exactly one structured record; the helper checks the whole
stderr stream, the canonical class, a one-line hint, and empty stdout.

  $ unset DSH_SESSION_ID
  $ export XDG_CONFIG_HOME="$PWD/config" XDG_RUNTIME_DIR="$PWD/runtime" XDG_STATE_HOME="$PWD/state"
  $ mkdir -p "$XDG_CONFIG_HOME" "$XDG_RUNTIME_DIR" "$XDG_STATE_HOME"
  $ tmp=$(mktemp -d /tmp/leash-l41-XXXXXX)
  $ case "$tmp" in /tmp/leash-l41-*) ;; *) exit 1;; esac
  $ trap 'chmod 700 "$tmp/denied" 2>/dev/null; rm -rf "${tmp:?}"' EXIT
  $ check() { expected="$1"; shift; "$@" >out 2>err; status=$?; ./daily_cli_fixture.exe inspect "$expected" "$status" out err; }

Service down, permission denied, usage, invalid request, and Cmdliner parsing all
use that same client envelope, including --pretty.

  $ check service-unreachable leash status --owner test --socket "$tmp/missing.sock" --pretty
  service-unreachable: exit 69, JSON-only stderr, hint, empty stdout
  $ mkdir "$tmp/denied"; chmod 000 "$tmp/denied"
  $ check socket-permission leash status --owner test --socket "$tmp/denied/control.sock"
  socket-permission: exit 77, JSON-only stderr, hint, empty stdout
  $ chmod 700 "$tmp/denied"
  $ check usage leash status --socket "$tmp/missing.sock"
  usage: exit 64, JSON-only stderr, hint, empty stdout
  $ check usage leash status --owner '   ' --socket "$tmp/missing.sock"
  usage: exit 64, JSON-only stderr, hint, empty stdout
  $ check cli-parse leash snap --owner test
  cli-parse: exit 124, JSON-only stderr, hint, empty stdout
  $ check cli-parse leash status --bogus
  cli-parse: exit 124, JSON-only stderr, hint, empty stdout
  $ check cli-parse leash definitely-not-a-command
  cli-parse: exit 124, JSON-only stderr, hint, empty stdout

Configuration writes preserve successful output and classify local permissions.

  $ leash config init --config "$tmp/default.toml" >out 2>err
  $ ./daily_cli_fixture.exe inspect-init "$tmp/default.toml" out err
  config init writes its path and empty stderr
  $ check usage leash config init --config "$tmp/default.toml"
  usage: exit 64, JSON-only stderr, hint, empty stdout
  $ chmod 000 "$tmp/denied"
  $ check permission-denied leash config init --config "$tmp/denied/config.toml"
  permission-denied: exit 77, JSON-only stderr, hint, empty stdout
  $ chmod 700 "$tmp/denied"
  $ printf 'blocking file\n' > "$tmp/as-file"
  $ check internal leash config init --config "$tmp/as-file/config.toml"
  internal: exit 70, JSON-only stderr, hint, empty stdout

Configuration parse, explicit missing file and semantic validation failures are
classified. Aggregate field/path checks are also asserted below.

  $ printf 'broken = [\n' > "$tmp/broken.toml"
  $ check config-invalid leash config check --config "$tmp/broken.toml"
  config-invalid: exit 65, JSON-only stderr, hint, empty stdout
  $ check config-invalid leash config check --config "$tmp/missing.toml"
  config-invalid: exit 65, JSON-only stderr, hint, empty stdout
  $ printf '[chrome]\nheadless = "wrong"\n[expiry]\nidle_s = -1\n[control]\nsocket = "relative.sock"\n[tabs]\ncap = 0\n' > "$tmp/invalid.toml"
  $ check config-invalid leash config check --config "$tmp/invalid.toml"
  config-invalid: exit 65, JSON-only stderr, hint, empty stdout
  $ ./daily_cli_fixture.exe config-details "$tmp/invalid.toml" err
  config path and all four problems are present

Local authoring errors also use the envelope; no service is contacted.

  $ check script-invalid leash playbook check "$tmp/missing/"
  script-invalid: exit 65, JSON-only stderr, hint, empty stdout
  $ printf 'not json\n' > "$tmp/proposal.json"
  $ check script-invalid leash playbook accept "$tmp/proposal.json"
  script-invalid: exit 65, JSON-only stderr, hint, empty stdout
  $ check usage leash help nonsense
  usage: exit 64, JSON-only stderr, hint, empty stdout

Every service failure class, including a malformed peer, takes the same stderr
boundary. The peer is local and private; it has no Chrome dependency.

  $ peer() { code="$1"; expected="${2:-$code}"; rm -f "$tmp/ready"; ./daily_cli_fixture.exe serve "$tmp/control.sock" "$code" "$tmp/ready" & pid=$!; while test ! -f "$tmp/ready"; do kill -0 "$pid" 2>/dev/null || return 1; sleep 0.01; done; check "$expected" leash snap t_fixture --owner test --socket "$tmp/control.sock" --pretty; wait "$pid"; }
  $ peer invalid-request
  invalid-request: exit 64, JSON-only stderr, hint, empty stdout
  $ peer stale-snapshot
  stale-snapshot: exit 65, JSON-only stderr, hint, empty stdout
  $ peer unknown-tab
  unknown-tab: exit 66, JSON-only stderr, hint, empty stdout
  $ peer browser-unavailable
  browser-unavailable: exit 69, JSON-only stderr, hint, empty stdout
  $ peer model-unavailable
  model-unavailable: exit 69, JSON-only stderr, hint, empty stdout
  $ peer internal
  internal: exit 70, JSON-only stderr, hint, empty stdout
  $ peer invalid-response
  invalid-response: exit 70, JSON-only stderr, hint, empty stdout
  $ peer invalid-envelope invalid-response
  invalid-response: exit 70, JSON-only stderr, hint, empty stdout
  $ peer timeout
  timeout: exit 75, JSON-only stderr, hint, empty stdout
  $ peer tab-cap
  tab-cap: exit 75, JSON-only stderr, hint, empty stdout
  $ peer not-owner
  not-owner: exit 77, JSON-only stderr, hint, empty stdout
  $ peer with-human
  with-human: exit 77, JSON-only stderr, hint, empty stdout
  $ peer already-owned
  already-owned: exit 77, JSON-only stderr, hint, empty stdout

Success still emits its unwrapped compact result, and never writes stderr.

  $ rm -f "$tmp/ready"; ./daily_cli_fixture.exe serve "$tmp/control.sock" success "$tmp/ready" & pid=$!
  $ while test ! -f "$tmp/ready"; do kill -0 "$pid" 2>/dev/null || exit 1; sleep 0.01; done
  $ HOME="$tmp/empty-home" leash status --owner test --socket "$tmp/control.sock" >out 2>err
  $ ./daily_cli_fixture.exe status-skill missing out err
  status: skill missing, running version and commit, service fields retained
  $ wait "$pid"; test ! -s err
