Drive flags and help are offline until a valid request is encoded (fly-nolf
fly-hc3l fly-b6yt fly-mqkr).

  $ export XDG_CONFIG_HOME="$PWD/config" XDG_RUNTIME_DIR="$PWD/runtime"
  $ mkdir -p "$XDG_CONFIG_HOME" "$XDG_RUNTIME_DIR"
  $ tmp=$(mktemp -d /tmp/leash-l45c-XXXXXX)
  $ case "$tmp" in /tmp/leash-l45c-*) ;; *) exit 1;; esac
  $ trap 'rm -rf "${tmp:?}"' EXIT
  $ check() { expected="$1"; shift; "$@" >out 2>err; status=$?; ./daily_cli_fixture.exe inspect "$expected" "$status" out err; }

Help names both routes, the four playbook cases, and an operator-state example.

  $ leash drive --help=plain >help 2>err
  $ test ! -s err
  $ ./daily_cli_fixture.exe drive-help help
  drive help: both routes, four playbook cases, operator-state example

Zero, negative, and a non-http start fail as usage before any socket connect.
A negative value uses the sticky form: Cmdliner treats a spaced -1 as an option.
A non-integer is still a parse failure. The message names a correct example.

  $ check usage leash drive 'Open the page' --max-steps 0 --socket "$tmp/missing.sock"
  usage: exit 64, JSON-only stderr, hint, empty stdout
  $ grep -q -- '--max-steps 60' err && printf 'max-steps usage names an example\n'
  max-steps usage names an example
  $ check usage leash drive 'Open the page' --max-steps=-1 --socket "$tmp/missing.sock"
  usage: exit 64, JSON-only stderr, hint, empty stdout
  $ check usage leash drive 'Open the page' --url 'javascript:alert(1)' --socket "$tmp/missing.sock"
  usage: exit 64, JSON-only stderr, hint, empty stdout
  $ grep -q 'https://books.toscrape.com/' err && printf 'url usage names an example\n'
  url usage names an example
  $ check usage leash drive 'Open the page' --url 'about:blank' --socket "$tmp/missing.sock"
  usage: exit 64, JSON-only stderr, hint, empty stdout
  $ check usage leash drive 'Open the page' --url 'http://user@example.com/' --socket "$tmp/missing.sock"
  usage: exit 64, JSON-only stderr, hint, empty stdout
  $ check cli-parse leash drive 'Open the page' --max-steps no
  cli-parse: exit 124, JSON-only stderr, hint, empty stdout

A valid --url becomes start_url. --max-steps is sent only when given. The wire
key is never url.

  $ rm -f "$tmp/ready" "$tmp/request" "$tmp/control.sock"
  $ ./daily_cli_fixture.exe capture "$tmp/control.sock" "$tmp/request" "$tmp/ready" & pid=$!
  $ while test ! -f "$tmp/ready"; do kill -0 "$pid" 2>/dev/null || exit 1; sleep 0.01; done
  $ timeout 15 leash drive 'Open Travel' --url https://books.toscrape.com/ --max-steps 12 --out "$tmp/out.jsonl" --socket "$tmp/control.sock" >out 2>err
  $ test ! -s err
  $ wait "$pid"
  $ ./daily_cli_fixture.exe drive-request "$tmp/request"
  mission=Open Travel start_url=https://books.toscrape.com/ max_steps=12 tab=absent out=present
  $ rm -f "$tmp/ready" "$tmp/request" "$tmp/control.sock"
  $ ./daily_cli_fixture.exe capture "$tmp/control.sock" "$tmp/request" "$tmp/ready" & pid=$!
  $ while test ! -f "$tmp/ready"; do kill -0 "$pid" 2>/dev/null || exit 1; sleep 0.01; done
  $ timeout 15 leash drive 'Open Travel' --tab t_9xk --socket "$tmp/control.sock" >out 2>err
  $ test ! -s err
  $ wait "$pid"
  $ ./daily_cli_fixture.exe drive-request "$tmp/request"
  mission=Open Travel start_url=absent max_steps=absent tab=t_9xk out=absent
