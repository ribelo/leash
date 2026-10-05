Daily CLI failures are exactly one structured record; the helper checks the whole
stderr stream, the canonical class, a one-line hint, and empty stdout.

  $ export XDG_CONFIG_HOME="$PWD/config" XDG_RUNTIME_DIR="$PWD/runtime" XDG_STATE_HOME="$PWD/state"
  $ mkdir -p "$XDG_CONFIG_HOME" "$XDG_RUNTIME_DIR" "$XDG_STATE_HOME"
  $ tmp=$(mktemp -d /tmp/leash-l41-XXXXXX)
  $ case "$tmp" in /tmp/leash-l41-*) ;; *) exit 1;; esac
  $ trap 'chmod 700 "$tmp/denied" 2>/dev/null; rm -rf "${tmp:?}"' EXIT
  $ check() { expected="$1"; shift; "$@" >out 2>err; status=$?; ./daily_cli_fixture.exe inspect "$expected" "$status" out err; }

hand-scaz / hand-w85z: service down, permission denied, usage, invalid request,
and Cmdliner parsing use that same client envelope, including --pretty. The
removed caller flag below must be rejected rather than silently ignored.

  $ printf 'load=loaded\nactive=active\nsub=running\nbinary=present\n' > "$tmp/active.fixture"
  $ LEASH_INSTALL_FIXTURE="$tmp/active.fixture" check service-unreachable leash status --socket "$tmp/missing.sock" --pretty
  service-unreachable: exit 69, JSON-only stderr, hint, empty stdout
  $ mkdir "$tmp/denied"; chmod 000 "$tmp/denied"
  $ check socket-permission leash status --socket "$tmp/denied/control.sock"
  socket-permission: exit 77, JSON-only stderr, hint, empty stdout
  $ chmod 700 "$tmp/denied"
  $ check cli-parse leash status --owner gone --socket "$tmp/missing.sock"
  cli-parse: exit 124, JSON-only stderr, hint, empty stdout
  $ check cli-parse leash claim t_dead
  cli-parse: exit 124, JSON-only stderr, hint, empty stdout
  $ check cli-parse leash release t_dead
  cli-parse: exit 124, JSON-only stderr, hint, empty stdout
  $ check usage leash snap
  usage: exit 64, JSON-only stderr, hint, empty stdout
  $ leash click t_9xk >out 2>err; test $? -eq 64
  $ grep -q 'click: SNAPSHOT is missing; usage: click TAB SNAPSHOT INDEX' err
  $ leash click t_9xk '' 7 >out 2>err; test $? -eq 64
  $ grep -q 'SNAPSHOT is missing' err
  $ printf 's3cret-field-5sdo' | leash fill t_9xk s_1 1 --stdin --socket "$tmp/missing.sock" >out 2>err; test $? -ne 0
  $ grep -q 's3cret-field-5sdo' out err && exit 1 || true
  $ printf '%65537s' x > "$tmp/big-fill"
  $ check too-large leash fill t_9xk s_1 1 --argument-file "$tmp/big-fill" --socket "$tmp/missing.sock"
  too-large: exit 65, JSON-only stderr, hint, empty stdout
  $ check cli-parse leash status --bogus
  cli-parse: exit 124, JSON-only stderr, hint, empty stdout
  $ check cli-parse leash definitely-not-a-command
  cli-parse: exit 124, JSON-only stderr, hint, empty stdout

pic-egvj pic-f2hy pic-33hm: picture syntax reaches the socket without row arguments;
malformed or mixed syntax and oversized protected text fail locally.

  $ LEASH_INSTALL_FIXTURE="$tmp/active.fixture" check service-unreachable leash snap t_9xk --with-image --socket "$tmp/missing.sock"
  service-unreachable: exit 69, JSON-only stderr, hint, empty stdout
  $ LEASH_INSTALL_FIXTURE="$tmp/active.fixture" check service-unreachable leash click t_9xk --at 10.25,20.5 --socket "$tmp/missing.sock"
  service-unreachable: exit 69, JSON-only stderr, hint, empty stdout
  $ LEASH_INSTALL_FIXTURE="$tmp/active.fixture" check service-unreachable leash dblclick t_9xk --at 10,20 --shot --socket "$tmp/missing.sock"
  service-unreachable: exit 69, JSON-only stderr, hint, empty stdout
  $ LEASH_INSTALL_FIXTURE="$tmp/active.fixture" check service-unreachable leash scroll t_9xk --at 10,20 --dy=-120 --socket "$tmp/missing.sock"
  service-unreachable: exit 69, JSON-only stderr, hint, empty stdout
  $ LEASH_INSTALL_FIXTURE="$tmp/active.fixture" check service-unreachable leash drag t_9xk --from 10,20 --to 40,50 --socket "$tmp/missing.sock"
  service-unreachable: exit 69, JSON-only stderr, hint, empty stdout
  $ check cli-parse leash click t_9xk --at NaN,20 --socket "$tmp/missing.sock"
  cli-parse: exit 124, JSON-only stderr, hint, empty stdout
  $ check cli-parse leash scroll t_9xk --at 10,20 --dy inf --socket "$tmp/missing.sock"
  cli-parse: exit 124, JSON-only stderr, hint, empty stdout
  $ check usage leash click t_9xk s_1 1 --at 10,20 --socket "$tmp/missing.sock"
  usage: exit 64, JSON-only stderr, hint, empty stdout
  $ check usage leash scroll t_9xk --at 10,20 --socket "$tmp/missing.sock"
  usage: exit 64, JSON-only stderr, hint, empty stdout
  $ check too-large leash type t_9xk --argument-file "$tmp/big-fill" --socket "$tmp/missing.sock"
  too-large: exit 65, JSON-only stderr, hint, empty stdout
  $ printf 's3cret-pic-33hm' | leash type t_9xk --stdin --socket "$tmp/missing.sock" >out 2>err; test $? -ne 0
  $ grep -q 's3cret-pic-33hm' out err && exit 1 || true

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

Local errors also use the envelope; no service is contacted.

  $ check usage leash help nonsense
  usage: exit 64, JSON-only stderr, hint, empty stdout

Every service failure class, including a malformed peer, takes the same stderr
boundary. The peer is local and private; it has no Chrome dependency.

  $ peer() { code="$1"; expected="${2:-$code}"; rm -f "$tmp/ready"; ./daily_cli_fixture.exe serve "$tmp/control.sock" "$code" "$tmp/ready" & pid=$!; while test ! -f "$tmp/ready"; do kill -0 "$pid" 2>/dev/null || return 1; sleep 0.01; done; check "$expected" leash snap t_fixture --socket "$tmp/control.sock" --pretty; wait "$pid"; }
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
  $ peer ambiguous
  ambiguous: exit 66, JSON-only stderr, hint, empty stdout
  $ peer no-match
  no-match: exit 66, JSON-only stderr, hint, empty stdout
  $ peer taken
  taken: exit 77, JSON-only stderr, hint, empty stdout
  $ peer with-human
  with-human: exit 77, JSON-only stderr, hint, empty stdout

Success still emits its unwrapped compact result, and never writes stderr.

  $ rm -f "$tmp/ready"; ./daily_cli_fixture.exe serve "$tmp/control.sock" success "$tmp/ready" & pid=$!
  $ while test ! -f "$tmp/ready"; do kill -0 "$pid" 2>/dev/null || exit 1; sleep 0.01; done
  $ HOME="$tmp/empty-home" leash status --socket "$tmp/control.sock" >out 2>err
  $ ./daily_cli_fixture.exe status-skill missing out err
  status: skill missing, running version and commit, service fields retained
  $ wait "$pid"; test ! -s err

hand-scaz: an old harness variable cannot become a protocol identity.

  $ rm -f "$tmp/ready" "$tmp/control.sock"
  $ ./daily_cli_fixture.exe capture "$tmp/control.sock" "$tmp/request" "$tmp/ready" & pid=$!
  $ while test ! -f "$tmp/ready"; do kill -0 "$pid" 2>/dev/null || exit 1; sleep 0.01; done
  $ DSH_SESSION_ID=legacy leash status --socket "$tmp/control.sock" >out 2>err
  $ wait "$pid"; test ! -s err
  $ ./daily_cli_fixture.exe anonymous-request "$tmp/request"
  hand-scaz only v, cmd and args, even in a harness environment
