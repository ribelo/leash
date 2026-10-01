# Field reports

Every real task done through Leash ends with a short field report. A real task is work the operator wanted done on a real site, not a test or a gate. The next milestone is shaped by these reports, not by the plan.

## The rule

- The agent that did the task writes the report when it finishes, whether the task succeeded or not.
- The report goes in this directory as `YYYY-MM-DD-<slug>.md`, with one report per task.
- It records three things:
  - **Worked:** the commands and flows that did their job without help.
  - **Failed:** each failure with its exact error `code` (or `status` and `reason` for a `drive`), the site and the command.
  - **Worked around:** what the agent did instead when Leash fell short, such as `eval` in place of `fill`, a manual step, or a retry. Workarounds show where the gaps are.
- Facts only. Name the site, the page and the command. Quote error codes and messages verbatim. Never include secrets, credentials or personal data.
- Keep it short: the one-line summary, then a few lines per section. Link a transcript if one exists; do not paste it.

## Template

The first line of every report, filled in:

```
<date> | <task> | <sites> | <done|partial|failed> | worked: <…> | failed: <code@command, …> | worked around: <…>
```

For example:

```
2026-09-30 | register API keys | dvids, europeana, api.data.gov, dpla, gmail | partial (4/6) | worked: new, fill, net body, debug, popups | failed: row-not-actionable@click (label checkbox), timeout@nav (Pixabay), unknown-tab after new timeout | worked around: eval for password fields, eval for Gmail's empty AX tree
```

## How the reports are used

Before a new milestone is written, the reports since the last one are read together. A failure or workaround that repeats becomes a story citing the reports it came from. [2026-09-30-field-report](../2026-09-30-field-report/README.md) is the first such report; it became L48.
