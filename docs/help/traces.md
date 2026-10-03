# Traces

Every public drive outcome is kept by default, including blocked, exhausted,
error, handed-off, and failed drives, in playbook and on-the-fly lanes.

```text
$XDG_STATE_HOME/leash/traces/<site>/<UTC timestamp>-<outcome>.json
```

The fallback is $HOME/.local/state/leash/traces. The first non-blank HTTP(S) URL
chooses the registrable domain, using a frozen public-suffix list including private
suffixes: books.toscrape.com becomes toscrape.com; a.b.co.uk becomes b.co.uk.
IP addresses and local hosts retain their host. Without an observed site the
directory is unknown. A cross-site drive writes one file under its first site.
Directories are private (0700), files 0600; symlink files/directories are refused.

## Inspect offline

```sh
leash traces list [--site SITE] [--outcome OUTCOME]
leash traces show FILE
leash traces prune [--site SITE] [--dry-run]
```

list prints newest-first TSV with six columns: UTC time, site, outcome, reported
cost (empty if unknown), executed-step count, mission. Tabs and newlines in a
mission become spaces. show prints decoded JSON. prune prints affected paths;
--dry-run changes nothing. list and prune accept --config FILE to read retention
without contacting the control socket. Missing stores list as empty; invalid
filters, malformed traces, symlinks, and files larger than 8 MiB report an error
and exit 65. No service, browser, or model is needed.

## Safe typed files

The version-1 derived Protocol.drive_trace projection contains time, site, mission,
outcome, cost (number or null), duration_ms, model_calls, page_kind_path,
inferred_pages, arguments, compiled, procedures, steps, unattended, final (URL/title or null), and optional
error_code and `structural_outline` (default `null`). For done collection missions the final page contributes a tag/class skeleton of repeated containers, bounded to 4096 bytes, at most 256 elements and depth five. It contains no text nodes, attributes, field values or URLs; failed capture leaves null. Legacy files decode with null. The compiler receives this skeleton as selector evidence (map-op09). inferred_pages is the session mapping: each `{name, url_pattern}` is a
generalized URL and the name it was given, first-seen. A missing inferred_pages on an
older file decodes as empty. Procedures
have n, procedure, outcome, planned, and safe steps. `arguments` is a list of `[name, value]` pairs (default `[]`): only bindings whose values occur in retained, non-redacted typed steps are saved; unused and password-marker bindings are discarded. Steps have n, operation, source (`operator` or `planner`, default `operator`), non_repeatable (default false), optional error code,
optional target {role,label}, optional text, operations and targets probability
lists ({key,probability}), after {url,title}, and elapsed_ms.

Targets come from the decision-time snapshot before an action replaces a row.
Password-field text is exactly [password]. Page text, tab/snapshot handles,
cookies, raw model state, script records, and error messages/details are not saved.
Mission, URLs, titles, and target labels are retained: do not put secrets in the
mission. Non-finite probabilities and undeclared operation keys are discarded.
A selected playbook's declared kind wins over an inferred one and is not added to
inferred_pages. Where no declared kind matches, the inferred name enters
page_kind_path and the generalized pattern enters inferred_pages. An installed book
that was not selected does not supply declared kinds. Unchanged observations do not
add duplicates. Inferred kinds are not written into a playbook; the compiler proposes
pages from inferred_pages.
Persistence completes before reply encoding, so trace_path names an existing
file. Errors expose error.detail.trace_path. Write/prune failures are logged and
never change the drive outcome; a failed write omits the path.

## Unattended audit

`unattended` defaults to `[]` for older traces. Notification events record the one-line
message, sent/failed outcome, failure text when present, and elapsed time.
Handoff events record reason, elapsed wait, and resumed/expired/failed outcome. Challenge
events record origin, whether attempts are enabled, turns used and the outcome. No tab
handle, snapshot capability, raw page dump, or arbitrary model response is copied into
these events. Messages are operator-facing content and may contain order IDs.

## Switch and retention

In leash.toml:

```toml
[traces]
enabled = true
[traces.retention]
count = 20
days = 30
```

enabled = false disables capture, writes, and automatic pruning; offline reads
still work. count is 1..10000; days is 1..3650. Retention is per site: keep only
the newest count traces that are also no older than days. All outcomes count
toward the newest-first rank. Automatic pruning follows a successful write;
prune applies the same rule offline. Cutoffs use UTC; the exact age boundary is
kept.

Every done trace with compiled = false is exempt from both limits. Missing
compiled decodes as false for older files. A future compiler may set compiled =
true only after the resulting procedure is durably accepted; normal retention
then applies. L51 neither compiles traces nor sets the marker.
