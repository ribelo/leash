L51 offline durable commands: trace-o6ld, trace-dqr2, trace-szpg.

  $ export XDG_CONFIG_HOME="$PWD/config" XDG_STATE_HOME="$PWD/state" XDG_RUNTIME_DIR="$PWD/runtime"
  $ mkdir -p "$XDG_CONFIG_HOME/leash" "$XDG_STATE_HOME/leash/traces/example.com" "$XDG_STATE_HOME/leash/traces/other.com"
  $ printf '[traces.retention]\ncount = 1\ndays = 1\n' >"$XDG_CONFIG_HOME/leash/config.toml"
  $ trace() { printf '{"version":1,"time":"%s","site":"%s","mission":"%s","outcome":"%s","cost":null,"duration_ms":12,"model_calls":1,"page_kind_path":[],"compiled":%s,"procedures":[],"steps":[],"final":null}\n' "$1" "$2" "$3" "$4" "$5" >"$XDG_STATE_HOME/leash/traces/$2/$1-$4.json"; }
  $ trace 2000-01-01T00:00:00.000000Z example.com preserved done false
  $ trace 2000-01-02T00:00:00.000000Z example.com doomed error false
  $ trace 2000-01-03T00:00:00.000000Z other.com untouched error false

List is newest-first TSV with the six promised columns, and both filters work.

  $ leash traces list | awk -F '	' '{ print $2, $3, NF, $5, $6 }'
  other.com error 6 0 untouched
  example.com error 6 0 doomed
  example.com done 6 0 preserved
  $ leash traces list --site example.com --outcome done | awk -F '	' '{ print $2, $3, $6 }'
  example.com done preserved

Show uses the derived schema. A second rendering is stable JSON, not a service reply.

  $ f="$XDG_STATE_HOME/leash/traces/example.com/2000-01-01T00:00:00.000000Z-done.json"
  $ leash traces show "$f" >shown.json
  $ leash traces show shown.json >shown-again.json
  $ cmp shown.json shown-again.json
  $ test ! -e "$XDG_RUNTIME_DIR/leash"

Dry-run names deletion without deleting; real prune leaves uncompiled done and other sites.

  $ leash traces prune --site example.com --dry-run | sed "s|$XDG_STATE_HOME/||"
  leash/traces/example.com/2000-01-02T00:00:00.000000Z-error.json
  $ test -f "$XDG_STATE_HOME/leash/traces/example.com/2000-01-02T00:00:00.000000Z-error.json"
  $ leash traces prune --site example.com | sed "s|$XDG_STATE_HOME/||"
  leash/traces/example.com/2000-01-02T00:00:00.000000Z-error.json
  $ test -f "$f"
  $ test -f "$XDG_STATE_HOME/leash/traces/other.com/2000-01-03T00:00:00.000000Z-error.json"

Unsafe filters and malformed files fail offline with data-error 65.

  $ leash traces list --site ../escape
  trace error: invalid site filter
  [65]
  $ printf '{' >broken.json
  $ leash traces show broken.json >out 2>err; status=$?; test "$status" -eq 65 && test ! -s out && test -s err
  $ test ! -e "$XDG_RUNTIME_DIR/leash"
