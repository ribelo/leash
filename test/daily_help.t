Help is offline and short first contact is not the full manual.

  $ export XDG_CONFIG_HOME="$PWD/config" XDG_RUNTIME_DIR="$PWD/runtime" XDG_DATA_HOME="$PWD/data" XDG_STATE_HOME="$PWD/state"
  $ mkdir -p "$XDG_CONFIG_HOME" "$XDG_RUNTIME_DIR" "$XDG_DATA_HOME" "$XDG_STATE_HOME"
  $ leash 2>err
  Leash: local managed Chrome for agents.
  Service: unreachable
  Start: systemctl --user start leash
  Begin: leash status; leash new https://example.com; leash snap TAB
  agent tabs close after 30 idle minutes; human tabs are never closed unless an agent takes one
  Help: leash --help; leash COMMAND --help; leash help errors
  $ test ! -s err
  $ leash --help=plain >help 2>err
  $ ./daily_cli_fixture.exe top-help help; test ! -s err
  top-level help groups tabs, observe, act, network/debug, missions, playbooks, service and skill
  $ for cmd in new downloads list take close status snap text shot debug eval nav click fill press select scroll wait upload hover check uncheck net cookies storage dialog handoff resume drive discover playbook serve config skill help; do leash "$cmd" --help=plain >help 2>err && ./daily_cli_fixture.exe check-help help && test ! -s err || exit 1; done
  $ for cmd in list show check test accept; do leash playbook "$cmd" --help=plain >help 2>err && ./daily_cli_fixture.exe check-help help && test ! -s err || exit 1; done
  $ for cmd in install show; do leash skill "$cmd" --help=plain >help 2>err && ./daily_cli_fixture.exe check-help help && test ! -s err || exit 1; done
  $ for cmd in init check; do leash config "$cmd" --help=plain >help 2>err && ./daily_cli_fixture.exe check-help help && test ! -s err || exit 1; done
  $ printf 'every command has examples and exit-status help\n'
  every command has examples and exit-status help
  $ leash list --help=plain >help 2>err
  $ ./daily_cli_fixture.exe list-help help; test ! -s err
  hand-3v5u list help states the tab rule and never shows handles
  $ leash help handles >handles 2>err; test ! -s err
  $ grep -q 'agent tabs close after 30 idle minutes; human tabs are never closed unless an agent takes one' handles
  $ leash help errors >errors 2>err
  $ ./daily_cli_fixture.exe error-help errors; test ! -s err
  all 38 error codes, exit classes, meanings and hints are discoverable
