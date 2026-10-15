daily-c4cl / daily-9ggi: CLI acceptance fixes are proved against private files
and a one-request socket peer, never the installed service or managed Chrome.

  $ unset LEASH_INSTALL_FIXTURE
  $ export XDG_CONFIG_HOME="$PWD/config" XDG_RUNTIME_DIR="$PWD/runtime" XDG_STATE_HOME="$PWD/state" HOME="$PWD/home"
  $ mkdir -p "$XDG_CONFIG_HOME" "$XDG_RUNTIME_DIR" "$XDG_STATE_HOME" "$HOME"
  $ tmp=$(mktemp -d /tmp/leash-daily-c4cl-XXXXXX)
  $ case "$tmp" in /tmp/leash-daily-c4cl-*) ;; *) exit 1;; esac
  $ trap 'rm -rf "${tmp:?}"' EXIT

Press help states its vocabulary rather than accepting the plausible but invalid
Return alias. The root help no longer suggests an Allegro purchase.

  $ help=$(leash press --help=plain); case "$help" in *'Accepted names: Enter,'*ArrowLeft*'lowercase a-z,'*'digits 0-9,'*) printf 'press vocabulary documented\n';; *) exit 1;; esac
  press vocabulary documented
  $ case "$help" in *Return*) exit 1;; *) printf 'unsupported Return absent\n';; esac
  unsupported Return absent
  $ root_help=$(leash --help=plain); case "$root_help" in *Allegro*|*allegro*) exit 1;; *) printf 'purchase example absent\n';; esac
  purchase example absent

Status, ordinary tab clients, and the eval --file exchange route (evl-gign)
all distinguish the same unreachable service states.

  $ printf '%s\n' 'return {title: document.title};' > "$tmp/probe.js"
  $ client() { expected="$1"; shift; LEASH_INSTALL_FIXTURE="$tmp/service.fixture" leash "$@" --socket "$tmp/missing.sock" >out 2>err; code=$?; ./daily_cli_fixture.exe inspect "$expected" "$code" out err >/dev/null; }
  $ routes() { client "$1" status && client "$1" list && client "$1" net t_9xk && client "$1" eval t_9xk --file "$tmp/probe.js" && printf '%s: all four client routes\n' "$1"; }
  $ printf 'load=not-found\nactive=inactive\nsub=dead\nbinary=absent\n' > "$tmp/service.fixture"; routes not-installed
  not-installed: all four client routes
  $ printf 'load=not-found\nactive=inactive\nsub=dead\nbinary=present\n' > "$tmp/service.fixture"; routes not-installed
  not-installed: all four client routes
  $ printf 'load=loaded\nactive=inactive\nsub=dead\nbinary=present\n' > "$tmp/service.fixture"; routes service-stopped
  service-stopped: all four client routes
  $ printf 'load=loaded\nactive=activating\nsub=auto-restart\nbinary=present\n' > "$tmp/service.fixture"; routes service-restarting
  service-restarting: all four client routes
  $ printf 'load=loaded\nactive=active\nsub=running\nbinary=present\n' > "$tmp/service.fixture"; routes service-unreachable
  service-unreachable: all four client routes

hand-scaz / hand-w85z: a leftover caller flag is a parse failure, not an
ignored option. This transcript deliberately tries the removed spelling.

  $ leash traces list --owner gone >rejected 2>err; code=$?; test "$code" -eq 124 && test ! -s rejected && printf 'traces list rejects a caller flag\n'
  traces list rejects a caller flag

Configured nested roots drive install and status; explicit PATH still wins and
automatic consent is not granted for a configured target.

  $ printf '[skill]\nroots = ["~/.dotfiles/skills/engineering/browser"]\n' > "$tmp/config.toml"
  $ root="$HOME/.dotfiles/skills/engineering/browser"
  $ outcome() { expected="$1"; path="$2"; shift 2; "$@" >out 2>err && ./daily_cli_fixture.exe skill-outcome "$expected" "$path" out err; }
  $ outcome planned-install "$root/leash" leash skill install --config "$tmp/config.toml" --dry-run
  planned-install: one JSON outcome, empty stderr
  $ test ! -e "$root"
  $ leash skill install --config "$tmp/config.toml" --no-input >out 2>err; code=$?; ./daily_cli_fixture.exe inspect usage "$code" out err
  usage: exit 64, JSON-only stderr, hint, empty stdout
  $ outcome installed "$root/leash" leash skill install --config "$tmp/config.toml" --force
  installed: one JSON outcome, empty stderr
  $ test -f "$root/leash/SKILL.md" && test ! -e "$HOME/.agents/skills/leash"
  $ ./daily_cli_fixture.exe serve "$tmp/control.sock" success "$tmp/ready" & peer=$!; while test ! -f "$tmp/ready"; do :; done; leash status --config "$tmp/config.toml" --socket "$tmp/control.sock" >out 2>err; code=$?; wait "$peer"; test "$code" -eq 0 && ./daily_cli_fixture.exe status-skill current out err
  status: skill current, running version and commit, service fields retained
  $ outcome planned-install "$HOME/explicit/leash" leash skill install "$HOME/explicit" --config "$tmp/config.toml" --dry-run
  planned-install: one JSON outcome, empty stderr
