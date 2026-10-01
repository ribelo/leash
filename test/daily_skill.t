L42 local bundle operations use neither a service nor a tab handle. Installation
preserves modified bundles until consent, and dry-run has no filesystem effects.

  $ tmp=$(mktemp -d /tmp/leash-l42-XXXXXX)
  $ case "$tmp" in /tmp/leash-l42-*) ;; *) exit 1;; esac
  $ trap 'chmod -R u+rwx "${tmp:?}"; rm -rf "${tmp:?}"' EXIT
  $ export HOME="$tmp/home" XDG_CONFIG_HOME="$tmp/config" XDG_RUNTIME_DIR="$tmp/runtime"
  $ mkdir -p "$HOME/.agents" "$XDG_RUNTIME_DIR"
  $ outcome() { action="$1"; path="$2"; shift 2; "$@" >out 2>err && ./daily_cli_fixture.exe skill-outcome "$action" "$path" out err; }
  $ check() { expected="$1"; shift; "$@" >out 2>err; status=$?; ./daily_cli_fixture.exe inspect "$expected" "$status" out err; }
  $ leash skill show >show 2>err
  $ ./daily_cli_fixture.exe skill-show show err
  show: exact bundled entrypoint, YAML version and commit stamp, empty stderr
  $ outcome planned-install "$tmp/explicit/leash" leash skill install "$tmp/explicit" --dry-run
  planned-install: one JSON outcome, empty stderr
  $ test ! -e "$tmp/explicit"
  $ outcome installed "$tmp/explicit/leash" leash skill install "$tmp/explicit"
  installed: one JSON outcome, empty stderr
  $ cmp show "$tmp/explicit/leash/SKILL.md"
  $ test -d "$tmp/explicit/leash/references"
  $ outcome current "$tmp/explicit/leash" leash skill install "$tmp/explicit" --no-input
  current: one JSON outcome, empty stderr
  $ printf '\nlocal modification\n' >>"$tmp/explicit/leash/SKILL.md"
  $ cp "$tmp/explicit/leash/SKILL.md" modified
  $ check usage leash skill install "$tmp/explicit" --no-input
  usage: exit 64, JSON-only stderr, hint, empty stdout
  $ cmp modified "$tmp/explicit/leash/SKILL.md"
  $ outcome planned-replace "$tmp/explicit/leash" leash skill install "$tmp/explicit" --dry-run
  planned-replace: one JSON outcome, empty stderr
  $ cmp modified "$tmp/explicit/leash/SKILL.md"
  $ outcome replaced "$tmp/explicit/leash" leash skill install "$tmp/explicit" --force
  replaced: one JSON outcome, empty stderr
  $ cmp show "$tmp/explicit/leash/SKILL.md"
  $ test "$(ls -A "$tmp/explicit" | wc -l)" -eq 1
  $ check usage leash skill install '' --force
  usage: exit 64, JSON-only stderr, hint, empty stdout
  $ mkdir "$tmp/denied"; chmod 000 "$tmp/denied"
  $ check permission-denied leash skill install "$tmp/denied" --force
  permission-denied: exit 77, JSON-only stderr, hint, empty stdout
  $ chmod 700 "$tmp/denied"

Default discovery is Nema's, including automatic consent. Status keeps the service
result and inspects discovered roots: missing, current, changed commit, missing
stamp, modified contents (even with a matching stamp), and force repair.

  $ outcome planned-install "$HOME/.agents/skills/leash" leash skill install --dry-run
  planned-install: one JSON outcome, empty stderr
  $ test ! -e "$HOME/.agents/skills"
  $ check usage leash skill install --no-input
  usage: exit 64, JSON-only stderr, hint, empty stdout
  $ status_skill() { expected="$1"; rm -f "$tmp/ready"; ./daily_cli_fixture.exe serve "$tmp/control.sock" success "$tmp/ready" & peer=$!; while test ! -f "$tmp/ready"; do :; done; leash status --socket "$tmp/control.sock" >out 2>err; code=$?; wait "$peer"; test "$code" -eq 0 && ./daily_cli_fixture.exe status-skill "$expected" out err; }
  $ status_skill missing
  status: skill missing, running version and commit, service fields retained
  $ outcome installed "$HOME/.agents/skills/leash" leash skill install --force
  installed: one JSON outcome, empty stderr
  $ status_skill current
  status: skill current, running version and commit, service fields retained
  $ sed -i 's/leash-commit: .*/leash-commit: "old-commit"/' "$HOME/.agents/skills/leash/SKILL.md"
  $ status_skill stale
  status: skill stale, running version and commit, service fields retained
  $ outcome replaced "$HOME/.agents/skills/leash" leash skill install --force
  replaced: one JSON outcome, empty stderr
  $ sed -i '/leash-version:/d; /leash-commit:/d' "$HOME/.agents/skills/leash/SKILL.md"
  $ status_skill stale
  status: skill stale, running version and commit, service fields retained
  $ outcome replaced "$HOME/.agents/skills/leash" leash skill install --force
  replaced: one JSON outcome, empty stderr
  $ mkdir "$HOME/.codex"
  $ status_skill current
  status: skill current, running version and commit, service fields retained
  $ outcome installed "$HOME/.codex/skills/leash" leash skill install "$HOME/.codex/skills"
  installed: one JSON outcome, empty stderr
  $ printf '\nlocal modification\n' >>"$HOME/.agents/skills/leash/references/errors.md"
  $ status_skill stale
  status: skill stale, running version and commit, service fields retained
  $ outcome replaced "$HOME/.agents/skills/leash" leash skill install "$HOME/.agents/skills" --force
  replaced: one JSON outcome, empty stderr
  $ status_skill current
  status: skill current, running version and commit, service fields retained
