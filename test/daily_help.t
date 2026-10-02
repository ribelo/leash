Help is offline and short first contact is not the full manual.

  $ export XDG_CONFIG_HOME="$PWD/config" XDG_RUNTIME_DIR="$PWD/runtime" XDG_DATA_HOME="$PWD/data" XDG_STATE_HOME="$PWD/state"
  $ mkdir -p "$XDG_CONFIG_HOME" "$XDG_RUNTIME_DIR" "$XDG_DATA_HOME" "$XDG_STATE_HOME"
  $ test ! -S "$XDG_RUNTIME_DIR/leash/control.sock"
  $ leash >orient 2>err
  $ test ! -s err
  $ test "$(wc -l <orient)" -eq 1
  $ grep -q 'leash new returns a handle you must keep' orient
  $ grep -q 'agent tabs close after 30 idle minutes; human tabs are never closed unless an agent takes one' orient
  $ grep -q 'OPENROUTER_API_KEY in the service'\''s environment or models.api_key in the config' orient
  $ grep -q "the key is the operator's" orient
  $ grep -q 'OpenRouter' orient
  $ grep -q 'Prefer leash drive MISSION for a goal: it learns; manual commands do not' orient
  $ grep -q 'Start with leash status and leash help drive' orient
  $ printf 'bare leash is one paragraph and does not need the service\n'
  bare leash is one paragraph and does not need the service
  $ leash --help=plain >help 2>err
  $ test "$(grep -c '^[ ]*discover[ ]' help)" -eq 0
  $ ./daily_cli_fixture.exe top-help help; test ! -s err
  top-level help groups tabs, observe, act, network/debug, missions, playbooks, service and skill
  $ for cmd in new downloads list take close status snap text shot debug eval nav click fill press select scroll wait upload hover check uncheck net cookies storage dialog handoff resume drive playbook traces serve config skill help; do leash "$cmd" --help=plain >help 2>err && ./daily_cli_fixture.exe check-help help && ./daily_cli_fixture.exe option-docs help && test ! -s err || exit 1; done
  $ for cmd in list show check test accept; do leash playbook "$cmd" --help=plain >help 2>err && ./daily_cli_fixture.exe check-help help && ./daily_cli_fixture.exe option-docs help && test ! -s err || exit 1; done
  $ for cmd in list show prune; do leash traces "$cmd" --help=plain >help 2>err && ./daily_cli_fixture.exe check-help help && ./daily_cli_fixture.exe option-docs help && test ! -s err || exit 1; done
  $ for cmd in install show; do leash skill "$cmd" --help=plain >help 2>err && ./daily_cli_fixture.exe check-help help && ./daily_cli_fixture.exe option-docs help && test ! -s err || exit 1; done
  $ for cmd in init check; do leash config "$cmd" --help=plain >help 2>err && ./daily_cli_fixture.exe check-help help && ./daily_cli_fixture.exe option-docs help && test ! -s err || exit 1; done
  $ printf 'every command has examples and exit-status help\n'
  every command has examples and exit-status help
  $ leash list --help=plain >help 2>err
  $ ./daily_cli_fixture.exe list-help help; test ! -s err
  hand-3v5u list help states the tab rule and never shows handles
  $ leash help >topics 2>err; test ! -s err
  $ ./daily_cli_fixture.exe help-topics topics; test ! -s err
  help lists handles, playbooks, authoring, expectations, drive, scripts, errors, traces
  $ leash help handles >handles 2>err; test ! -s err
  $ grep -q 'agent tabs close after 30 idle minutes; human tabs are never closed unless an agent takes one' handles
  $ leash help errors >errors 2>err
  $ ./daily_cli_fixture.exe error-help errors; test ! -s err
  all 38 error codes, exit classes, meanings and hints are discoverable
  $ leash playbook --help=plain >playbook-help 2>err; test ! -s err
  $ grep -q 'A playbook is a directory that describes one site: pages, procedures, and scripts.' playbook-help
  $ grep -q 'The operator writes it. A model never does. JEV follows it when a mission fits.' playbook-help
  $ grep -q 'Format, example, and every loader refusal: leash help playbooks' playbook-help
  $ leash drive --help=plain >drive-help 2>err; test ! -s err
  $ grep -q 'Drive runs one mission on one tab until done, blocked, a cap, a deadline, or an error.' drive-help
  $ grep -q 'It may follow an installed playbook or act on the page. Leash never asserts the goal.' drive-help
  $ grep -q 'Lanes, options, and how to read a trace: leash help drive' drive-help
  $ ./daily_cli_fixture.exe option-docs help

hdoc-vqj7: required press snapshot, playbook groups, and actionable help.
  $ leash press --help=plain >press-help 2>err; test ! -s err
  $ grep -q 'leash press.*TAB SNAPSHOT KEY' press-help
  $ leash playbook --help=plain >playbook-help 2>err; test ! -s err
  $ for section in "INSTALLED PLAYBOOKS" "VALIDATION" "AUTHORING"; do grep -q "$section" playbook-help || exit 1; done
  $ test "$(grep -c '^ACT$' playbook-help)" -eq 0
  $ leash eval --help=plain >eval-help 2>err; test ! -s err
  $ grep -q 'returned promise is awaited' eval-help
  $ grep -q 'top-level await' eval-help
  $ leash snap --help=plain >snap-help 2>err; test ! -s err
  $ grep -q 'omits the snapshot id' snap-help
