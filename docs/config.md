# Configuration

One TOML file, `$XDG_CONFIG_HOME/leash/config.toml` (`HOME/.config` when
`XDG_CONFIG_HOME` is unset; `--config FILE` overrides it). The Door decodes it, applies
the environment overrides below, and validates it against the machine before anything
starts: an unknown key, a bad value, a missing Chrome binary or an unreadable profile
directory fails at boot with the field's JSON pointer, and `leash config check` reports the
same without starting the service.

Every setting has a default, so a file that names one field — or a file that is only
comments, or no file at all — is a configuration: a first run starts on the defaults, and
only a `--config FILE` path that is not there is an error naming it (svc-x8rp,
napp-9x0s). `leash config init` writes that file with every setting commented out and its
default shown, refusing to overwrite an existing one unless `--force`; the file it writes
decodes to the defaults it documents.

| key | default | meaning |
| --- | --- | --- |
| `chrome.binary` | `"google-chrome-stable"` | The managed Chrome. An absolute path, or a bare name found on `PATH` (svc-x8rp). |
| `chrome.profile_dir` | `"$XDG_DATA_HOME/leash/profile"` | The one profile Chrome runs on; `$HOME/.local/share` when `XDG_DATA_HOME` is unset. The service creates it 0700 on a first run. |
| `chrome.workspace` | `"leash"` | The niri workspace the window belongs on, best effort (chrome-2y3t). |
| `chrome.headless` | `false` | Only the live-acceptance gate sets true; production is headed (ADR-0003). |
| `tabs.cap` | `32` | Open tabs; `new` past it fails at once (ADR-0005). |
| `expiry.idle_s` | `1800` | Stage 1 releases a tab idle this long (own-uo77). |
| `expiry.unclaimed_s` | `3600` | Stage 2 closes an unclaimed agent-origin tab this long after (own-hslp). |
| `expiry.tombstone_s` | `3600` | A closed handle answers `tab-gone` for this long (chrome-akz4). |
| `control.socket` | `"$XDG_RUNTIME_DIR/leash/control.sock"` | Where the service listens and the CLI connects; owner-only, in a directory the listener verifies (svc-o4wt). |
| `otlp.endpoint` | unset | Optional OTLP/HTTP exporter; absent means no exporter is acquired (svc-f4op). |
| `otlp.headers` | `[]` | Collector headers, each `{name, value}`; values are secrets (svc-f4op). |
| `models.api_key` | unset | `OPENROUTER_API_KEY` in the environment wins over the file, and no rendering path ever shows it (svc-kzt6). |
| `models.systemone_endpoint` | OpenRouter's System One | Where JEV is asked (drive-e7oi). |
| `models.jev_model` | `"typesafe/jev-1.13-20260917"` | The pinned decision model; a reply naming another model is refused (drive-e7oi). |
| `models.chat_base_url` | `"https://openrouter.ai/api/v1"` | The text helper's base url (drive-ls3c). |
| `models.text_model` | `"inception/mercury-2.5"` | The text helper's model (drive-ls3c). |
| `handoff.focus_command` | empty | The argv template a handoff runs to raise the window; off by default because a handoff must not take focus (daily-n7on, operator 2026-10-01). For niri: `["niri", "msg", "action", "focus-window", "--id", "{window_id}"]` (hand-phof). |
| `handoff.notify_command` | `notify-send --urgency=critical --app-name=Leash --action done=Done "Leash needs you" {reason}` | The argv template for the notification whose Done action resumes; critical so the daemon keeps it until answered; empty turns it off (hand-phof). |

Environment:

- `OPENROUTER_API_KEY` replaces `models.api_key` whenever it is non-empty (svc-kzt6).
- `XDG_DATA_HOME` and `XDG_RUNTIME_DIR` expand the two XDG paths above. A variable that is
  unset leaves its placeholder in place, and validation refuses that field by pointer — the
  service never writes to a path named `$XDG_RUNTIME_DIR`.
