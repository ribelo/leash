# L49 fresh-agent Leash transcript

## $ leash
exit code: 0

stdout:
```
Leash: local managed Chrome for agents.
Service: reachable, but not healthy (run leash status)
Start: systemctl --user start leash
Begin: leash status; leash new https://example.com; leash snap TAB
agent tabs close after 30 idle minutes; your tabs are never closed unless an agent takes one
Help: leash --help; leash COMMAND --help; leash help errors

```
stderr:
```

```

## $ leash --help
exit code: 0

stdout:
```
NAME
       leash - A local managed Chrome for agents.

SYNOPSIS
       leash [COMMAND] …

DESCRIPTION
       One local service owns the managed Chrome. Commands send one JSON
       request over its private Unix socket. Only skill install may ask for
       local installation consent; use --force or --no-input in automation.

       Handles are secret capabilities; save the handle from leash new or
       leash take. leash list never reveals handles.

       agent tabs close after 30 idle minutes; your tabs are never closed
       unless an agent takes one

       leash status

       leash list --table

       leash new https://example.com --label research

       leash snap TAB --limit 20

SERVICE
       serve
           Start the service in the foreground; normally systemctl --user
           start leash owns it.

       config init / config check
           Write the default configuration, then report all setup problems
           before starting.

       status [--config=FILE] [--pretty] [--socket=PATH] [OPTION]…
           Report version, Chrome, the model key and the installed skill.

SKILL
       leash skill show prints the bundled entrypoint. leash skill install
       --dry-run previews configured skill.roots (or discovered skills roots
       when unset); --force authorizes installation or replacement. PATH
       means a skills root, with the bundle at PATH/leash/.

       skill COMMAND …
           Show or install the bundled agent skill.

ACT
       check [OPTION]… [TAB] [SNAPSHOT] [INDEX]
           Check the control at INDEX and verify it became checked.

       click [OPTION]… [TAB] [SNAPSHOT] [INDEX]
           Click the row at INDEX of SNAPSHOT. A covering label of that
           control is clicked and reported as via label.

       dialog [OPTION]… [TAB] [ACCEPT|DISMISS]
           Answer the page's dialog (never automatic).

       fill [OPTION]… [TAB] [SNAPSHOT] [INDEX] [TEXT]
           Fill the row at INDEX of SNAPSHOT with TEXT, or with
           --argument-file or --stdin.

       hover [OPTION]… [TAB] [SNAPSHOT] [INDEX]
           Move the mouse to the row at INDEX of SNAPSHOT.

       nav [--config=FILE] [--pretty] [--socket=PATH] [OPTION]… [TAB] [URL]
           Navigate a tab to a URL (http, https or about:blank).

       press [OPTION]… [TAB] [SNAPSHOT] [KEY]
           Press KEY; with --index the row is focused first. Accepted names:
           Enter, Escape, Esc, Tab, Backspace, Delete, ArrowUp, ArrowDown,
           ArrowLeft, ArrowRight, Home, End, PageUp, PageDown, Space,
           lowercase a-z, digits 0-9, and single punctuation characters - = [
           ] ; , . / '.

       scroll [OPTION]… [TAB] [UP|DOWN]
           Scroll the page, or the row --index names, one viewport.

       select [OPTION]… [TAB] [SNAPSHOT] [INDEX] [OPTION]
           Choose OPTION, the row's observed option index.

       uncheck [OPTION]… [TAB] [SNAPSHOT] [INDEX]
           Uncheck the control at INDEX and verify it became unchecked.

       upload [--config=FILE] [--pretty] [--socket=PATH] [OPTION]… [TAB]
       [SNAPSHOT] [INDEX] [PATH]…
           Set PATH... on the file input at INDEX of SNAPSHOT.

       wait [OPTION]… [TAB]
           Wait for the ANDed page conditions.

MISSIONS
       discover [OPTION]… [SITE-OR-URL]
           Explore SITE with the planner; write a proposed playbook without
           applying it.

       drive [OPTION]… [MISSION]
           Drive MISSION on the fly, or through a fitting playbook when JEV
           chooses one.

NETWORK AND DEBUG
       cookies [--config=FILE] [--pretty] [--socket=PATH] [OPTION]… [TAB]
           Read the cookies of the tab's URL, httpOnly included (read-only).

       debug [OPTION]… [TAB]
           Show the console, exception and failed-request ring.

       eval [OPTION]… [TAB] [EXPRESSION]
           Evaluate EXPRESSION as a function body in the page.

       net [OPTION]… [TAB] [body|request] [ID]
           List the tab's recent requests; `net TAB body ID` and `net TAB
           request ID` read one.

       storage [--config=FILE] [--pretty] [--socket=PATH] [OPTION]… [TAB]
       [local|session]
           Read the tab's local or session storage (read-only).

OBSERVE
       downloads [--config=FILE] [--pretty] [--socket=PATH] [OPTION]… [TAB]
           List downloads started by this tab.

       shot [OPTION]… [TAB] [PATH]
           Write a screenshot as a PNG to PATH.

       snap [OPTION]… [TAB]
           Observe an indexed snapshot of a tab.

       text [OPTION]… [TAB]
           Extract the page's visible text.

PLAYBOOKS
       playbook COMMAND …
           Inspect, validate and grow site playbooks.

TABS
       close [--config=FILE] [--pretty] [--socket=PATH] [OPTION]… [TAB]
           Close a tab using its handle.

       handoff [OPTION]… [TAB] [REASON]
           Hand the tab to the human and block until resume or timeout.

       list [OPTION]…
           List all tabs without handles; agent tabs close after 30 idle
           minutes; your tabs are never closed unless an agent takes one

       new [OPTION]… [URL]
           Open an agent tab. agent tabs close after 30 idle minutes; your
           tabs are never closed unless an agent takes one

       resume [--config=FILE] [--pretty] [--socket=PATH] [OPTION]… [TAB]
           Resume a tab a handoff is waiting on.

       take [OPTION]…
           Take exactly one human tab matching one selector and return its
           handle.

COMMANDS
       config COMMAND …
           Inspect configuration.

       help [OPTION]… [TOPIC]
           Discover help topics without contacting the service.

       serve [--config=FILE] [OPTION]…
           Start the program.

COMMON OPTIONS
       --help[=FMT] (default=auto)
           Show this help in format FMT. The value FMT must be one of auto,
           pager, groff or plain. With auto, the format is pager or plain
           whenever the TERM env var is dumb or undefined.

EXIT STATUS
       leash exits with:

       0   Success.

       64  Invalid request or invocation; fix the input.

       65  Invalid configuration, playbook, or stale page data.

       66  Unknown or gone tab, row, or network request.

       69  Service, browser, or model unavailable.

       70  Internal failure or invalid service response.

       75  Retryable timeout or tab capacity limit.

       77  Filesystem or socket permission, or tab capability refused.

       124 Command-line parsing failed; the command did not run.

EXAMPLES
       leash click --help; leash help errors

       leash config init; leash config check; leash serve

ERRORS
       Run leash help errors for every code, exit class, meaning and recovery
       hint. --socket PATH overrides the configured control socket.


```
stderr:
```

```

## $ leash status
exit code: 0

stdout:
```
{"key_present":true,"commit":"964c51a3c41125f89ae379ac445a918ca7c25f68","skill":{"state":"current","version":"0.0.0","commit":"964c51a3c41125f89ae379ac445a918ca7c25f68","installs":[{"path":"/home/ribelo/.dotfiles/skills/engineering/debugging/leash","state":"current","version":"0.0.0","commit":"964c51a3c41125f89ae379ac445a918ca7c25f68"}]},"generation":1,"tabs":{"open":1,"cap":32},"chrome":"running","uptime_s":39.1117479801178,"models":{"configured":true,"jev_model":"typesafe/jev-1.13-20260917","text_model":"inception/mercury-2.5","systemone_endpoint":"https://openrouter.ai/api/v1/systemone","chat_base_url":"https://openrouter.ai/api/v1"},"version":"0.0.0","pid":1724561,"headed":true}

```
stderr:
```

```

## $ leash list
exit code: 0

stdout:
```
{"tabs":[{"label":null,"url":"https://books.toscrape.com/catalogue/category/books/poetry_23/index.html","title":"books.toscrape.com/catalogue/category/books/poetry_23/index.html","origin":"human","age_s":38,"idle_s":38,"closes_in_s":null,"with_human":false}]}

```
stderr:
```

```

## $ leash new --help
exit code: 0

stdout:
```
NAME
       leash-new - Open an agent tab. agent tabs close after 30 idle minutes;
       your tabs are never closed unless an agent takes one

SYNOPSIS
       leash new [OPTION]… [URL]

OPTIONS
       --config=FILE
           TOML configuration file the control socket is read from.

       --label=TEXT
           Free label shown by list. It is not a capability.

       --pretty
           Indent JSON output.

       --socket=PATH
           Control socket path; overrides control.socket.

COMMON OPTIONS
       --help[=FMT] (default=auto)
           Show this help in format FMT. The value FMT must be one of auto,
           pager, groff or plain. With auto, the format is pager or plain
           whenever the TERM env var is dumb or undefined.

EXIT STATUS
       leash new exits with:

       0   Success.

       64  Invalid request or invocation; fix the input.

       65  Invalid configuration, playbook, or stale page data.

       69  Service, browser, or model unavailable.

       70  Internal failure or invalid service response.

       75  Retryable timeout or tab capacity limit.

       77  Filesystem or socket permission, or tab capability refused.

       124 Command-line parsing failed; the command did not run.

EXAMPLES
       leash new https://example.com

       leash new https://example.com --label research

ERRORS
       Failures are one JSON record on stderr. Run leash help errors for
       codes and recovery hints.

SEE ALSO
       leash(1)


```
stderr:
```

```

## $ leash take --help
exit code: 0

stdout:
```
NAME
       leash-take - Take exactly one human tab matching one selector and
       return its handle.

SYNOPSIS
       leash take [OPTION]…

OPTIONS
       --config=FILE
           TOML configuration file the control socket is read from.

       --label=TEXT
           Case-insensitive exact label.

       --pretty
           Indent JSON output.

       --socket=PATH
           Control socket path; overrides control.socket.

       --title=TEXT
           Case-insensitive title substring.

       --url=PREFIX
           Case-insensitive URL prefix.

COMMON OPTIONS
       --help[=FMT] (default=auto)
           Show this help in format FMT. The value FMT must be one of auto,
           pager, groff or plain. With auto, the format is pager or plain
           whenever the TERM env var is dumb or undefined.

EXIT STATUS
       leash take exits with:

       0   Success.

       64  Invalid request or invocation; fix the input.

       65  Invalid configuration, playbook, or stale page data.

       66  Unknown or gone tab, row, or network request.

       69  Service, browser, or model unavailable.

       70  Internal failure or invalid service response.

       75  Retryable timeout or tab capacity limit.

       77  Filesystem or socket permission, or tab capability refused.

       124 Command-line parsing failed; the command did not run.

EXAMPLES
       leash take --url https://example.com/

       leash take --title Login

ERRORS
       Failures are one JSON record on stderr. Run leash help errors for
       codes and recovery hints.

SEE ALSO
       leash(1)


```
stderr:
```

```

## $ leash handoff --help
exit code: 0

stdout:
```
NAME
       leash-handoff - Hand the tab to the human and block until resume or
       timeout.

SYNOPSIS
       leash handoff [OPTION]… [TAB] [REASON]

OPTIONS
       --config=FILE
           TOML configuration file the control socket is read from.

       --pretty
           Indent JSON output.

       --socket=PATH
           Control socket path; overrides control.socket.

       --timeout-s=S
           Seconds before the handoff ends (default 900).

COMMON OPTIONS
       --help[=FMT] (default=auto)
           Show this help in format FMT. The value FMT must be one of auto,
           pager, groff or plain. With auto, the format is pager or plain
           whenever the TERM env var is dumb or undefined.

EXIT STATUS
       leash handoff exits with:

       0   Success.

       64  Invalid request or invocation; fix the input.

       65  Invalid configuration, playbook, or stale page data.

       66  Unknown or gone tab, row, or network request.

       69  Service, browser, or model unavailable.

       70  Internal failure or invalid service response.

       75  Retryable timeout or tab capacity limit.

       77  Filesystem or socket permission, or tab capability refused.

       124 Command-line parsing failed; the command did not run.

EXAMPLES
       leash handoff t_9xk 'The captcha needs you'

ERRORS
       Failures are one JSON record on stderr. Run leash help errors for
       codes and recovery hints.

SEE ALSO
       leash(1)


```
stderr:
```

```

## $ leash close --help
exit code: 0

stdout:
```
NAME
       leash-close - Close a tab using its handle.

SYNOPSIS
       leash close [--config=FILE] [--pretty] [--socket=PATH] [OPTION]… [TAB]

OPTIONS
       --config=FILE
           TOML configuration file the control socket is read from.

       --pretty
           Indent JSON output.

       --socket=PATH
           Control socket path; overrides control.socket.

COMMON OPTIONS
       --help[=FMT] (default=auto)
           Show this help in format FMT. The value FMT must be one of auto,
           pager, groff or plain. With auto, the format is pager or plain
           whenever the TERM env var is dumb or undefined.

EXIT STATUS
       leash close exits with:

       0   Success.

       64  Invalid request or invocation; fix the input.

       65  Invalid configuration, playbook, or stale page data.

       66  Unknown or gone tab, row, or network request.

       69  Service, browser, or model unavailable.

       70  Internal failure or invalid service response.

       75  Retryable timeout or tab capacity limit.

       77  Filesystem or socket permission, or tab capability refused.

       124 Command-line parsing failed; the command did not run.

EXAMPLES
       leash close t_9xk

ERRORS
       Failures are one JSON record on stderr. Run leash help errors for
       codes and recovery hints.

SEE ALSO
       leash(1)


```
stderr:
```

```

## $ leash list --help
exit code: 0

stdout:
```
NAME
       leash-list - List all tabs without handles; agent tabs close after 30
       idle minutes; your tabs are never closed unless an agent takes one

SYNOPSIS
       leash list [OPTION]…

OPTIONS
       --config=FILE
           TOML configuration file the control socket is read from.

       --pretty
           Indent JSON output.

       --socket=PATH
           Control socket path; overrides control.socket.

       --table
           Render list and snap rows as a table.

COMMON OPTIONS
       --help[=FMT] (default=auto)
           Show this help in format FMT. The value FMT must be one of auto,
           pager, groff or plain. With auto, the format is pager or plain
           whenever the TERM env var is dumb or undefined.

EXIT STATUS
       leash list exits with:

       0   Success.

       64  Invalid request or invocation; fix the input.

       65  Invalid configuration, playbook, or stale page data.

       69  Service, browser, or model unavailable.

       70  Internal failure or invalid service response.

       77  Filesystem or socket permission, or tab capability refused.

       124 Command-line parsing failed; the command did not run.

EXAMPLES
       leash list

       leash list --table

ERRORS
       Failures are one JSON record on stderr. Run leash help errors for
       codes and recovery hints.

SEE ALSO
       leash(1)


```
stderr:
```

```

## $ leash new https://books.toscrape.com/catalogue/category/books/travel_2/index.html --label fresh-travel
exit code: 0

stdout:
```
{"tab":"t_0514d86b9eadd0369dccee594ac4222e","label":"fresh-travel","url":"https://books.toscrape.com/catalogue/category/books/travel_2/index.html","title":"Travel | Books to Scrape - Sandbox","origin":"agent","age_s":0,"idle_s":0,"closes_in_s":1800,"with_human":false,"generation":1,"dialog":null,"loaded":true}

```
stderr:
```

```

## $ leash text t_0514d86b9eadd0369dccee594ac4222e --max-chars 3000
exit code: 0

stdout:
```
{"url":"https://books.toscrape.com/catalogue/category/books/travel_2/index.html","title":"Travel | Books to Scrape - Sandbox","text":"Books to Scrape We love being scraped!\nHome  Books Travel\nBooks\nTravel\nMystery\nHistorical Fiction\nSequential Art\nClassics\nPhilosophy\nRomance\nWomens Fiction\nFiction\nChildrens\nReligion\nNonfiction\nMusic\nDefault\nScience Fiction\nSports and Games\nAdd a comment\nFantasy\nNew Adult\nYoung Adult\nScience\nPoetry\nParanormal\nArt\nPsychology\nAutobiography\nParenting\nAdult Fiction\nHumor\nHorror\nHistory\nFood and Drink\nChristian Fiction\nBusiness\nBiography\nThriller\nContemporary\nSpirituality\nAcademic\nSelf Help\nHistorical\nChristian\nSuspense\nShort Stories\nNovels\nHealth\nPolitics\nCultural\nErotica\nCrime\nTravel\n11 results.\nWarning! This is a demo website for web scraping purposes. Prices and ratings here were randomly assigned and have no real meaning.\n\n    \n\nIt's Only the Himalayas\n\n£45.17\n\n In stock\n\nAdd to basket\n\n    \n\nFull Moon over Noah’s ...\n\n£49.43\n\n In stock\n\nAdd to basket\n\n    \n\nSee America: A Celebration ...\n\n£48.87\n\n In stock\n\nAdd to basket\n\n    \n\nVagabonding: An Uncommon Guide ...\n\n£36.94\n\n In stock\n\nAdd to basket\n\n    \n\nUnder the Tuscan Sun\n\n£37.33\n\n In stock\n\nAdd to basket\n\n    \n\nA Summer In Europe\n\n£44.34\n\n In stock\n\nAdd to basket\n\n    \n\nThe Great Railway Bazaar\n\n£30.54\n\n In stock\n\nAdd to basket\n\n    \n\nA Year in Provence ...\n\n£56.88\n\n In stock\n\nAdd to basket\n\n    \n\nThe Road to Little ...\n\n£23.21\n\n In stock\n\nAdd to basket\n\n    \n\nNeither Here nor There: ...\n\n£38.95\n\n In stock\n\nAdd to basket\n\n    \n\n1,000 Places to See ...\n\n£26.08\n\n In stock\n\nAdd to basket","truncated":false}

```
stderr:
```

```

## $ leash take --title Poetry
exit code: 0

stdout:
```
{"tab":"t_f94c7dbb004398e32a2ed5c662e74f02","label":null,"url":"https://books.toscrape.com/catalogue/category/books/poetry_23/index.html","title":"books.toscrape.com/catalogue/category/books/poetry_23/index.html","origin":"agent","age_s":45,"idle_s":0,"closes_in_s":1800,"with_human":false,"generation":1,"dialog":null}

```
stderr:
```

```

(note: previous take output handle saved to /tmp/l49-poetry.txt; handles redacted below is not done, they are session-local)

## $ leash eval t_0514d86b9eadd0369dccee594ac4222e 'return [...document.querySelectorAll("article.product_pod h3 a")].map(a=>a.title)'
exit code: 0

stdout:
```
{"value":["It's Only the Himalayas","Full Moon over Noah’s Ark: An Odyssey to Mount Ararat and Beyond","See America: A Celebration of Our National Parks & Treasured Sites","Vagabonding: An Uncommon Guide to the Art of Long-Term World Travel","Under the Tuscan Sun","A Summer In Europe","The Great Railway Bazaar","A Year in Provence (Provence #1)","The Road to Little Dribbling: Adventures of an American in Britain (Notes From a Small Island #2)","Neither Here nor There: Travels in Europe","1,000 Places to See Before You Die"]}

```
stderr:
```

```

## $ leash eval t_f94c7dbb004398e32a2ed5c662e74f02 'return [...document.querySelectorAll("article.product_pod")].map(a=>[a.querySelector("h3 a").title, a.querySelector(".price_color").textContent])'
exit code: 0

stdout:
```
{"value":[["A Light in the Attic","£51.77"],["The Black Maria","£52.15"],["Shakespeare's Sonnets","£20.66"],["Olio","£23.88"],["You can't bury them all: Poems","£33.63"],["Slow States of Collapse: Poems","£57.31"],["Untitled Collection: Sabbath Poems 2014","£14.27"],["Poems That Make Grown Women Cry","£14.19"],["Night Sky with Exit Wounds","£41.05"],["salt.","£46.78"],["Quarter Life Poetry: Poems for the Young, Broke and Hangry","£50.89"],["Out of Print: City Lights Spotlight No. 14","£53.64"],["Les Fleurs du Mal","£29.04"],["Howl and Other Poems","£40.45"],["Leave This Song Behind: Teen Poetry at Its Best","£51.17"],["The Collected Poems of W.B. Yeats (The Collected Works of W.B. Yeats #1)","£15.42"],["The Crossover","£38.77"],["Booked","£17.49"],["Twenty Love Poems and a Song of Despair","£30.95"]]}

```
stderr:
```

```

## $ leash text t_f94c7dbb004398e32a2ed5c662e74f02 --max-chars 1500
exit code: 0

stdout:
```
{"url":"https://books.toscrape.com/catalogue/category/books/poetry_23/index.html","title":"books.toscrape.com/catalogue/category/books/poetry_23/index.html","text":"Books to Scrape We love being scraped!\nHome  Books Poetry\nBooks\nTravel\nMystery\nHistorical Fiction\nSequential Art\nClassics\nPhilosophy\nRomance\nWomens Fiction\nFiction\nChildrens\nReligion\nNonfiction\nMusic\nDefault\nScience Fiction\nSports and Games\nAdd a comment\nFantasy\nNew Adult\nYoung Adult\nScience\nPoetry\nParanormal\nArt\nPsychology\nAutobiography\nParenting\nAdult Fiction\nHumor\nHorror\nHistory\nFood and Drink\nChristian Fiction\nBusiness\nBiography\nThriller\nContemporary\nSpirituality\nAcademic\nSelf Help\nHistorical\nChristian\nSuspense\nShort Stories\nNovels\nHealth\nPolitics\nCultural\nErotica\nCrime\nPoetry\n19 results.\nWarning! This is a demo website for web scraping purposes. Prices and ratings here were randomly assigned and have no real meaning.\n\n    \n\nA Light in the ...\n\n£51.77\n\n In stock\n\nAdd to basket\n\n    \n\nThe Black Maria\n\n£52.15\n\n In stock\n\nAdd to basket\n\n    \n\nShakespeare's Sonnets\n\n£20.66\n\n In stock\n\nAdd to basket\n\n    \n\nOlio\n\n£23.88\n\n In stock\n\nAdd to basket\n\n    \n\nYou can't bury them ...\n\n£33.63\n\n In stock\n\nAdd to basket\n\n    \n\nSlow States of Collapse: ...\n\n£57.31\n\n In stock\n\nAdd to basket\n\n    \n\nUntitled Collection: Sabbath Poems ...\n\n£14.27\n\n In stock\n\nAdd to basket\n\n    \n\nPoems That Make Grown ...\n\n£14.19\n\n In stock\n\nAdd to basket\n\n    \n\nNight Sky with Exit ...\n\n£41.05\n\n In stock\n\nAdd to basket\n\n    \n\nsalt.\n\n£46.78\n\n In stock\n\nAdd to basket\n\n    \n\nQuarter Life Poetry: Poems ...\n\n£50.89\n\n In stock\n\nAdd to basket\n\n    \n\nOut of Print: City ...\n\n£53.64\n\n In stock\n\nAdd to basket\n\n    \n\nLes F","truncated":true}

```
stderr:
```

```

## $ leash snap t_0514d86b9eadd0369dccee594ac4222e --match 'Himalayas' --limit 10
exit code: 0

stdout:
```
{"snapshot":"s_t_c7d729d2e7f55a6d9808ea8a4033e5ff","tab":"t_0514d86b9eadd0369dccee594ac4222e","url":"https://books.toscrape.com/catalogue/category/books/travel_2/index.html","title":"Travel | Books to Scrape - Sandbox","rows":[{"index":40,"role":"link","name":"It's Only the Himalayas"},{"index":42,"role":"heading","name":"It's Only the Himalayas"},{"index":43,"role":"link","name":"It's Only the Himalayas"}],"total":3,"offset":0,"truncated":false,"settled":true,"source":"ax","dialog":null}

```
stderr:
```

```

## $ leash click t_0514d86b9eadd0369dccee594ac4222e s_t_c7d729d2e7f55a6d9808ea8a4033e5ff 40
exit code: 0

stdout:
```
{"tab":"t_0514d86b9eadd0369dccee594ac4222e","url":"https://books.toscrape.com/catalogue/category/books/travel_2/index.html","title":"Travel | Books to Scrape - Sandbox","snapshot":null,"dialog":null,"popups":[]}

```
stderr:
```

```

## $ leash wait t_0514d86b9eadd0369dccee594ac4222e --text 'Product Description' --timeout-ms 8000
exit code: 0

stdout:
```
{"tab":"t_0514d86b9eadd0369dccee594ac4222e","url":"https://books.toscrape.com/catalogue/its-only-the-himalayas_981/index.html","title":"books.toscrape.com/catalogue/its-only-the-himalayas_981/index.html","snapshot":null,"dialog":null,"popups":[]}

```
stderr:
```

```

## $ leash snap t_f94c7dbb004398e32a2ed5c662e74f02 --match 'Light in the Attic' --limit 10
exit code: 0

stdout:
```
{"snapshot":"s_t_062a5dda846af68e5ece002a352b6548","tab":"t_f94c7dbb004398e32a2ed5c662e74f02","url":"https://books.toscrape.com/catalogue/category/books/poetry_23/index.html","title":"books.toscrape.com/catalogue/category/books/poetry_23/index.html","rows":[{"index":40,"role":"link","name":"A Light in the Attic"}],"total":1,"offset":0,"truncated":false,"settled":true,"source":"ax","dialog":null}

```
stderr:
```

```

## $ leash click t_f94c7dbb004398e32a2ed5c662e74f02 s_t_062a5dda846af68e5ece002a352b6548 40
exit code: 0

stdout:
```
{"tab":"t_f94c7dbb004398e32a2ed5c662e74f02","url":"https://books.toscrape.com/catalogue/category/books/poetry_23/index.html","title":"Poetry | Books to Scrape - Sandbox","snapshot":null,"dialog":null,"popups":[]}

```
stderr:
```

```

## $ leash wait t_f94c7dbb004398e32a2ed5c662e74f02 --text 'Product Description' --timeout-ms 8000
exit code: 0

stdout:
```
{"tab":"t_f94c7dbb004398e32a2ed5c662e74f02","url":"https://books.toscrape.com/catalogue/a-light-in-the-attic_1000/index.html","title":"books.toscrape.com/catalogue/a-light-in-the-attic_1000/index.html","snapshot":null,"dialog":null,"popups":[]}

```
stderr:
```

```

## $ leash eval t_0514d86b9eadd0369dccee594ac4222e 'return {title:document.title,h1:document.querySelector("h1").textContent,price:document.querySelector(".price_color").textContent}'
exit code: 0

stdout:
```
{"value":{"title":"It's Only the Himalayas | Books to Scrape - Sandbox","h1":"It's Only the Himalayas","price":"£45.17"}}

```
stderr:
```

```

## $ leash eval t_f94c7dbb004398e32a2ed5c662e74f02 'return {title:document.title,h1:document.querySelector("h1").textContent,price:document.querySelector(".price_color").textContent}'
exit code: 0

stdout:
```
{"value":{"title":"A Light in the Attic | Books to Scrape - Sandbox","h1":"A Light in the Attic","price":"£51.77"}}

```
stderr:
```

```

## $ leash handoff <mine> 'L49 check: please look at this tab and click Done' --timeout-s 600 (background job {"kind":"background","jobId":"bash-1567"})

## $ leash list --table
exit code: 0

stdout:
```
LABEL	URL	TITLE	ORIGIN	AGE_S	IDLE_S	CLOSES_IN_S	WITH_HUMAN
-	https://books.toscrape.com/catalogue/a-light-in-the-attic_1000/index.html	books.toscrape.com/catalogue/a-light-in-the-attic_1000/index.html	agent	67	3	1797	false
fresh-travel	https://books.toscrape.com/catalogue/its-only-the-himalayas_981/index.html	books.toscrape.com/catalogue/its-only-the-himalayas_981/index.html	agent	22	3	-	true

```
stderr:
```

```

## $ leash text t_0514d86b9eadd0369dccee594ac4222e --max-chars 100
exit code: 77

stdout:
```

```
stderr:
```
{"code":"with-human","message":"the tab is with the human; resume it first","hint":"the human holds this tab; wait, or return it with `leash resume TAB`"}

```

## handoff job bash-1567 result
exit code: 0
```
{"resumed":true,"url":"https://books.toscrape.com/catalogue/its-only-the-himalayas_981/index.html","title":"books.toscrape.com/catalogue/its-only-the-himalayas_981/index.html"}
```
(job ran ~45 s; operator clicked Done)

## $ leash list
exit code: 0

stdout:
```
{"tabs":[{"label":null,"url":"https://books.toscrape.com/catalogue/a-light-in-the-attic_1000/index.html","title":"books.toscrape.com/catalogue/a-light-in-the-attic_1000/index.html","origin":"agent","age_s":115,"idle_s":51,"closes_in_s":1749,"with_human":false},{"label":"fresh-travel","url":"https://books.toscrape.com/catalogue/its-only-the-himalayas_981/index.html","title":"books.toscrape.com/catalogue/its-only-the-himalayas_981/index.html","origin":"agent","age_s":70,"idle_s":5,"closes_in_s":1795,"with_human":false}]}

```
stderr:
```

```

## $ leash snap t_0514d86b9eadd0369dccee594ac4222e --limit 3
exit code: 0

stdout:
```
{"snapshot":"s_t_0b1f1cd4c0795d6c659410ff316a4e35","tab":"t_0514d86b9eadd0369dccee594ac4222e","url":"https://books.toscrape.com/catalogue/its-only-the-himalayas_981/index.html","title":"books.toscrape.com/catalogue/its-only-the-himalayas_981/index.html","rows":[{"index":1,"role":"link","name":"Books to Scrape"},{"index":2,"role":"link","name":"Home"},{"index":3,"role":"link","name":"Books"}],"total":10,"offset":0,"truncated":true,"settled":true,"source":"ax","dialog":null}

```
stderr:
```

```

## $ leash close t_0514d86b9eadd0369dccee594ac4222e
exit code: 0

stdout:
```
{"closed":true}

```
stderr:
```

```

## $ leash list
exit code: 0

stdout:
```
{"tabs":[{"label":null,"url":"https://books.toscrape.com/catalogue/a-light-in-the-attic_1000/index.html","title":"books.toscrape.com/catalogue/a-light-in-the-attic_1000/index.html","origin":"agent","age_s":116,"idle_s":51,"closes_in_s":1749,"with_human":false}]}

```
stderr:
```

```

## $ leash text t_0514d86b9eadd0369dccee594ac4222e --max-chars 50
exit code: 66

stdout:
```

```
stderr:
```
{"code":"tab-gone","message":"the tab is gone","hint":"open a new tab with `leash new`","detail":{"disposition":"closed_by_handle"}}

```

## $ leash status
exit code: 0

stdout:
```
{"key_present":true,"commit":"964c51a3c41125f89ae379ac445a918ca7c25f68","skill":{"state":"current","version":"0.0.0","commit":"964c51a3c41125f89ae379ac445a918ca7c25f68","installs":[{"path":"/home/ribelo/.dotfiles/skills/engineering/debugging/leash","state":"current","version":"0.0.0","commit":"964c51a3c41125f89ae379ac445a918ca7c25f68"}]},"generation":1,"tabs":{"open":1,"cap":32},"chrome":"running","uptime_s":116.96416401863098,"models":{"configured":true,"jev_model":"typesafe/jev-1.13-20260917","text_model":"inception/mercury-2.5","systemone_endpoint":"https://openrouter.ai/api/v1/systemone","chat_base_url":"https://openrouter.ai/api/v1"},"version":"0.0.0","pid":1724561,"headed":true}

```
stderr:
```

```

## $ leash help errors
exit code: 0

stdout:
```
# code	exit	meaning	hint
invalid-request	64	malformed JSON, unknown command, or bad arguments	fix the request; `leash <command> --help` names the arguments and one example
ambiguous	66	take matches several tabs; detail.matches lists them without handles	narrow the URL, title or label selector
no-match	66	take matches no tab	read `leash list` and use a matching URL prefix, title or label
taken	77	the tab already has a live handle	ask the holder for the handle
with-human	77	the tab is handed to the human; commands are refused until resume	the human holds this tab; wait, or return it with `leash resume TAB`
tab-gone	66	the handle names a closed tab; detail.disposition is closed_by_handle, closed_by_idle, closed_externally, or browser_lost	open a new tab with `leash new`
unknown-tab	66	no tab and no tombstone for the handle	that handle is not a tab; open a new tab with `leash new`, or ask the holder for the handle
stale-snapshot	65	the snapshot id or target row no longer matches the current page	read detail.snapshot; re-snap with `leash snap TAB` and use its id and row; if the row is gone, navigate back or re-find it before acting
no-such-row	66	the index is not in the snapshot	that index is not in the snapshot; `leash snap TAB` and use a listed index
body-unavailable	66	net body or request has no body to read, or Chrome has evicted it	that body is gone; `leash net TAB` and read a request that still has one
unknown-request	66	the tab's ring holds no request with that id	that id is not in the tab's ring; `leash net TAB` and use a listed id
row-not-actionable	65	the row is not visible, is disabled, is covered, or is the wrong kind of control	pick another row, or `leash snap TAB` if the page moved; a file input takes `leash upload`
state-unchanged	65	a check or uncheck did not change the control's checked state	snap and read the row's state; the control did not toggle, so pick another row or click its label
dialog-open	65	a dialog blocks page reads and actions; answer it first	answer it with `leash dialog TAB accept` or `leash dialog TAB dismiss`, then retry
no-dialog	64	dialog was asked with nothing to answer	nothing is open; `leash snap TAB` and call dialog only when a dialog is shown
no-handoff	64	resume on a tab nobody is waiting on	nobody is waiting; `leash handoff TAB REASON` starts one, and only then does `leash resume TAB` finish it
url-refused	64	scheme is not http, https, or about:blank, or the URL has userinfo	use an http or https URL with no userinfo, or about:blank
tab-cap	75	no capacity for a new tab	close a tab with `leash close TAB`, then retry `leash new`
timeout	75	wait, handoff, or a bounded operation ran out of time; a handoff's detail.warnings lists the steps that failed	retry; for a wait raise `--timeout-ms`, for a handoff raise the timeout or `leash resume TAB`
renderer-unresponsive	75	a tab session CDP call exceeded its deadline; detail.entries carries its last debug entries	the page's renderer is not answering; a bot-detection challenge or a hung script is likely; shot may still work; close the tab or hand off
browser-unavailable	69	Chrome is restarting	Chrome is restarting; retry `leash status` in a few seconds
model-unavailable	69	System One or the text helper failed, or no API key is configured; detail.code is missing-key, unavailable, timeout, authentication, invalid-response, input-too-large, model-mismatch, or text-helper-unavailable	read detail.code; set OPENROUTER_API_KEY or fix the model config, then retry
model-timeout	75	a model call exceeded its per-call deadline	the model provider timed out; retry, or raise models.<kind>_timeout
too-large	65	expression, argument, result, fill text, or a script result is over its bound	shrink the text, expression, argument, or files under the bound and retry
script-failed	65	a playbook script threw, rejected, or could not be compiled; message carries what it threw	read message; fix the script or the page, then `leash playbook test`
script-invalid	65	a playbook script's result does not fit its returns; message is the first mismatch	the result missed its returns shape; message is the first bad path, so fix the script or the returns
playbook-invalid	65	a playbook failed validation (load, check or accept); message names the rule	fix the playbook as the message says, then `leash playbook check ./DIR`; the skill's authoring reference lists the rules
internal	70	a defect; the message carries no page content	a defect, not a page failure; retry once, then report the message
service-unreachable	69	the CLI could not connect to the control socket	`systemctl --user start leash`, or pass --socket
not-installed	69	no leash.service unit is installed	Leash is not installed; rebuild NixOS so leash.service exists, then `systemctl --user start leash`
service-stopped	69	the leash unit is installed but inactive	`systemctl --user start leash`, then `leash status`; a brief service-restarting (75) right after start is normal - retry; tabs and snapshots from before the stop are gone, so re-open them
service-restarting	75	the leash unit is activating or auto-restarting, or Chrome's generation is being relaunched	Leash is restarting; retry `leash status` in a few seconds
socket-permission	77	the CLI was denied access to the control socket	the control socket is not readable; check its permissions, or pass --socket
permission-denied	77	the CLI was denied access to a filesystem path	check the path's permissions, or pass another path
config-invalid	65	the configuration file is missing, unreadable, or invalid	fix the reported problems; `leash config check` lists every one with the config path
usage	64	the command was invoked wrongly; the arguments do not match its synopsis	`leash <command> --help` shows the arguments and an example
cli-parse	124	Cmdliner rejected the command line; the command did not run	the command line did not parse; `leash <command> --help` shows the accepted form
invalid-response	70	the service reply was not a protocol object the CLI could decode	the service reply was not a protocol object; check `leash status` and retry


```
stderr:
```

```


## Final state
leash list after step 5 shows only the Poetry tab (now origin=agent, closes_in_s≈1749, label null, URL .../a-light-in-the-attic_1000/index.html). Own tab closed ({"closed":true}); later use gives tab-gone/closed_by_handle (exit 66).
Handles are session-local capabilities and appear in the command lines above as used.
