# Expectations

An expectation is a sentence. After a procedure, and before a mission is accepted as done, Leash checks the sentence. Some sentences are checked by code. Any other sentence is a judgment: JEV scores it against the page, which is slower and can be wrong. `{name}` placeholders are substituted from the run's arguments first (`the page shows {product}`).

A trailing period is ignored. Matching of the sentence shape is case-insensitive. A page-kind name that is not declared is refused at load (`unknown page kind KIND`), not scored.

## Code checkers

`the page is category`

The current URL or page text matches the page kind named `category`. A `url_pattern` matches the whole URL. `*` matches any characters, including `?` and `#`. Without `*` the pattern is exact. A `text_marker` matches as a case-insensitive substring of the page text. Either match is enough.

`the page is not cart`

The current page is not the kind named `cart`.

`the page shows Your cart is empty`

The page text contains that string, case-insensitive. `the page contains In stock` is the same checker. An empty phrase (`the page shows` with nothing after it) is not this checker; it is a judgment.

`a file was downloaded`

A download started by this tab has completed.

`a pdf was downloaded`

A completed download whose MIME type is `application/pdf`. `a pdf file was downloaded` is the same checker.

`no dialog is open`

No JavaScript `alert`, `confirm`, `prompt`, or `beforeunload` is open. An HTML modal is page text and rows, not this checker.

`a button named Checkout is present`

A snapshot row has that role and that name. The shape is `a ROLE named NAME is present`. An empty name is not this checker; it is a judgment.

## Only in a goal's until

`the address changed`

The URL differs from the URL at the start of this goal step. Checked only after an action, never before the first one. `the url changed` is the same checker. It is not a procedure expectation: in `expect` it is a judgment.

## Judgment

`the cheapest book is selected`

JEV scores the sentence against the page. Use a code checker when one exists. A mission `--expect` with no playbook must be a concrete text, row, download, or dialog sentence: a page-kind name needs a playbook.
