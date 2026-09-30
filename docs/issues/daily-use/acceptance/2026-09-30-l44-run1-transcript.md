# Leash L44 acceptance transcript

Owner: l44-acceptance
Started: 2026-09-30T09:50:05.259Z

Read: SKILL.md, references/{browser,errors,lifecycle,missions}.md, `leash --help`, `leash help errors`, and --help for new/snap/fill/select/click/net/dialog/downloads/drive/eval/text (full help saved in /tmp/leash-l44/help.txt).

**Pre-run observations**
- `leash help errors` lists codes not in the skill's errors.md exit table: `not-installed`(69), `service-stopped`(69), `service-restarting`(75). Skill table lists only `service-unreachable` under 69.
- The `drive --help` examples are 'Buy a Logitech MX Master 3S on allegro.pl' (a purchase example) - risky example text.
- `leash --help` says `list`: 'List the tabs this caller owns'.


## Step 1: httpbin form

```
$ leash new https://httpbin.org/forms/post --owner l44-acceptance
{"tab":"t_5bd503a6bb8d892d87ca26d868f441a2","url":"https://httpbin.org/forms/post","title":"httpbin.org/forms/post","origin":"agent","state":"owned","owner":"l44-acceptance","generation":2,"dialog":null,"expires":{"stage":"release","in_s":1800}}
[exit 0]

```

```
$ leash snap t_5bd503a6bb8d892d87ca26d868f441a2 --owner l44-acceptance
{"snapshot":"s_t_21594d9110bc5d9f9ac26a3ee7905b24","tab":"t_5bd503a6bb8d892d87ca26d868f441a2","url":"https://httpbin.org/forms/post","title":"httpbin.org/forms/post","rows":[{"index":1,"role":"textbox","name":"Customer name: "},{"index":2,"role":"textbox","name":"Telephone: "},{"index":3,"role":"textbox","name":"E-mail address: "},{"index":4,"role":"radio","name":" Small","state":["unchecked"]},{"index":5,"role":"radio","name":" Medium","state":["unchecked"]},{"index":6,"role":"radio","name":" Large","state":["unchecked"]},{"index":7,"role":"checkbox","name":" Bacon","state":["unchecked"]},{"index":8,"role":"checkbox","name":" Extra Cheese","state":["unchecked"]},{"index":9,"role":"checkbox","name":" Onion","state":["unchecked"]},{"index":10,"role":"checkbox","name":" Mushroom","state":["unchecked"]}],"total":10,"offset":0,"truncated":false,"settled":true,"dialog":null}
[exit 0]

```

Conclusion: snapshot lists only 10 rows (name, phone, email, 3 radios, 4 checkboxes). No row for the Comments textarea, the delivery-time input, or the Submit button. Suspicious; investigating with text/eval/--match.

```
$ leash snap t_5bd503a6bb8d892d87ca26d868f441a2 --owner l44-acceptance --match Submit
{"snapshot":"s_t_f72db527b231ed4497fcf02fd506d6a0","tab":"t_5bd503a6bb8d892d87ca26d868f441a2","url":"https://httpbin.org/forms/post","title":"httpbin.org/forms/post","rows":[],"total":0,"offset":0,"truncated":false,"settled":true,"dialog":null}
[exit 0]

```

```
$ leash snap t_5bd503a6bb8d892d87ca26d868f441a2 --owner l44-acceptance --table
INDEX	ROLE	NAME	VALUE	STATE
1	textbox	Customer name: 	-	
2	textbox	Telephone: 	-	
3	textbox	E-mail address: 	-	
4	radio	 Small	-	unchecked
5	radio	 Medium	-	unchecked
6	radio	 Large	-	unchecked
7	checkbox	 Bacon	-	unchecked
8	checkbox	 Extra Cheese	-	unchecked
9	checkbox	 Onion	-	unchecked
10	checkbox	 Mushroom	-	unchecked
[exit 0]

```

```
$ leash eval t_5bd503a6bb8d892d87ca26d868f441a2 'return [...document.querySelectorAll("input,textarea,button,select")].map(e=>e.tagName+":"+(e.type||"")+":"+e.name)' --owner l44-acceptance
{"value":["INPUT:text:custname","INPUT:tel:custtel","INPUT:email:custemail","INPUT:radio:size","INPUT:radio:size","INPUT:radio:size","INPUT:checkbox:topping","INPUT:checkbox:topping","INPUT:checkbox:topping","INPUT:checkbox:topping","INPUT:time:delivery","TEXTAREA:textarea:comments","BUTTON:submit:"]}
[exit 0]

```

```
$ leash text t_5bd503a6bb8d892d87ca26d868f441a2 --owner l44-acceptance
{"url":"https://httpbin.org/forms/post","title":"httpbin.org/forms/post","text":"Customer name: \n\nTelephone: \n\nE-mail address: \n\nPizza Size\n\n Small\n\n Medium\n\n Large\n\nPizza Toppings\n\n Bacon\n\n Extra Cheese\n\n Onion\n\n Mushroom\n\nPreferred delivery time: \n\nDelivery instructions: \n\nSubmit order","truncated":false}
[exit 0]

```

Conclusion: DOM has time input, textarea (comments) and submit button, `text` shows them, but `snap` omits them (even `--match Submit` -> 0 rows). Guess: they're below the viewport and snap only lists in-viewport rows? Trying `scroll down` then snap. (Skill says nothing about snap being viewport-limited.)

```
$ leash eval t_5bd503a6bb8d892d87ca26d868f441a2 'return {h:innerHeight,w:innerWidth,sh:document.documentElement.scrollHeight}' --owner l44-acceptance
{"value":{"h":944,"w":940,"sh":944}}
[exit 0]

```

```
$ leash scroll t_5bd503a6bb8d892d87ca26d868f441a2 down --owner l44-acceptance
{"tab":"t_5bd503a6bb8d892d87ca26d868f441a2","url":"https://httpbin.org/forms/post","title":"httpbin.org/forms/post","snapshot":null,"dialog":null,"popups":[]}
[exit 0]

```

```
$ leash snap t_5bd503a6bb8d892d87ca26d868f441a2 --owner l44-acceptance --table
INDEX	ROLE	NAME	VALUE	STATE
1	textbox	Customer name: 	-	
2	textbox	Telephone: 	-	
3	textbox	E-mail address: 	-	
4	radio	 Small	-	unchecked
5	radio	 Medium	-	unchecked
6	radio	 Large	-	unchecked
7	checkbox	 Bacon	-	unchecked
8	checkbox	 Extra Cheese	-	unchecked
9	checkbox	 Onion	-	unchecked
10	checkbox	 Mushroom	-	unchecked
[exit 0]

```

```
$ leash snap t_5bd503a6bb8d892d87ca26d868f441a2 --owner l44-acceptance --offset 8 --limit 50
{"snapshot":"s_t_b944721dcba2490639492108297ee850","tab":"t_5bd503a6bb8d892d87ca26d868f441a2","url":"https://httpbin.org/forms/post","title":"httpbin.org/forms/post","rows":[{"index":9,"role":"checkbox","name":" Onion","state":["unchecked"]},{"index":10,"role":"checkbox","name":" Mushroom","state":["unchecked"]}],"total":10,"offset":8,"truncated":false,"settled":true,"dialog":null}
[exit 0]

```

```
$ leash eval t_5bd503a6bb8d892d87ca26d868f441a2 'return [...document.querySelectorAll("input[type=time],textarea,button")].map(e=>{const r=e.getBoundingClientRect();return [e.tagName,r.x,r.y,r.width,r.height,getComputedStyle(e).visibility]})' --owner l44-acceptance
{"value":[["INPUT",164.8203125,500.6875,103.5,24,"visible"],["TEXTAREA",151.0859375,540.6875,182,37,"visible"],["BUTTON",8,597.6875,92.3046875,21.5,"visible"]]}
[exit 0]

```

Conclusion: elements are visible in-viewport (viewport 940x944, page not scrollable) yet not in snap. Not a viewport issue. Trying nav reload + fresh snap.

```
$ leash nav t_5bd503a6bb8d892d87ca26d868f441a2 https://httpbin.org/forms/post --owner l44-acceptance
{"tab":"t_5bd503a6bb8d892d87ca26d868f441a2","url":"https://httpbin.org/forms/post","title":"httpbin.org/forms/post","origin":"agent","state":"owned","owner":"l44-acceptance","generation":2,"dialog":null,"expires":{"stage":"release","in_s":1800}}
[exit 0]

```

```
$ leash snap t_5bd503a6bb8d892d87ca26d868f441a2 --owner l44-acceptance --table
INDEX	ROLE	NAME	VALUE	STATE
1	textbox	Customer name: 	-	
2	textbox	Telephone: 	-	
3	textbox	E-mail address: 	-	
4	radio	 Small	-	unchecked
5	radio	 Medium	-	unchecked
6	radio	 Large	-	unchecked
7	checkbox	 Bacon	-	unchecked
8	checkbox	 Extra Cheese	-	unchecked
9	checkbox	 Onion	-	unchecked
10	checkbox	 Mushroom	-	unchecked
[exit 0]

```

Conclusion: after reload still only 10 rows. The Comments textarea, delivery time, and Submit button are unreachable by snapshot row. **Skill/product gap**: no way documented to reach them. Skill forbids eval clicks. Plan: fill visible fields via fill/click; try `press` (Tab / Enter) from an indexed row for the rest. First `press --help`.

```
$ leash press --help | sed -n 1,40p
NAME
       leash-press - Press KEY; with --index the row is focused first.

SYNOPSIS
       leash press [OPTION]… TAB SNAPSHOT KEY

OPTIONS
       --config=FILE
           TOML configuration file the control socket is read from.

       --index=N
           Focus the row at index N before the key.

       --owner=NAME
           Request owner (default dsh:$DSH_SESSION_ID).

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
       leash press exits with:

       0   Success.

       64  Invalid request or invocation; fix the input.

       65  Invalid configuration, playbook, or stale page data.

       66  Unknown or gone tab, row, or network request.

       69  Service, browser, or model unavailable.
[exit 0]

```

```
$ leash snap t_5bd503a6bb8d892d87ca26d868f441a2 --owner l44-acceptance --limit 12
{"snapshot":"s_t_9d89e61dcffb5bfe24b1894776270506","tab":"t_5bd503a6bb8d892d87ca26d868f441a2","url":"https://httpbin.org/forms/post","title":"httpbin.org/forms/post","rows":[{"index":1,"role":"textbox","name":"Customer name: "},{"index":2,"role":"textbox","name":"Telephone: "},{"index":3,"role":"textbox","name":"E-mail address: "},{"index":4,"role":"radio","name":" Small","state":["unchecked"]},{"index":5,"role":"radio","name":" Medium","state":["unchecked"]},{"index":6,"role":"radio","name":" Large","state":["unchecked"]},{"index":7,"role":"checkbox","name":" Bacon","state":["unchecked"]},{"index":8,"role":"checkbox","name":" Extra Cheese","state":["unchecked"]},{"index":9,"role":"checkbox","name":" Onion","state":["unchecked"]},{"index":10,"role":"checkbox","name":" Mushroom","state":["unchecked"]}],"total":10,"offset":0,"truncated":false,"settled":true,"dialog":null}
[exit 0]

```

```
$ leash fill t_5bd503a6bb8d892d87ca26d868f441a2 s_t_9d89e61dcffb5bfe24b1894776270506 1 'Leash Tester'
[exit 77]
[stderr]
{"code":"not-owner","message":"the tab belongs to another owner","hint":"run `leash list --all` to see the owner; `leash claim TAB` takes an unowned tab"}

```

```
$ leash fill t_5bd503a6bb8d892d87ca26d868f441a2 s_t_9d89e61dcffb5bfe24b1894776270506 2 '555-0100'
[exit 77]
[stderr]
{"code":"not-owner","message":"the tab belongs to another owner","hint":"run `leash list --all` to see the owner; `leash claim TAB` takes an unowned tab"}

```
Deliberately reused the same snapshot id after a fill to see if input invalidates it.

CONCLUSION (accidental not-owner): my own slip — I omitted `--owner l44-acceptance` on the two fill calls, so the CLI fell back to the default `dsh:$DSH_SESSION_ID` identity (DSH_SESSION_ID is set in my env). The error `not-owner` / hint 'run `leash list --all` to see the owner; `leash claim TAB` takes an unowned tab' does not say 'check that your --owner matches' — the hint alone points toward claim, which would be wrong here (the tab is owned by me under another name). `list --all` did show owner l44-acceptance, which is the real clue. (The skill's errors.md does say 'Verify that your --owner or DSH_SESSION_ID has not changed' but the hint text itself omits it.) Note: I did not run `claim`. Retrying with --owner.

```
$ leash snap t_5bd503a6bb8d892d87ca26d868f441a2 --owner l44-acceptance --limit 12
{"snapshot":"s_t_84635a6f33cd4c36ca7508caf4143c8b","tab":"t_5bd503a6bb8d892d87ca26d868f441a2","url":"https://httpbin.org/forms/post","title":"httpbin.org/forms/post","rows":[{"index":1,"role":"textbox","name":"Customer name: "},{"index":2,"role":"textbox","name":"Telephone: "},{"index":3,"role":"textbox","name":"E-mail address: "},{"index":4,"role":"radio","name":" Small","state":["unchecked"]},{"index":5,"role":"radio","name":" Medium","state":["unchecked"]},{"index":6,"role":"radio","name":" Large","state":["unchecked"]},{"index":7,"role":"checkbox","name":" Bacon","state":["unchecked"]},{"index":8,"role":"checkbox","name":" Extra Cheese","state":["unchecked"]},{"index":9,"role":"checkbox","name":" Onion","state":["unchecked"]},{"index":10,"role":"checkbox","name":" Mushroom","state":["unchecked"]}],"total":10,"offset":0,"truncated":false,"settled":true,"dialog":null}
[exit 0]

```

```
$ leash fill t_5bd503a6bb8d892d87ca26d868f441a2 s_t_84635a6f33cd4c36ca7508caf4143c8b 1 'Leash Tester' --owner l44-acceptance
{"tab":"t_5bd503a6bb8d892d87ca26d868f441a2","url":"https://httpbin.org/forms/post","title":"httpbin.org/forms/post","snapshot":null,"dialog":null,"popups":[]}
[exit 0]

```

```
$ leash fill t_5bd503a6bb8d892d87ca26d868f441a2 s_t_84635a6f33cd4c36ca7508caf4143c8b 2 '555-0100' --owner l44-acceptance
{"tab":"t_5bd503a6bb8d892d87ca26d868f441a2","url":"https://httpbin.org/forms/post","title":"httpbin.org/forms/post","snapshot":null,"dialog":null,"popups":[]}
[exit 0]

```
Deliberately reused the same snapshot id after a fill to see whether input invalidates it.

Observation: the second fill reusing the same snapshot id succeeded (a fill does not stale the snapshot), contrary to the skill's blanket 'after input, take a fresh snapshot'. Not harmful.

```
$ leash snap t_5bd503a6bb8d892d87ca26d868f441a2 --owner l44-acceptance --limit 12
{"snapshot":"s_t_87dff8e4239909651ef495a642ab5e0f","tab":"t_5bd503a6bb8d892d87ca26d868f441a2","url":"https://httpbin.org/forms/post","title":"httpbin.org/forms/post","rows":[{"index":1,"role":"textbox","name":"Customer name: ","value":"Leash Tester"},{"index":2,"role":"textbox","name":"Telephone: ","value":"555-0100"},{"index":3,"role":"textbox","name":"E-mail address: "},{"index":4,"role":"radio","name":" Small","state":["unchecked"]},{"index":5,"role":"radio","name":" Medium","state":["unchecked"]},{"index":6,"role":"radio","name":" Large","state":["unchecked"]},{"index":7,"role":"checkbox","name":" Bacon","state":["unchecked"]},{"index":8,"role":"checkbox","name":" Extra Cheese","state":["unchecked"]},{"index":9,"role":"checkbox","name":" Onion","state":["unchecked"]},{"index":10,"role":"checkbox","name":" Mushroom","state":["unchecked"]}],"total":10,"offset":0,"truncated":false,"settled":true,"dialog":null}
[exit 0]

```

```
$ leash click t_5bd503a6bb8d892d87ca26d868f441a2 s_t_87dff8e4239909651ef495a642ab5e0f 6 --owner l44-acceptance
{"tab":"t_5bd503a6bb8d892d87ca26d868f441a2","url":"https://httpbin.org/forms/post","title":"httpbin.org/forms/post","snapshot":null,"dialog":null,"popups":[]}
[exit 0]

```

```
$ leash click t_5bd503a6bb8d892d87ca26d868f441a2 s_t_87dff8e4239909651ef495a642ab5e0f 7 --owner l44-acceptance
{"tab":"t_5bd503a6bb8d892d87ca26d868f441a2","url":"https://httpbin.org/forms/post","title":"httpbin.org/forms/post","snapshot":null,"dialog":null,"popups":[]}
[exit 0]

```

```
$ leash snap t_5bd503a6bb8d892d87ca26d868f441a2 --owner l44-acceptance --table
INDEX	ROLE	NAME	VALUE	STATE
1	textbox	Customer name: 	Leash Tester	
2	textbox	Telephone: 	555-0100	
3	textbox	E-mail address: 	-	
4	radio	 Small	-	unchecked
5	radio	 Medium	-	unchecked
6	radio	 Large	-	checked
7	checkbox	 Bacon	-	checked
8	checkbox	 Extra Cheese	-	unchecked
9	checkbox	 Onion	-	unchecked
10	checkbox	 Mushroom	-	unchecked
[exit 0]

```

Name, phone, Large, Bacon set and verified in snap. Comments textarea has no row: workaround attempt using only `press` (documented): focus row 10 (Mushroom), Tab, Tab, then check focus with read-only eval.

```
$ leash snap t_5bd503a6bb8d892d87ca26d868f441a2 --owner l44-acceptance --limit 12
{"snapshot":"s_t_173ed2d644bd13d31ec334440938eadc","tab":"t_5bd503a6bb8d892d87ca26d868f441a2","url":"https://httpbin.org/forms/post","title":"httpbin.org/forms/post","rows":[{"index":1,"role":"textbox","name":"Customer name: ","value":"Leash Tester"},{"index":2,"role":"textbox","name":"Telephone: ","value":"555-0100"},{"index":3,"role":"textbox","name":"E-mail address: "},{"index":4,"role":"radio","name":" Small","state":["unchecked"]},{"index":5,"role":"radio","name":" Medium","state":["unchecked"]},{"index":6,"role":"radio","name":" Large","state":["checked"]},{"index":7,"role":"checkbox","name":" Bacon","state":["checked"]},{"index":8,"role":"checkbox","name":" Extra Cheese","state":["unchecked"]},{"index":9,"role":"checkbox","name":" Onion","state":["unchecked"]},{"index":10,"role":"checkbox","name":" Mushroom","state":["unchecked"]}],"total":10,"offset":0,"truncated":false,"settled":true,"dialog":null}
[exit 0]

```

```
$ leash press t_5bd503a6bb8d892d87ca26d868f441a2 s_t_173ed2d644bd13d31ec334440938eadc Tab --index 10 --owner l44-acceptance
{"tab":"t_5bd503a6bb8d892d87ca26d868f441a2","url":"https://httpbin.org/forms/post","title":"httpbin.org/forms/post","snapshot":null,"dialog":null,"popups":[]}
[exit 0]

```

```
$ leash press t_5bd503a6bb8d892d87ca26d868f441a2 s_t_173ed2d644bd13d31ec334440938eadc Tab --owner l44-acceptance
{"tab":"t_5bd503a6bb8d892d87ca26d868f441a2","url":"https://httpbin.org/forms/post","title":"httpbin.org/forms/post","snapshot":null,"dialog":null,"popups":[]}
[exit 0]

```

```
$ leash eval t_5bd503a6bb8d892d87ca26d868f441a2 'return document.activeElement.tagName+":"+document.activeElement.name' --owner l44-acceptance
{"value":"INPUT:delivery"}
[exit 0]

```

```
$ leash snap t_5bd503a6bb8d892d87ca26d868f441a2 --owner l44-acceptance --limit 12
{"snapshot":"s_t_2f2a09d62f4742e2661753f406e9df37","tab":"t_5bd503a6bb8d892d87ca26d868f441a2","url":"https://httpbin.org/forms/post","title":"httpbin.org/forms/post","rows":[{"index":1,"role":"textbox","name":"Customer name: ","value":"Leash Tester"},{"index":2,"role":"textbox","name":"Telephone: ","value":"555-0100"},{"index":3,"role":"textbox","name":"E-mail address: "},{"index":4,"role":"radio","name":" Small","state":["unchecked"]},{"index":5,"role":"radio","name":" Medium","state":["unchecked"]},{"index":6,"role":"radio","name":" Large","state":["checked"]},{"index":7,"role":"checkbox","name":" Bacon","state":["checked"]},{"index":8,"role":"checkbox","name":" Extra Cheese","state":["unchecked"]},{"index":9,"role":"checkbox","name":" Onion","state":["unchecked"]},{"index":10,"role":"checkbox","name":" Mushroom","state":["unchecked"]}],"total":10,"offset":0,"truncated":false,"settled":true,"dialog":null}
[exit 0]

```

```
$ leash press t_5bd503a6bb8d892d87ca26d868f441a2 s_t_2f2a09d62f4742e2661753f406e9df37 Tab --owner l44-acceptance
{"tab":"t_5bd503a6bb8d892d87ca26d868f441a2","url":"https://httpbin.org/forms/post","title":"httpbin.org/forms/post","snapshot":null,"dialog":null,"popups":[]}
[exit 0]

```

```
$ leash eval t_5bd503a6bb8d892d87ca26d868f441a2 'return document.activeElement.tagName+":"+document.activeElement.name' --owner l44-acceptance
{"value":"INPUT:delivery"}
[exit 0]

```

```
$ leash press t_5bd503a6bb8d892d87ca26d868f441a2 s_t_2f2a09d62f4742e2661753f406e9df37 Tab --owner l44-acceptance
{"tab":"t_5bd503a6bb8d892d87ca26d868f441a2","url":"https://httpbin.org/forms/post","title":"httpbin.org/forms/post","snapshot":null,"dialog":null,"popups":[]}
[exit 0]

```

```
$ leash eval t_5bd503a6bb8d892d87ca26d868f441a2 'return document.activeElement.tagName+":"+document.activeElement.name' --owner l44-acceptance
{"value":"INPUT:delivery"}
[exit 0]

```

```
$ leash press t_5bd503a6bb8d892d87ca26d868f441a2 s_t_2f2a09d62f4742e2661753f406e9df37 Tab --owner l44-acceptance
{"tab":"t_5bd503a6bb8d892d87ca26d868f441a2","url":"https://httpbin.org/forms/post","title":"httpbin.org/forms/post","snapshot":null,"dialog":null,"popups":[]}
[exit 0]

```

```
$ leash eval t_5bd503a6bb8d892d87ca26d868f441a2 'return document.activeElement.tagName+":"+document.activeElement.name' --owner l44-acceptance
{"value":"TEXTAREA:comments"}
[exit 0]

```

Conclusion: focus is in TEXTAREA:comments after 1 (focus row 10) + 1 + 4 more Tabs (the time input eats several Tabs for its segments). Now typing via `press`: first a multi-char key to see what press accepts.

```
$ leash snap t_5bd503a6bb8d892d87ca26d868f441a2 --owner l44-acceptance --limit 12
{"snapshot":"s_t_7d540085fbe8b865254b974ba88d6f5b","tab":"t_5bd503a6bb8d892d87ca26d868f441a2","url":"https://httpbin.org/forms/post","title":"httpbin.org/forms/post","rows":[{"index":1,"role":"textbox","name":"Customer name: ","value":"Leash Tester"},{"index":2,"role":"textbox","name":"Telephone: ","value":"555-0100"},{"index":3,"role":"textbox","name":"E-mail address: "},{"index":4,"role":"radio","name":" Small","state":["unchecked"]},{"index":5,"role":"radio","name":" Medium","state":["unchecked"]},{"index":6,"role":"radio","name":" Large","state":["checked"]},{"index":7,"role":"checkbox","name":" Bacon","state":["checked"]},{"index":8,"role":"checkbox","name":" Extra Cheese","state":["unchecked"]},{"index":9,"role":"checkbox","name":" Onion","state":["unchecked"]},{"index":10,"role":"checkbox","name":" Mushroom","state":["unchecked"]}],"total":10,"offset":0,"truncated":false,"settled":true,"dialog":null}
[exit 0]

```

```
$ leash press t_5bd503a6bb8d892d87ca26d868f441a2 s_t_7d540085fbe8b865254b974ba88d6f5b 'ring the bell' --owner l44-acceptance
[exit 64]
[stderr]
{"code":"invalid-request","message":"unknown key name ring the bell","hint":"fix the request; `leash <command> --help` names the arguments and one example"}

```

Problem noted: `unknown key name ring the bell`; hint 'leash <command> --help names the arguments and one example' — press --help doesn't list valid key names (see below). Checking press --help examples.

```
$ leash press --help | sed -n '/EXAMPLES/,/ERRORS/p'
EXAMPLES
       leash press t_9xk s_3 Enter

ERRORS
[exit 0]

```

```
$ leash snap t_5bd503a6bb8d892d87ca26d868f441a2 --owner l44-acceptance --limit 12
{"snapshot":"s_t_c87cf0382dc9a5f542da6878aafd0154","tab":"t_5bd503a6bb8d892d87ca26d868f441a2","url":"https://httpbin.org/forms/post","title":"httpbin.org/forms/post","rows":[{"index":1,"role":"textbox","name":"Customer name: ","value":"Leash Tester"},{"index":2,"role":"textbox","name":"Telephone: ","value":"555-0100"},{"index":3,"role":"textbox","name":"E-mail address: "},{"index":4,"role":"radio","name":" Small","state":["unchecked"]},{"index":5,"role":"radio","name":" Medium","state":["unchecked"]},{"index":6,"role":"radio","name":" Large","state":["checked"]},{"index":7,"role":"checkbox","name":" Bacon","state":["checked"]},{"index":8,"role":"checkbox","name":" Extra Cheese","state":["unchecked"]},{"index":9,"role":"checkbox","name":" Onion","state":["unchecked"]},{"index":10,"role":"checkbox","name":" Mushroom","state":["unchecked"]}],"total":10,"offset":0,"truncated":false,"settled":true,"dialog":null}
[exit 0]

```

```
$ leash press t_5bd503a6bb8d892d87ca26d868f441a2 s_t_c87cf0382dc9a5f542da6878aafd0154 h --owner l44-acceptance
{"tab":"t_5bd503a6bb8d892d87ca26d868f441a2","url":"https://httpbin.org/forms/post","title":"httpbin.org/forms/post","snapshot":null,"dialog":null,"popups":[]}
[exit 0]

```

```
$ leash eval t_5bd503a6bb8d892d87ca26d868f441a2 'return document.querySelector("textarea").value' --owner l44-acceptance
{"value":"h"}
[exit 0]

```

Conclusion: single-character keys type into the focused textarea ('h' appeared in value). `press --help` only shows `Enter` example; valid key names undocumented (guessed that a single char works). Typing the rest: e,l,l,o then space.

```
$ leash snap t_5bd503a6bb8d892d87ca26d868f441a2 --owner l44-acceptance --limit 12
{"snapshot":"s_t_97960fbf35b09052c1ffd615ecf91df4","tab":"t_5bd503a6bb8d892d87ca26d868f441a2","url":"https://httpbin.org/forms/post","title":"httpbin.org/forms/post","rows":[{"index":1,"role":"textbox","name":"Customer name: ","value":"Leash Tester"},{"index":2,"role":"textbox","name":"Telephone: ","value":"555-0100"},{"index":3,"role":"textbox","name":"E-mail address: "},{"index":4,"role":"radio","name":" Small","state":["unchecked"]},{"index":5,"role":"radio","name":" Medium","state":["unchecked"]},{"index":6,"role":"radio","name":" Large","state":["checked"]},{"index":7,"role":"checkbox","name":" Bacon","state":["checked"]},{"index":8,"role":"checkbox","name":" Extra Cheese","state":["unchecked"]},{"index":9,"role":"checkbox","name":" Onion","state":["unchecked"]},{"index":10,"role":"checkbox","name":" Mushroom","state":["unchecked"]}],"total":10,"offset":0,"truncated":false,"settled":true,"dialog":null}
[exit 0]

```

(10 `leash press TAB SNAP '<char>'` calls for: e l l o <space> l e a s h; errors: [[" ","{\"code\":\"invalid-request\",\"message\":\"unknown key name  \",\"hint\":\"fix the request; `leash <command> --help` names the arguments and one example\"}\n"]])

```
$ leash eval t_5bd503a6bb8d892d87ca26d868f441a2 'return document.querySelector("textarea").value' --owner l44-acceptance
{"value":"helloleash"}
[exit 0]

```

Problem: key ' ' rejected: `unknown key name  ` — no way to know the name for space from help/skill. Textarea now 'helloleash'. Guess: 'Space'.

```
$ leash snap t_5bd503a6bb8d892d87ca26d868f441a2 --owner l44-acceptance --limit 12
{"snapshot":"s_t_af78e386b9dae6ea80deaacd9076318a","tab":"t_5bd503a6bb8d892d87ca26d868f441a2","url":"https://httpbin.org/forms/post","title":"httpbin.org/forms/post","rows":[{"index":1,"role":"textbox","name":"Customer name: ","value":"Leash Tester"},{"index":2,"role":"textbox","name":"Telephone: ","value":"555-0100"},{"index":3,"role":"textbox","name":"E-mail address: "},{"index":4,"role":"radio","name":" Small","state":["unchecked"]},{"index":5,"role":"radio","name":" Medium","state":["unchecked"]},{"index":6,"role":"radio","name":" Large","state":["checked"]},{"index":7,"role":"checkbox","name":" Bacon","state":["checked"]},{"index":8,"role":"checkbox","name":" Extra Cheese","state":["unchecked"]},{"index":9,"role":"checkbox","name":" Onion","state":["unchecked"]},{"index":10,"role":"checkbox","name":" Mushroom","state":["unchecked"]}],"total":10,"offset":0,"truncated":false,"settled":true,"dialog":null}
[exit 0]

```

```
$ leash press t_5bd503a6bb8d892d87ca26d868f441a2 s_t_af78e386b9dae6ea80deaacd9076318a Space --owner l44-acceptance
{"tab":"t_5bd503a6bb8d892d87ca26d868f441a2","url":"https://httpbin.org/forms/post","title":"httpbin.org/forms/post","snapshot":null,"dialog":null,"popups":[]}
[exit 0]

```

```
$ leash eval t_5bd503a6bb8d892d87ca26d868f441a2 'return document.querySelector("textarea").value' --owner l44-acceptance
{"value":"helloleash "}
[exit 0]

```

Conclusion: 'Space' is the key name for space (guess, undocumented). Typing 'ok', then submit. Submit button has no row, so submission by implicit form submission: `press Enter --index 1` on the name textbox (guess; the skill says 'Do not ... repeated Enter presses' but only for blind chains). This is a test site designed for echoing form posts, so submission is authorized by the task.

```
$ leash snap t_5bd503a6bb8d892d87ca26d868f441a2 --owner l44-acceptance --limit 12
{"snapshot":"s_t_7114ab707a3deef289c130f4809a2b72","tab":"t_5bd503a6bb8d892d87ca26d868f441a2","url":"https://httpbin.org/forms/post","title":"httpbin.org/forms/post","rows":[{"index":1,"role":"textbox","name":"Customer name: ","value":"Leash Tester"},{"index":2,"role":"textbox","name":"Telephone: ","value":"555-0100"},{"index":3,"role":"textbox","name":"E-mail address: "},{"index":4,"role":"radio","name":" Small","state":["unchecked"]},{"index":5,"role":"radio","name":" Medium","state":["unchecked"]},{"index":6,"role":"radio","name":" Large","state":["checked"]},{"index":7,"role":"checkbox","name":" Bacon","state":["checked"]},{"index":8,"role":"checkbox","name":" Extra Cheese","state":["unchecked"]},{"index":9,"role":"checkbox","name":" Onion","state":["unchecked"]},{"index":10,"role":"checkbox","name":" Mushroom","state":["unchecked"]}],"total":10,"offset":0,"truncated":false,"settled":true,"dialog":null}
[exit 0]

```

```
$ leash press t_5bd503a6bb8d892d87ca26d868f441a2 s_t_7114ab707a3deef289c130f4809a2b72 o --owner l44-acceptance
{"tab":"t_5bd503a6bb8d892d87ca26d868f441a2","url":"https://httpbin.org/forms/post","title":"httpbin.org/forms/post","snapshot":null,"dialog":null,"popups":[]}
[exit 0]

```

```
$ leash press t_5bd503a6bb8d892d87ca26d868f441a2 s_t_7114ab707a3deef289c130f4809a2b72 k --owner l44-acceptance
{"tab":"t_5bd503a6bb8d892d87ca26d868f441a2","url":"https://httpbin.org/forms/post","title":"httpbin.org/forms/post","snapshot":null,"dialog":null,"popups":[]}
[exit 0]

```

```
$ leash eval t_5bd503a6bb8d892d87ca26d868f441a2 'return [...new FormData(document.forms[0]).entries()]' --owner l44-acceptance
{"value":[["custname","Leash Tester"],["custtel","555-0100"],["custemail",""],["size","large"],["topping","bacon"],["delivery",""],["comments","helloleash ok"]]}
[exit 0]

```
Verifying form values (read-only) before submitting.

```
$ leash press t_5bd503a6bb8d892d87ca26d868f441a2 s_t_7114ab707a3deef289c130f4809a2b72 Enter --index 1 --owner l44-acceptance
{"tab":"t_5bd503a6bb8d892d87ca26d868f441a2","url":"https://httpbin.org/forms/post","title":"httpbin.org/forms/post","snapshot":null,"dialog":null,"popups":[]}
[exit 0]

```

```
$ leash wait t_5bd503a6bb8d892d87ca26d868f441a2 --text 'custname' --timeout-ms 8000 --owner l44-acceptance
{"tab":"t_5bd503a6bb8d892d87ca26d868f441a2","url":"https://httpbin.org/post","title":"httpbin.org/post","snapshot":null,"dialog":null,"popups":[]}
[exit 0]

```

```
$ leash text t_5bd503a6bb8d892d87ca26d868f441a2 --owner l44-acceptance
{"url":"https://httpbin.org/post","title":"httpbin.org/post","text":"{\n  \"args\": {}, \n  \"data\": \"\", \n  \"files\": {}, \n  \"form\": {\n    \"comments\": \"helloleash ok\", \n    \"custemail\": \"\", \n    \"custname\": \"Leash Tester\", \n    \"custtel\": \"555-0100\", \n    \"delivery\": \"\", \n    \"size\": \"large\", \n    \"topping\": \"bacon\"\n  }, \n  \"headers\": {\n    \"Accept\": \"text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8,application/signed-exchange;v=b3;q=0.7\", \n    \"Accept-Encoding\": \"gzip, deflate, br, zstd\", \n    \"Accept-Language\": \"en-US,en;q=0.9\", \n    \"Cache-Control\": \"max-age=0\", \n    \"Content-Length\": \"107\", \n    \"Content-Type\": \"application/x-www-form-urlencoded\", \n    \"Host\": \"httpbin.org\", \n    \"Origin\": \"https://httpbin.org\", \n    \"Priority\": \"u=0, i\", \n    \"Referer\": \"https://httpbin.org/forms/post\", \n    \"Sec-Ch-Ua\": \"\\\"Chromium\\\";v=\\\"152\\\", \\\"Not?A_Brand\\\";v=\\\"24\\\", \\\"Google Chrome\\\";v=\\\"152\\\"\", \n    \"Sec-Ch-Ua-Mobile\": \"?0\", \n    \"Sec-Ch-Ua-Platform\": \"\\\"Linux\\\"\", \n    \"Sec-Fetch-Dest\": \"document\", \n    \"Sec-Fetch-Mode\": \"navigate\", \n    \"Sec-Fetch-Site\": \"same-origin\", \n    \"Sec-Fetch-User\": \"?1\", \n    \"Upgrade-Insecure-Requests\": \"1\", \n    \"User-Agent\": \"Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/152.0.0.0 Safari/537.36\", \n    \"X
```

**Step 1 result: PASS (with workaround).** Result page https://httpbin.org/post echoed form: custname "Leash Tester", custtel "555-0100", size "large", topping "bacon", comments "helloleash ok". Problems: snapshot did not expose the time input, the Comments textarea or the Submit button; had to reach textarea via Tab presses + one-char `press` keys and submit via Enter on the name box. The skill says 'Do not turn a whole form into a blind chain of guessed indices or repeated Enter presses' but offers no path for unlisted controls.

## Step 2: text + bounded eval

```
$ leash nav t_5bd503a6bb8d892d87ca26d868f441a2 https://example.com --owner l44-acceptance
{"tab":"t_5bd503a6bb8d892d87ca26d868f441a2","url":"https://example.com/","title":"Example Domain","origin":"agent","state":"owned","owner":"l44-acceptance","generation":2,"dialog":null,"expires":{"stage":"release","in_s":1800}}
[exit 0]

```

```
$ leash text t_5bd503a6bb8d892d87ca26d868f441a2 --max-chars 500 --owner l44-acceptance
{"url":"https://example.com/","title":"Example Domain","text":"This domain is for use in documentation examples without needing permission. This is not a service, avoid relying on it for testing and monitoring purposes.\n\nهذا النطاق مُخصص للاستخدام في أمثلة التوثيق دون الحاجة إلى إذن. هذه ليست خدمة، يُرجى تجنب الاعتماد عليها لأغراض الاختبار والمراقبة.\n\n该域名仅用于文档示例，无需获得许可。这并非一项服务，请勿将其用于测试和监控目的。\n\nL’usage de ce domaine est réservé à des exemples de documentation, sans autorisation préalable. Il ne s’agit pas d’un service ; son utilisation à des fins de test ou d","truncated":true}
[exit 0]

```

```
$ leash eval t_5bd503a6bb8d892d87ca26d868f441a2 'return {title: document.title, links: document.querySelectorAll("a").length}' --owner l44-acceptance
{"value":{"title":"Example Domain","links":1}}
[exit 0]

```

**Step 2 result: PASS.** (see title and link count above)

## Step 3: network
Note: net ring begins at tab creation/attach, so navigating within the same tab is fine.

```
$ leash nav t_5bd503a6bb8d892d87ca26d868f441a2 https://httpbin.org/ --owner l44-acceptance
{"tab":"t_5bd503a6bb8d892d87ca26d868f441a2","url":"https://httpbin.org/","title":"httpbin.org","origin":"agent","state":"owned","owner":"l44-acceptance","generation":2,"dialog":null,"expires":{"stage":"release","in_s":1800}}
[exit 0]

```

```
$ leash wait t_5bd503a6bb8d892d87ca26d868f441a2 --text 'httpbin' --timeout-ms 10000 --owner l44-acceptance
{"tab":"t_5bd503a6bb8d892d87ca26d868f441a2","url":"https://httpbin.org/","title":"httpbin.org","snapshot":null,"dialog":null,"popups":[]}
[exit 0]

```

```
$ leash net t_5bd503a6bb8d892d87ca26d868f441a2 --type xhr --owner l44-acceptance
{"requests":[]}
[exit 0]

```

```
$ leash net t_5bd503a6bb8d892d87ca26d868f441a2 --type fetch --owner l44-acceptance
{"requests":[]}
[exit 0]

```

Conclusion: `--type xhr` and `--type fetch` first returned [] right after nav, but an unfiltered `net` a moment later shows `GET https://httpbin.org/spec.json type=fetch id 3874066.52`. Most likely the swagger UI fetch simply hadn't happened yet when I listed (the `wait --text httpbin` was satisfied instantly). Re-listing with --type fetch. (Also: unfiltered net includes many data: URLs and fonts — long output.)

```
$ leash net t_5bd503a6bb8d892d87ca26d868f441a2 --type fetch --owner l44-acceptance
{"requests":[{"id":"3874066.52","method":"GET","url":"https://httpbin.org/spec.json","status":200,"type":"fetch","mime":"application/json","size":41215,"duration_ms":282,"from_cache":false}]}
[exit 0]

```

```
$ leash net t_5bd503a6bb8d892d87ca26d868f441a2 request 3874066.52 --owner l44-acceptance
{"id":"3874066.52","method":"GET","url":"https://httpbin.org/spec.json","headers":{"sec-ch-ua-platform":"\"Linux\"","Referer":"https://httpbin.org/","User-Agent":"Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/152.0.0.0 Safari/537.36","sec-ch-ua":"\"Chromium\";v=\"152\", \"Not?A_Brand\";v=\"24\", \"Google Chrome\";v=\"152\"","sec-ch-ua-mobile":"?0"},"base64":false,"truncated":false}
[exit 0]

```

```
$ leash net t_5bd503a6bb8d892d87ca26d868f441a2 body 3874066.52 --owner l44-acceptance | jq -c '{keys:keys, truncated:.truncated, base64:.base64, len:(.body|length), head:(.body|.[0:120])}'
{"keys":["base64","body","bytes","id","truncated"],"truncated":false,"base64":false,"len":41019,"head":"{\n  \"basePath\": \"/\", \n  \"definitions\": {}, \n  \"host\": \"httpbin.org\", \n  \"info\": {\n    \"contact\": {\n      \"email\": \"me@ke"}
[exit 0]

```

**Step 3 result: PASS.** Found GET https://httpbin.org/spec.json (type fetch), read its body via `net TAB body ID` (41019 chars, base64 false, truncated false). Minor: immediately after nav the type-filtered list was empty (timing) — skill doesn't say the ring only shows requests that have already happened / to wait.

## Step 4: dialogs and popups

```
$ leash nav t_5bd503a6bb8d892d87ca26d868f441a2 https://the-internet.herokuapp.com/javascript_alerts --owner l44-acceptance
{"tab":"t_5bd503a6bb8d892d87ca26d868f441a2","url":"https://the-internet.herokuapp.com/javascript_alerts","title":"The Internet","origin":"agent","state":"owned","owner":"l44-acceptance","generation":2,"dialog":null,"expires":{"stage":"release","in_s":1800}}
[exit 0]

```

```
$ leash snap t_5bd503a6bb8d892d87ca26d868f441a2 --owner l44-acceptance --table
INDEX	ROLE	NAME	VALUE	STATE
1	heading	JavaScript Alerts	-	
2	paragraph	Here are some examples of different JavaScript alerts which can be troublesome for automation	-	
3	button	Click for JS Alert	-	
4	button	Click for JS Confirm	-	
5	button	Click for JS Prompt	-	
6	heading	Result:	-	
7	link	Elemental Selenium	-	
[exit 0]

```

```
$ leash snap t_5bd503a6bb8d892d87ca26d868f441a2 --owner l44-acceptance
{"snapshot":"s_t_2e46abd4a4b52925da15ee366e690182","tab":"t_5bd503a6bb8d892d87ca26d868f441a2","url":"https://the-internet.herokuapp.com/javascript_alerts","title":"The Internet","rows":[{"index":1,"role":"heading","name":"JavaScript Alerts"},{"index":2,"role":"paragraph","name":"Here are some examples of different JavaScript alerts which can be troublesome for automation"},{"index":3,"role":"button","name":"Click for JS Alert"},{"index":4,"role":"button","name":"Click for JS Confirm"},{"index":5,"role":"button","name":"Click for JS Prompt"},{"index":6,"role":"heading","name":"Result:"},{"index":7,"role":"link","name":"Elemental Selenium"}],"total":7,"offset":0,"truncated":false,"settled":true,"dialog":null}
[exit 0]

```

```
$ leash click t_5bd503a6bb8d892d87ca26d868f441a2 s_t_2e46abd4a4b52925da15ee366e690182 3 --owner l44-acceptance
{"tab":"t_5bd503a6bb8d892d87ca26d868f441a2","url":"https://the-internet.herokuapp.com/javascript_alerts","title":"The Internet","snapshot":null,"dialog":{"kind":"alert","message":"I am a JS Alert","default_prompt":""},"popups":[]}
[exit 0]

```

```
$ leash snap t_5bd503a6bb8d892d87ca26d868f441a2 --owner l44-acceptance --table
INDEX	ROLE	NAME	VALUE	STATE
[exit 0]

```
Snap while dialog open (skill says dialog is state in snapshots).

```
$ leash snap t_5bd503a6bb8d892d87ca26d868f441a2 --owner l44-acceptance
{"snapshot":"s_t_7acd48358cd9ed24d5c48e0f59c71ba7","tab":"t_5bd503a6bb8d892d87ca26d868f441a2","url":"https://the-internet.herokuapp.com/javascript_alerts","title":"The Internet","rows":[],"total":0,"offset":0,"truncated":false,"settled":false,"dialog":{"kind":"alert","message":"I am a JS Alert","default_prompt":""}}
[exit 0]

```

```
$ leash dialog t_5bd503a6bb8d892d87ca26d868f441a2 accept --owner l44-acceptance
{"tab":"t_5bd503a6bb8d892d87ca26d868f441a2","url":"https://the-internet.herokuapp.com/javascript_alerts","title":"The Internet","snapshot":null,"dialog":null,"popups":[]}
[exit 0]

```

Conclusion: click reply carried `dialog:{kind:alert,...}`; snap with dialog open returned 0 rows and settled:false (expected/consistent w/ skill); `dialog accept` cleared it. Now confirm; I'll dismiss it this time to see distinct result text.

```
$ leash text t_5bd503a6bb8d892d87ca26d868f441a2 --index 6 --owner l44-acceptance
[exit 66]
[stderr]
{"code":"no-such-row","message":"the snapshot has no such row","hint":"that index is not in the snapshot; `leash snap TAB` and use a listed index"}

```
(text --index uses current row table; expected to fail or be stale since I took no snapshot after dialog — see result)

```
$ leash snap t_5bd503a6bb8d892d87ca26d868f441a2 --owner l44-acceptance
{"snapshot":"s_t_e370116ea0d6d5e07a62d49d8e629dd6","tab":"t_5bd503a6bb8d892d87ca26d868f441a2","url":"https://the-internet.herokuapp.com/javascript_alerts","title":"The Internet","rows":[{"index":1,"role":"heading","name":"JavaScript Alerts"},{"index":2,"role":"paragraph","name":"Here are some examples of different JavaScript alerts which can be troublesome for automation"},{"index":3,"role":"button","name":"Click for JS Alert"},{"index":4,"role":"button","name":"Click for JS Confirm"},{"index":5,"role":"button","name":"Click for JS Prompt"},{"index":6,"role":"heading","name":"Result:"},{"index":7,"role":"paragraph","name":"You successfully clicked an alert"}],"total":7,"offset":0,"truncated":false,"settled":true,"dialog":null}
[exit 0]

```

```
$ leash click t_5bd503a6bb8d892d87ca26d868f441a2 s_t_e370116ea0d6d5e07a62d49d8e629dd6 4 --owner l44-acceptance
{"tab":"t_5bd503a6bb8d892d87ca26d868f441a2","url":"https://the-internet.herokuapp.com/javascript_alerts","title":"The Internet","snapshot":null,"dialog":{"kind":"confirm","message":"I am a JS Confirm","default_prompt":""},"popups":[]}
[exit 0]

```

```
$ leash dialog t_5bd503a6bb8d892d87ca26d868f441a2 dismiss --owner l44-acceptance
{"tab":"t_5bd503a6bb8d892d87ca26d868f441a2","url":"https://the-internet.herokuapp.com/javascript_alerts","title":"The Internet","snapshot":null,"dialog":null,"popups":[]}
[exit 0]

```

```
$ leash text t_5bd503a6bb8d892d87ca26d868f441a2 --owner l44-acceptance
{"url":"https://the-internet.herokuapp.com/javascript_alerts","title":"The Internet","text":"JavaScript Alerts\n\nHere are some examples of different JavaScript alerts which can be troublesome for automation\n\nClick for JS Alert\nClick for JS Confirm\nClick for JS Prompt\nResult:\n\nYou clicked: Cancel\n\nPowered by Elemental Selenium","truncated":false}
[exit 0]

```

Alert accepted, confirm dismissed; page shows 'You clicked: Cancel'. (The `text --index 6` error above was my own slip: last snapshot was taken with the dialog open and had 0 rows -> `no-such-row`, hint was adequate.) Note: dialog reply `default_prompt` present; no dialog handling was 'automatic'.

Now popup.

```
$ leash nav t_5bd503a6bb8d892d87ca26d868f441a2 https://the-internet.herokuapp.com/windows --owner l44-acceptance
{"tab":"t_5bd503a6bb8d892d87ca26d868f441a2","url":"https://the-internet.herokuapp.com/windows","title":"The Internet","origin":"agent","state":"owned","owner":"l44-acceptance","generation":2,"dialog":null,"expires":{"stage":"release","in_s":1800}}
[exit 0]

```

```
$ leash snap t_5bd503a6bb8d892d87ca26d868f441a2 --owner l44-acceptance --table
INDEX	ROLE	NAME	VALUE	STATE
1	heading	Opening a new window	-	
2	link	Click Here	-	
3	link	Elemental Selenium	-	
[exit 0]

```

```
$ leash snap t_5bd503a6bb8d892d87ca26d868f441a2 --owner l44-acceptance
{"snapshot":"s_t_0399996d1ef11c67bea6884e8a81eaa4","tab":"t_5bd503a6bb8d892d87ca26d868f441a2","url":"https://the-internet.herokuapp.com/windows","title":"The Internet","rows":[{"index":1,"role":"heading","name":"Opening a new window"},{"index":2,"role":"link","name":"Click Here"},{"index":3,"role":"link","name":"Elemental Selenium"}],"total":3,"offset":0,"truncated":false,"settled":true,"dialog":null}
[exit 0]

```

```
$ leash click t_5bd503a6bb8d892d87ca26d868f441a2 s_t_0399996d1ef11c67bea6884e8a81eaa4 2 --owner l44-acceptance
{"tab":"t_5bd503a6bb8d892d87ca26d868f441a2","url":"https://the-internet.herokuapp.com/windows","title":"The Internet","snapshot":null,"dialog":null,"popups":[{"tab":"t_b3d3ee519319f57216a61350eebde8f1","url":"","title":"","origin":"agent","state":"owned","owner":"l44-acceptance","generation":2,"dialog":null,"expires":{"stage":"release","in_s":1800}}]}
[exit 0]

```

```
$ leash list --owner l44-acceptance --table
TAB	URL	TITLE	ORIGIN	STATE	OWNER	REASON
t_5bd503a6bb8d892d87ca26d868f441a2	https://the-internet.herokuapp.com/windows	The Internet	agent	owned	l44-acceptance	-
t_b3d3ee519319f57216a61350eebde8f1	https://the-internet.herokuapp.com/windows/new	the-internet.herokuapp.com/windows/new	agent	owned	l44-acceptance	-
[exit 0]

```

Conclusion: click reply listed `popups` with an owned tab handle; note its url/title were empty in the click reply (popup still loading), while `list` shortly after showed the real URL /windows/new. Reading popup:

```
$ leash text t_b3d3ee519319f57216a61350eebde8f1 --owner l44-acceptance
{"url":"https://the-internet.herokuapp.com/windows/new","title":"the-internet.herokuapp.com/windows/new","text":"New Window","truncated":false}
[exit 0]

```

**Step 4 result: PASS.**

## Step 5: download

```
$ leash nav t_5bd503a6bb8d892d87ca26d868f441a2 https://the-internet.herokuapp.com/download --owner l44-acceptance
{"tab":"t_5bd503a6bb8d892d87ca26d868f441a2","url":"https://the-internet.herokuapp.com/download","title":"The Internet","origin":"agent","state":"owned","owner":"l44-acceptance","generation":2,"dialog":null,"expires":{"stage":"release","in_s":1800}}
[exit 0]

```

```
$ leash snap t_5bd503a6bb8d892d87ca26d868f441a2 --owner l44-acceptance --limit 12 --table
INDEX	ROLE	NAME	VALUE	STATE
1	heading	File Downloader	-	
2	link	r2_test_upload_bmwz_71o.txt	-	
3	link	random_data_18.txt	-	
4	link	referto_sperimentale_CX881.txt	-	
5	link	examplefile.json	-	
6	link	sample-1mb-test-file.dat	-	
7	link	test-upload.txt	-	
8	link	tmp3soc7qq4.txt	-	
9	link	tmpmaqga2jk.txt	-	
10	link	sample.pdf	-	
11	link	upload-17628522055331900173.txt	-	
12	link	sample.txt	-	
[exit 0]

```

```
$ leash snap t_5bd503a6bb8d892d87ca26d868f441a2 --owner l44-acceptance --limit 12
{"snapshot":"s_t_e9f8ecd44c847355bae524d79d14796d","tab":"t_5bd503a6bb8d892d87ca26d868f441a2","url":"https://the-internet.herokuapp.com/download","title":"The Internet","rows":[{"index":1,"role":"heading","name":"File Downloader"},{"index":2,"role":"link","name":"r2_test_upload_bmwz_71o.txt"},{"index":3,"role":"link","name":"random_data_18.txt"},{"index":4,"role":"link","name":"referto_sperimentale_CX881.txt"},{"index":5,"role":"link","name":"examplefile.json"},{"index":6,"role":"link","name":"sample-1mb-test-file.dat"},{"index":7,"role":"link","name":"test-upload.txt"},{"index":8,"role":"link","name":"tmp3soc7qq4.txt"},{"index":9,"role":"link","name":"tmpmaqga2jk.txt"},{"index":10,"role":"link","name":"sample.pdf"},{"index":11,"role":"link","name":"upload-17628522055331900173.txt"},{"index":12,"role":"link","name":"sample.txt"}],"total":26,"offset":0,"truncated":true,"settled":true,"dialog":null}
[exit 0]

```

```
$ leash click t_5bd503a6bb8d892d87ca26d868f441a2 s_t_e9f8ecd44c847355bae524d79d14796d 5 --owner l44-acceptance
{"tab":"t_5bd503a6bb8d892d87ca26d868f441a2","url":"https://the-internet.herokuapp.com/download","title":"The Internet","snapshot":null,"dialog":null,"popups":[]}
[exit 0]

```
Clicking examplefile.json (row 5).

```
$ leash downloads t_5bd503a6bb8d892d87ca26d868f441a2 --owner l44-acceptance
{"downloads":[{"id":"5a001e7f-366e-497f-9cb9-5b3584ec881b","suggested_name":"examplefile.json","mime":"application/octet-stream","state":"completed","path":"/home/ribelo/.local/share/leash/profile/downloads/examplefile.json"}]}
[exit 0]

```

```
$ ls -l .../downloads/examplefile.json; head -c 200
-rw-r--r-- 1 ribelo users 0 Sep 30 11:53 /home/ribelo/.local/share/leash/profile/downloads/examplefile.json

```
**Step 5 result: PASS.** `downloads TAB` reported state completed with path; file exists on disk.

## Step 6: drive

Note: the downloaded file is 0 bytes; verified with `curl -sI` that the source examplefile.json has Content-Length: 0, so the download is faithful, but `downloads` reports no byte size, so an agent can't tell an empty download from a good one without `ls`. Trying a second file (sample.txt) for a non-empty check.

```
$ leash snap t_5bd503a6bb8d892d87ca26d868f441a2 --owner l44-acceptance --limit 12
{"snapshot":"s_t_861ce8c328fa31c55ab330f40de33715","tab":"t_5bd503a6bb8d892d87ca26d868f441a2","url":"https://the-internet.herokuapp.com/download","title":"The Internet","rows":[{"index":1,"role":"heading","name":"File Downloader"},{"index":2,"role":"link","name":"r2_test_upload_bmwz_71o.txt"},{"index":3,"role":"link","name":"random_data_18.txt"},{"index":4,"role":"link","name":"referto_sperimentale_CX881.txt"},{"index":5,"role":"link","name":"examplefile.json"},{"index":6,"role":"link","name":"sample-1mb-test-file.dat"},{"index":7,"role":"link","name":"test-upload.txt"},{"index":8,"role":"link","name":"tmp3soc7qq4.txt"},{"index":9,"role":"link","name":"tmpmaqga2jk.txt"},{"index":10,"role":"link","name":"sample.pdf"},{"index":11,"role":"link","name":"upload-17628522055331900173.txt"},{"index":12,"role":"link","name":"sample.txt"}],"total":26,"offset":0,"truncated":true,"settled":true,"dialog":null}
[exit 0]

```

```
$ leash click t_5bd503a6bb8d892d87ca26d868f441a2 s_t_861ce8c328fa31c55ab330f40de33715 12 --owner l44-acceptance
{"tab":"t_5bd503a6bb8d892d87ca26d868f441a2","url":"https://the-internet.herokuapp.com/download","title":"The Internet","snapshot":null,"dialog":null,"popups":[]}
[exit 0]

```

```
$ leash downloads t_5bd503a6bb8d892d87ca26d868f441a2 --owner l44-acceptance
{"downloads":[{"id":"5a001e7f-366e-497f-9cb9-5b3584ec881b","suggested_name":"examplefile.json","mime":"application/octet-stream","state":"completed","path":"/home/ribelo/.local/share/leash/profile/downloads/examplefile.json"},{"id":"3d2e0814-2fe3-4357-b7d2-e80bc0d89e07","suggested_name":"sample.txt","mime":"application/octet-stream","state":"completed","path":"/home/ribelo/.local/share/leash/profile/downloads/sample.txt"}]}
[exit 0]

```

```
$ ls -l /home/ribelo/.local/share/leash/profile/downloads/
total 4
-rw-r--r-- 1 ribelo users  0 Sep 30 11:53 examplefile.json
-rw-r--r-- 1 ribelo users 16 Sep 30 11:53 sample.txt
[exit 0]

```

**Step 5 result: PASS.** `downloads` reported examplefile.json (completed, path); second download sample.txt is 16 bytes on disk.

(Note: I've also written help.txt and, below, drive-out.jsonl in /tmp/leash-l44 — the first was my help capture, the second is the requested `--out` file.)

```
$ cat /tmp/leash-l44/drive-result.json; echo; wc -c /tmp/leash-l44/drive-out.jsonl
{"playbook_choices":[],"status":"blocked","site":null,"procedures":[],"mission_expectations":[],"planner_turns":[],"proposals":[],"collected":0,"data":{"model_calls_by_kind":{"operator":1},"cost_unreported":0,"count":0,"first":[],"pages":0,"scripts":[]},"model_calls":1,"model_cost":2.604e-05,"operator_steps":[{"n":1,"snapshot":"s_t_6f056a02513ef1279a6025d851436268","operation":"blocked","index":null,"probabilities":{"op":{"WAIT":0.02,"BLOCKED":0.98,"DONE":0.0},"target":{}},"after":{"url":"about:blank","title":""},"elapsed_ms":782}],"final":{"snapshot":"s_t_6f056a02513ef1279a6025d851436268","tab":"t_9982af4b82686eed4d4aded0988bc3f1","url":"about:blank","title":"","rows":[],"total":0,"offset":0,"truncated":false,"settled":true,"dialog":null}}

0 /tmp/leash-l44/drive-out.jsonl
[exit 0]

```
Attempt 1 (executed in background job bash-2246): `leash drive 'On https://books.toscrape.com collect every book title and price in the Travel category' --expect 'the page shows the Travel category' --out /tmp/leash-l44/drive-out.jsonl --deadline-s 300 --max-procedures 8 --owner l44-acceptance` → exit 0 within ~1s, but result `status:"blocked"`, `playbook_choices:[]`, `collected:0`, final url about:blank; it opened a new tab t_9982af4b… on about:blank and left it. Exit 0 with blocked is documented in the skill ('inspect status'). But the skill does not say the no-playbook operator cannot navigate to a URL from the mission text, nor why it was blocked (no `reason` field in reply).

```
$ leash playbook list --owner l44-acceptance
[exit 124]
[stderr]
{"code":"cli-parse","message":"invalid command line; the command did not run","hint":"the command line did not parse; `leash <command> --help` shows the accepted form","detail":{"diagnostic":"Usage: leash playbook list [--help] [OPTION]…\nleash: unknown option '--owner'"}}

```

```
$ leash list --owner l44-acceptance --table
TAB	URL	TITLE	ORIGIN	STATE	OWNER	REASON
t_5bd503a6bb8d892d87ca26d868f441a2	https://the-internet.herokuapp.com/download	The Internet	agent	owned	l44-acceptance	-
t_9982af4b82686eed4d4aded0988bc3f1	about:blank		agent	owned	l44-acceptance	-
t_b3d3ee519319f57216a61350eebde8f1	https://the-internet.herokuapp.com/windows/new	the-internet.herokuapp.com/windows/new	agent	owned	l44-acceptance	-
[exit 0]

```

Note: `playbook list --owner` → cli-parse 'unknown option --owner' (playbook list is local; skill browser.md says 'Pass --owner NAME on every service call' and lifecycle says local commands don't need it — consistent but easy to trip on). Retrying without owner.

```
$ leash playbook list
[exit 0]

```

Attempt 2 plan: reuse my own tab, pre-navigated to the Travel category page, and mission text says 'the current page'. Use --tab.

```
$ leash nav t_5bd503a6bb8d892d87ca26d868f441a2 https://books.toscrape.com/catalogue/category/books/travel_2/index.html --owner l44-acceptance
{"tab":"t_5bd503a6bb8d892d87ca26d868f441a2","url":"https://books.toscrape.com/catalogue/category/books/travel_2/index.html","title":"Travel | Books to Scrape - Sandbox","origin":"agent","state":"owned","owner":"l44-acceptance","generation":2,"dialog":null,"expires":{"stage":"release","in_s":1800}}
[exit 0]

```

```
$ leash text t_5bd503a6bb8d892d87ca26d868f441a2 --max-chars 300 --owner l44-acceptance
{"url":"https://books.toscrape.com/catalogue/category/books/travel_2/index.html","title":"Travel | Books to Scrape - Sandbox","text":"Books to Scrape We love being scraped!\nHome  Books Travel\nBooks\nTravel\nMystery\nHistorical Fiction\nSequential Art\nClassics\nPhilosophy\nRomance\nWomens Fiction\nFiction\nChildrens\nReligion\nNonfiction\nMusic\nDefault\nScience Fiction\nSports and Games\nAdd a comment\nFantasy\nNew Adult\nYoung Adult\nScience\nPoetry\n","truncated":true}
[exit 0]

```

Attempt 2 (drive --tab, own Travel page): exit 69, stderr: ```{"code":"model-unavailable","message":"timed out","hint":"read detail.code; set OPENROUTER_API_KEY or fix the model config, then retry","detail":{"code":"timeout","site":null,"procedures":[],"mission_expectations":[{"sentence":"the page shows the Travel category","checker":"text","passed":false,"score":null}],"playbook_choices":[]}}```
Conclusion: detail.code=timeout is a provider timeout; hint says 'set OPENROUTER_API_KEY or fix the model config' which is misleading for timeout (status says key_present true, models.configured true). The skill's model-unavailable section is more accurate ('Provider retries are already bounded'). Checking status and retrying once (read-only mission, no side effects).

Attempt 3 (identical retry): exit 69 after 26s, same model-unavailable/timeout record. Status shows key_present/models.configured true. Will try a --dry-run on the same tab to see if the model path works at all, then a shorter mission.

```
$ leash drive 'Collect every book title and price on this Travel category page' --tab TAB --expect ... --dry-run --deadline-s 90 --owner l44-acceptance
(25.942s)
EXIT=69

{"code":"model-unavailable","message":"timed out","hint":"read detail.code; set OPENROUTER_API_KEY or fix the model config, then retry","detail":{"code":"timeout","site":null,"procedures":[],"mission_expectations":[{"sentence":"the page shows the Travel category","checker":"text","passed":false,"score":null}],"playbook_choices":[]}}

```

Attempt 4/5: --dry-run on --tab also timed out (exit 69, 26s, same record). Attempt 5 (no --tab, mission starting with 'Open <url> and collect ...'):
```
(0.761s)
{"playbook_choices":[],"status":"blocked","site":null,"procedures":[],"mission_expectations":[],"planner_turns":[],"proposals":[],"collected":0,"data":{"model_calls_by_kind":{"operator":1},"cost_unreported":0,"count":0,"first":[],"pages":0,"scripts":[]},"model_calls":1,"model_cost":2.6376e-05,"operator_steps":[{"n":1,"snapshot":"s_t_eca4981be0d325c8af81437fab829416","operation":"blocked","index":null,"probabilities":{"op":{"BLOCKED":0.97,"WAIT":0.02,"DONE":0.01},"target":{}},"after":{"url":"about:blank","title":""},"elapsed_ms":643}],"final":{"snapshot":"s_t_eca4981be0d325c8af81437fab829416","tab":"t_63df913e8b7a1a0fbc976b9ab6c1410c","url":"about:blank","title":"","rows":[],"total":0,"offset":0,"truncated":false,"settled":true,"dialog":null}}
EXIT=0


```

Attempt 6: the skill's own drive example verbatim:
```
$ leash drive 'Open https://example.com and show the Example Domain page' --expect 'the page shows Example Domain' --deadline-s 60 --max-procedures 3 --owner l44-acceptance
(0.78s)
{"playbook_choices":[],"status":"blocked","site":null,"procedures":[],"mission_expectations":[],"planner_turns":[],"proposals":[],"collected":0,"data":{"model_calls_by_kind":{"operator":1},"cost_unreported":0,"count":0,"first":[],"pages":0,"scripts":[]},"model_calls":1,"model_cost":2.5704e-05,"operator_steps":[{"n":1,"snapshot":"s_t_ee2ee491f091b0a384520ce7125de269","operation":"blocked","index":null,"probabilities":{"op":{"WAIT":0.03,"DONE":0.02,"BLOCKED":0.95},"target":{}},"after":{"url":"about:blank","title":""},"elapsed_ms":614}],"final":{"snapshot":"s_t_ee2ee491f091b0a384520ce7125de269","tab":"t_1a3f641d248cb0ef95b027136642a7ce","url":"about:blank","title":"","rows":[],"total":0,"offset":0,"truncated":false,"settled":true,"dialog":null}}
EXIT=0


```

Attempt 7: same skill example but pre-navigated own tab to example.com and used --tab:
```
(31.143s)
{"playbook_choices":[],"status":"handoff","site":null,"procedures":[],"mission_expectations":[{"sentence":"the page shows Example Domain","checker":"text","passed":false,"score":null}],"planner_turns":[{"n":1,"trigger":"blocked","answer":"handoff","reason":"The browser already shows the Example Domain page, but this run has no chosen site or site playbook. Choose Example Domain as the site so the page can be verified and the task marked complete.","usage":{"input_tokens":1341,"output_tokens":1369,"cost":0.0008186000000000001}}],"proposals":[],"collected":0,"data":{"model_calls_by_kind":{"operator":1,"planner":2},"cost_unreported":0,"count":0,"first":[],"pages":0,"scripts":[]},"model_calls":3,"model_cost":0.0008591720000000001,"operator_steps":[{"n":1,"snapshot":"s_t_46f02d012a3c4b0f522dc4ec194e96ff","operation":"done","index":null,"probabilities":{"op":{"WAIT":0.0,"BLOCKED":0.05,"DONE":0.95},"target":{}},"after":{"url":"https://example.com/","title":"Example Domain"},"elapsed_ms":618}],"final":{"snapshot":"s_t_b35c7bb66679404bae8bfda3c5d31530","tab":"t_5bd503a6bb8d892d87ca26d868f441a2","url":"https://example.com/","title":"Example Domain","rows":[{"index":1,"role":"paragraph","name":"T"},{"index":2,"role":"paragraph","name":"h"},{"index":3,"role":"paragraph","name":"i"},{"index":4,"role":"paragraph","name":"s"},{"index":5,"role":"paragraph","name":" "},{"index":6,"role":"paragraph","name":"d"},{"index":7,"role":"paragraph","name":"o"},{"index":8,"role":"paragraph","name":"m"},{"index":9,"role":"paragraph","name":"a"},{"index":10,"role":"paragraph","name":"i"},{"index":11,"role":"paragraph","name":"n"},{"index":12,"role":"paragraph","name":" "},{"index":13,"role":"paragraph","name":"i"},{"index":14,"role":"paragraph","name":"s"},{"index":15,"role":"paragraph","name":" "},{"index":16,"role":"paragraph","name":"f"},{"index":17,"role":"paragraph","name":"o"},{"index":18,"role":"paragraph","name":"r"},{"index":19,"role":"paragraph","name":" "},{"index":20,"role":"paragraph","name":"u"},{"index":21,"role":"paragraph","name":"s"},{"index":22,"role":"paragraph","name":"e"},{"index":23,"role":"paragraph","name":" "},{"index":24,"role":"paragraph","name":"i"},{"index":25,"role":"paragraph","name":"n"},{"index":26,"role":"paragraph","name":" "},{"index":27,"role":"paragraph","name":"d"},{"index":28,"role":"paragraph","name":"o"},{"index":29,"role":"paragraph","name":"c"},{"index":30,"role":"paragraph","name":"u"},{"index":31,"role":"paragraph","name":"m"},{"index":32

```

Attempt 7 conclusions: with --tab on a real page the run took 31s and returned status `handoff` (planner said: 'no chosen site or site playbook. Choose Example Domain as the site'), i.e. without an installed playbook, drive cannot do site work; also the final snapshot rows for example.com were single-character 'paragraph' rows ('T','h','i','s',...) - odd accessibility output. `playbook list` is empty on this machine. Authoring/installing a playbook would modify files outside the transcript, so I did not.

Attempt 8 (books Travel page, --tab, --out):
```
(0.092s)
EXIT=77

{"code":"with-human","message":"the tab is with the human; resume it first","hint":"the human holds this tab; wait, or return it with `leash resume TAB`"}

```

**Step 6 result: FAIL.** 8 attempts (see above). Outcomes: (1,5,6) blank tab → status "blocked" (exit 0), 0 records; (2,3,4,8-first) with --tab on the books page → model-unavailable/timeout ×3 (26s each); (7) with --tab on example.com → status "handoff" and the tab left in state with_human; (8) refused because the tab was with_human (`with-human`, exit 77). No playbook is installed (`leash playbook list` empty), and the skill says named/site work needs a playbook; the fallback operator does not navigate. drive-out.jsonl remained empty. Asked the parent (send_message) whether to resume the stuck tab t_5bd503a6…; no answer yet.

Side finding: leftover tabs opened by drive itself: t_9982af4b…, t_63df913e…, t_1a3f641d… (about:blank; skill says drive without --tab 'leaves it open; use final.tab').

## Step 7b: stale snapshot (doing (b) and (c) before (a), because (a) stops the service which may destroy the tabs I still have to close)
Using tab t_63df913e8b7a1a0fbc976b9ab6c1410c (was created by a drive run, about:blank).

```
$ leash nav t_63df913e8b7a1a0fbc976b9ab6c1410c https://httpbin.org/forms/post --owner l44-acceptance
{"tab":"t_63df913e8b7a1a0fbc976b9ab6c1410c","url":"https://httpbin.org/forms/post","title":"httpbin.org/forms/post","origin":"agent","state":"owned","owner":"l44-acceptance","generation":2,"dialog":null,"expires":{"stage":"release","in_s":1800}}
[exit 0]

```

```
$ leash snap t_63df913e8b7a1a0fbc976b9ab6c1410c --owner l44-acceptance --limit 5
{"snapshot":"s_t_715e9f2d8a57d5dcebc8b3be930386a1","tab":"t_63df913e8b7a1a0fbc976b9ab6c1410c","url":"https://httpbin.org/forms/post","title":"httpbin.org/forms/post","rows":[{"index":1,"role":"textbox","name":"Customer name: "},{"index":2,"role":"textbox","name":"Telephone: "},{"index":3,"role":"textbox","name":"E-mail address: "},{"index":4,"role":"radio","name":" Small","state":["unchecked"]},{"index":5,"role":"radio","name":" Medium","state":["unchecked"]}],"total":10,"offset":0,"truncated":true,"settled":true,"dialog":null}
[exit 0]

```

```
$ leash nav t_63df913e8b7a1a0fbc976b9ab6c1410c https://example.com --owner l44-acceptance
{"tab":"t_63df913e8b7a1a0fbc976b9ab6c1410c","url":"https://example.com/","title":"Example Domain","origin":"agent","state":"owned","owner":"l44-acceptance","generation":2,"dialog":null,"expires":{"stage":"release","in_s":1800}}
[exit 0]

```
Page changed after the snapshot above (s1).

```
$ leash click t_63df913e8b7a1a0fbc976b9ab6c1410c s_t_715e9f2d8a57d5dcebc8b3be930386a1 4 --owner l44-acceptance
[exit 65]
[stderr]
{"code":"stale-snapshot","message":"there is no snapshot for this tab; snap first","hint":"run `leash snap TAB` again and use its snapshot id"}

```
Acting on old snapshot row 4 (was the 'Small' radio on the form page).

**FINDING (per parent instruction to record):** a `drive` mission handed my tab to the human (status "handoff", tab left `with_human`, reason: 'The browser already shows the Example Domain page, but this run has no chosen site or site playbook. Choose Example Domain as the site so the page can be verified and the task marked complete.') instead of finishing or failing. That reason is a model note to itself, not a request a human can act on; nobody was waiting, and the tab stayed locked (`with-human`, exit 77) after `drive` exited. The parent authorized `resume` ('yes resume — no human is involved in that handoff').

```
$ leash resume t_5bd503a6bb8d892d87ca26d868f441a2 --owner l44-acceptance
{"resumed":true}
[exit 0]

```

```
$ leash list --owner l44-acceptance --table
TAB	URL	TITLE	ORIGIN	STATE	OWNER	REASON
t_1a3f641d248cb0ef95b027136642a7ce	about:blank		agent	owned	l44-acceptance	-
t_5bd503a6bb8d892d87ca26d868f441a2	https://example.com/	Example Domain	agent	owned	l44-acceptance	-
t_63df913e8b7a1a0fbc976b9ab6c1410c	https://example.com/	Example Domain	agent	owned	l44-acceptance	-
t_9982af4b82686eed4d4aded0988bc3f1	about:blank		agent	owned	l44-acceptance	-
t_b3d3ee519319f57216a61350eebde8f1	https://the-internet.herokuapp.com/windows/new	the-internet.herokuapp.com/windows/new	agent	owned	l44-acceptance	-
[exit 0]

```

**Step 7b outcome so far:** click on the old snapshot after nav → `stale-snapshot` (exit 65?), message 'there is no snapshot for this tab; snap first' (differs from help table meaning 'targeted snapshot is not current'; the hint text is the same and adequate). Recover using only the hint: snap, pick row, click with the new snapshot id.

```
$ leash snap t_63df913e8b7a1a0fbc976b9ab6c1410c --owner l44-acceptance --table
INDEX	ROLE	NAME	VALUE	STATE
1	paragraph	T	-	
2	paragraph	h	-	
3	paragraph	i	-	
4	paragraph	s	-	
5	paragraph	 	-	
6	paragraph	d	-	
7	paragraph	o	-	
8	paragraph	m	-	
9	paragraph	a	-	
10	paragraph	i	-	
11	paragraph	n	-	
12	paragraph	 	-	
13	paragraph	i	-	
14	paragraph	s	-	
15	paragraph	 	-	
16	paragraph	f	-	
17	paragraph	o	-	
18	paragraph	r	-	
19	paragraph	 	-	
20	paragraph	u	-	
21	paragraph	s	-	
22	paragraph	e	-	
23	paragraph	 	-	
24	paragraph	i	-	
25	paragraph	n	-	
26	paragraph	 	-	
27	paragraph	d	-	
28	paragraph	o	-	
29	paragraph	c	-	
30	paragraph	u	-	
31	paragraph	m	-	
32	paragraph	e	-	
33	paragraph	n	-	
34	paragraph	t	-	
35	paragraph	a	-	
36	paragraph	t	-	
37	paragraph	i	-	
38	paragraph	o	-	
39	paragraph	n	-	
40	paragraph	 	-	
41	paragraph	e	-	
42	paragraph	x	-	
43	paragraph	a	-	
44	paragraph	m	-	
45	paragraph	p	-	
46	paragraph	l	-	
47	paragraph	e	-	
48	paragraph	s	-	
49	paragraph	 	-	
50	paragraph	w	-	
51	paragraph	i	-	
52	paragraph	t	-	
53	paragraph	h	-	
54	paragraph	o	-	
55	paragraph	u	-	
56	paragraph	t	-	
57	paragraph	 	-	
58	paragraph	n	-	
59	paragraph	e	-	
60	paragraph	e	-	
61	paragraph	d	-	
62	paragraph	i	-	
63	paragraph	n	-	
64	paragraph	g	-	
65	paragraph	 	-	
66	paragraph	p	-	
67	paragraph	e	-	
68	paragraph	r	-	
69	paragraph	m	-	
70	paragraph	i	-	
71	paragraph	s	-	
72	paragraph	s	-	
73	paragraph	i	-	
74	paragraph	o	-	
75	paragraph	n	-	
76	paragraph	.	-	
77	paragraph	 	-	
78	paragraph	T	-	
79	paragraph	h	-	
80	paragraph	i	-	
81	paragraph	s	-	
82	paragraph	 	-	
83	paragraph	i	-	
84	paragraph	s	-	
85	paragraph	 	-	
86	paragraph	n	-	
87	paragraph	o	-	
88	paragraph	t	-	
89	paragraph	 	-	
90	paragraph	a	-	
91	paragraph	 	-	
92	paragraph	s	-	
93	paragraph	e	-	
94	paragraph	r	-	
95	paragraph	v	-	
96	paragraph	i	-	
97	paragraph	c	-	
98	paragraph	e	-	
99	paragraph	,	-	
100	paragraph	 	-	
101	paragraph	a	-	
102	paragraph	v	-	
103	paragraph	o	-	
104	paragraph	i	-	
105	paragraph	d	-	
106	paragraph	 	-	
107	paragraph	r	-	
108	paragraph	e	-	
109	paragraph	l	-	
110	paragraph	y	-	
111	paragraph	i	-	
112	paragraph	n	-	
113	paragraph	g	-	
114	paragraph	 	-	
115	paragraph	o	-	
116	paragraph	n	-	
117	paragraph	 	-	
118	paragraph	i	-	
119	paragraph	t	-	
120	paragraph	 	-	
[exit 0]

```

```
$ leash snap t_63df913e8b7a1a0fbc976b9ab6c1410c --owner l44-acceptance
{"snapshot":"s_t_8aade42288a39e89c7fdb931c13947dc","tab":"t_63df913e8b7a1a0fbc976b9ab6c1410c","url":"https://example.com/","title":"Example Domain","rows":[{"index":1,"role":"paragraph","name":"T"},{"index":2,"role":"paragraph","name":"h"},{"index":3,"role":"paragraph","name":"i"},{"index":4,"role":"paragraph","name":"s"},{"index":5,"role":"paragraph","name":" "},{"index":6,"role":"paragraph","name":"d"},{"index":7,"role":"paragraph","name":"o"},{"index":8,"role":"paragraph","name":"m"},{"index":9,"role":"paragraph","name":"a"},{"index":10,"role":"paragraph","name":"i"},{"index":11,"role":"paragraph","name":"n"},{"index":12,"role":"paragraph","name":" "},{"index":13,"role":"paragraph","name":"i"},{"index":14,"role":"paragraph","name":"s"},{"index":15,"role":"paragraph","name":" "},{"index":16,"role":"paragraph","name":"f"},{"index":17,"role":"paragraph","name":"o"},{"index":18,"role":"paragraph","name":"r"},{"index":19,"role":"paragraph","name":" "},{"index":20,"role":"paragraph","name":"u"},{"index":21,"role":"paragraph","name":"s"},{"index":22,"role":"paragraph","name":"e"},{"index":23,"role":"paragraph","name":" "},{"index":24,"role":"paragraph","name":"i"},{"index":25,"role":"paragraph","name":"n"},{"index":26,"role":"paragraph","name":" "},{"index":27,"role":"paragraph","name":"d"},{"index":28,"role":"paragraph","name":"o"},{"index":29,"role":"paragraph","name":"c"},{"index":30,"role":"paragraph","name":"u"},{"index":31,"role":"paragraph","name":"m"},{"index":32,"role":"paragraph","name":"e"},{"index":33,"role":"paragraph","name":"n"},{"index":34,"role":"paragraph","name":"t"},{"index":35,"role":"paragraph","name":"a"},{"index":36,"role":"paragraph","name":"t"},{"index":37,"role":"paragraph","name":"i"},{"index":38,"role":"paragraph","name":"o"},{"index":39,"role":"paragraph","name":"n"},{"index":40,"role":"paragraph","name":" "},{"index":41,"role":"paragraph","name":"e"},{"index":42,"role":"paragraph","name":"x"},{"index":43,"role":"paragraph","name":"a"},{"index":44,"role":"paragraph","name":"m"},{"index":45,"role":"paragraph","name":"p"},{"index":46,"role":"paragraph","name":"l"},{"index":47,"role":"paragraph","name":"e"},{"index":48,"role":"paragraph","name":"s"},{"index":49,"role":"paragraph","name":" "},{"index":50,"role":"paragraph","name":"w"},{"index":51,"role":"paragraph","name":"i"},{"index":52,"role":"paragraph","name":"t"},{"index":53,"role":"paragraph","name":"h"},{"index":54,"role":"paragraph","name":"o"},{"index":55,"role":"paragraph",
```

Observation: the fresh snap of example.com returned the paragraph text split into one row per character ('T','h','i','s',' ',...) — noisy/odd accessibility output (the same happened at the end of drive attempt 7, but `snap` on example.com wasn't done earlier in step 2). Filtering with --match to find the link.

```
$ leash snap t_63df913e8b7a1a0fbc976b9ab6c1410c --owner l44-acceptance --match link
{"snapshot":"s_t_b15628e301a29ae27e16b3c17ffb8a05","tab":"t_63df913e8b7a1a0fbc976b9ab6c1410c","url":"https://example.com/","title":"Example Domain","rows":[],"total":0,"offset":0,"truncated":false,"settled":true,"dialog":null}
[exit 0]

```

Finding: `resume` succeeded (see above). But example.com's snapshot is unusable today: total=784 rows, all single-character 'paragraph' rows, and NO link row for 'Learn more' (`--match link` → 0; nonparagraph rows = none in the first 300 and the last 60), although `text` shows the multilingual page with 'Learn more'. So I can't do the recovery click on example.com. The stale-snapshot error itself was obtained; redoing the cycle on the-internet.herokuapp.com/download (reliable rows) so the recovery uses a real click.

```
$ leash nav t_63df913e8b7a1a0fbc976b9ab6c1410c https://the-internet.herokuapp.com/javascript_alerts --owner l44-acceptance
{"tab":"t_63df913e8b7a1a0fbc976b9ab6c1410c","url":"https://the-internet.herokuapp.com/javascript_alerts","title":"The Internet","origin":"agent","state":"owned","owner":"l44-acceptance","generation":2,"dialog":null,"expires":{"stage":"release","in_s":1800}}
[exit 0]

```

```
$ leash snap t_63df913e8b7a1a0fbc976b9ab6c1410c --owner l44-acceptance
{"snapshot":"s_t_de8966c7e77df6b10f7f7bc5d2ec849a","tab":"t_63df913e8b7a1a0fbc976b9ab6c1410c","url":"https://the-internet.herokuapp.com/javascript_alerts","title":"The Internet","rows":[{"index":1,"role":"heading","name":"JavaScript Alerts"},{"index":2,"role":"paragraph","name":"Here are some examples of different JavaScript alerts which can be troublesome for automation"},{"index":3,"role":"button","name":"Click for JS Alert"},{"index":4,"role":"button","name":"Click for JS Confirm"},{"index":5,"role":"button","name":"Click for JS Prompt"},{"index":6,"role":"heading","name":"Result:"},{"index":7,"role":"link","name":"Elemental Selenium"}],"total":7,"offset":0,"truncated":false,"settled":true,"dialog":null}
[exit 0]

```

```
$ leash nav t_63df913e8b7a1a0fbc976b9ab6c1410c https://the-internet.herokuapp.com/download --owner l44-acceptance
{"tab":"t_63df913e8b7a1a0fbc976b9ab6c1410c","url":"https://the-internet.herokuapp.com/download","title":"The Internet","origin":"agent","state":"owned","owner":"l44-acceptance","generation":2,"dialog":null,"expires":{"stage":"release","in_s":1800}}
[exit 0]

```
Page changed after snapshot s1.

```
$ leash click t_63df913e8b7a1a0fbc976b9ab6c1410c s_t_de8966c7e77df6b10f7f7bc5d2ec849a 3 --owner l44-acceptance
[exit 65]
[stderr]
{"code":"stale-snapshot","message":"there is no snapshot for this tab; snap first","hint":"run `leash snap TAB` again and use its snapshot id"}

```
Acting on old snapshot row 3 (was 'Click for JS Alert' on the previous page).

7b: error record `stale-snapshot` (exit 65), message 'there is no snapshot for this tab; snap first' (differs from help table 'the targeted snapshot is not current' — after navigation the snapshot is dropped entirely), hint 'run `leash snap TAB` again and use its snapshot id'. Recovering strictly per hint:

```
$ leash snap t_63df913e8b7a1a0fbc976b9ab6c1410c --owner l44-acceptance --limit 12
{"snapshot":"s_t_9b004c2311907f8dbce6feeb31da8a96","tab":"t_63df913e8b7a1a0fbc976b9ab6c1410c","url":"https://the-internet.herokuapp.com/download","title":"The Internet","rows":[{"index":1,"role":"heading","name":"File Downloader"},{"index":2,"role":"link","name":"r2_test_upload_bmwz_71o.txt"},{"index":3,"role":"link","name":"random_data_18.txt"},{"index":4,"role":"link","name":"referto_sperimentale_CX881.txt"},{"index":5,"role":"link","name":"examplefile.json"},{"index":6,"role":"link","name":"sample-1mb-test-file.dat"},{"index":7,"role":"link","name":"test-upload.txt"},{"index":8,"role":"link","name":"tmp3soc7qq4.txt"},{"index":9,"role":"link","name":"tmpmaqga2jk.txt"},{"index":10,"role":"link","name":"sample.pdf"},{"index":11,"role":"link","name":"upload-17628522055331900173.txt"},{"index":12,"role":"link","name":"sample.txt"}],"total":26,"offset":0,"truncated":true,"settled":true,"dialog":null}
[exit 0]

```

```
$ leash click t_63df913e8b7a1a0fbc976b9ab6c1410c s_t_9b004c2311907f8dbce6feeb31da8a96 12 --owner l44-acceptance
{"tab":"t_63df913e8b7a1a0fbc976b9ab6c1410c","url":"https://the-internet.herokuapp.com/download","title":"The Internet","snapshot":null,"dialog":null,"popups":[]}
[exit 0]

```
Clicked the row for sample.txt (harmless small download) using the NEW snapshot id and its actual index.

```
$ leash downloads t_63df913e8b7a1a0fbc976b9ab6c1410c --owner l44-acceptance
{"downloads":[{"id":"24099e0f-2d0e-4c95-8de0-772add9c5c33","suggested_name":"sample.txt","mime":"application/octet-stream","state":"completed","path":"/home/ribelo/.local/share/leash/profile/downloads/sample.txt"}]}
[exit 0]

```

**Step 7b result: PASS; hint alone was enough** (snap again → new id → click succeeded; download confirmed).

## Step 7c: not-owner

```
$ leash snap t_63df913e8b7a1a0fbc976b9ab6c1410c --owner l44-acceptance --limit 5
{"snapshot":"s_t_cbd8bd516d85b4afebaa04b28ff50c15","tab":"t_63df913e8b7a1a0fbc976b9ab6c1410c","url":"https://the-internet.herokuapp.com/download","title":"The Internet","rows":[{"index":1,"role":"heading","name":"File Downloader"},{"index":2,"role":"link","name":"r2_test_upload_bmwz_71o.txt"},{"index":3,"role":"link","name":"random_data_18.txt"},{"index":4,"role":"link","name":"referto_sperimentale_CX881.txt"},{"index":5,"role":"link","name":"examplefile.json"}],"total":26,"offset":0,"truncated":true,"settled":true,"dialog":null}
[exit 0]

```

```
$ leash click t_63df913e8b7a1a0fbc976b9ab6c1410c s_t_cbd8bd516d85b4afebaa04b28ff50c15 1 --owner l44-intruder
[exit 77]
[stderr]
{"code":"not-owner","message":"the tab belongs to another owner","hint":"run `leash list --all` to see the owner; `leash claim TAB` takes an unowned tab"}

```
Acting on my tab with a different owner.

```
$ leash list --all --owner l44-intruder --table
TAB	URL	TITLE	ORIGIN	STATE	OWNER	REASON
t_04a0d8ee1428a0ae1504469b0adfc189	chrome://newtab/	New Tab	human	unowned	-	-
t_1a3f641d248cb0ef95b027136642a7ce	about:blank		agent	owned	l44-acceptance	-
t_5bd503a6bb8d892d87ca26d868f441a2	https://example.com/	Example Domain	agent	owned	l44-acceptance	-
t_63df913e8b7a1a0fbc976b9ab6c1410c	https://the-internet.herokuapp.com/download	The Internet	agent	owned	l44-acceptance	-
t_9982af4b82686eed4d4aded0988bc3f1	about:blank		agent	owned	l44-acceptance	-
t_b3d3ee519319f57216a61350eebde8f1	https://the-internet.herokuapp.com/windows/new	the-internet.herokuapp.com/windows/new	agent	owned	l44-acceptance	-
[exit 0]

```
Hint step 1: list --all.

```
$ leash claim t_63df913e8b7a1a0fbc976b9ab6c1410c --owner l44-intruder
[exit 77]
[stderr]
{"code":"already-owned","message":"the tab is already owned","hint":"the tab is already claimed; `leash list --all` shows its owner"}

```
Hint step 2: `claim TAB` (hint says it takes an *unowned* tab; this one is owned, so I expect refusal — trying only to see whether the hint's second half applies).

7c analysis: not-owner (exit 77) hint: 'run `leash list --all` to see the owner; `leash claim TAB` takes an unowned tab'. `list --all` revealed owner l44-acceptance and state owned; `claim` → `already-owned` (77), hint 'the tab is already claimed; `leash list --all` shows its owner'. Neither hint says what to DO when another owner holds the tab (ask the owner to release / use the owner's identity if it's really yours / open your own tab with `leash new`). Recovering with what I inferred: it's my own tab, so use my own owner name; a stranger should open its own tab.

```
$ leash snap t_63df913e8b7a1a0fbc976b9ab6c1410c --owner l44-acceptance --limit 5
{"snapshot":"s_t_1442434736c7f0d46d1f71a1683e74e7","tab":"t_63df913e8b7a1a0fbc976b9ab6c1410c","url":"https://the-internet.herokuapp.com/download","title":"The Internet","rows":[{"index":1,"role":"heading","name":"File Downloader"},{"index":2,"role":"link","name":"r2_test_upload_bmwz_71o.txt"},{"index":3,"role":"link","name":"random_data_18.txt"},{"index":4,"role":"link","name":"referto_sperimentale_CX881.txt"},{"index":5,"role":"link","name":"examplefile.json"}],"total":26,"offset":0,"truncated":true,"settled":true,"dialog":null}
[exit 0]

```

```
$ leash new https://example.org --owner l44-intruder
{"tab":"t_e4a6b3004fe332ff5548b36731004856","url":"https://example.org/","title":"Example Domain","origin":"agent","state":"owned","owner":"l44-intruder","generation":2,"dialog":null,"expires":{"stage":"release","in_s":1800}}
[exit 0]

```
Intruder opens its own tab (the only legitimate way forward when the tab isn't yours).

**Step 7c result: PARTIAL — hint alone NOT enough** (it explains how to inspect, and claim only for unowned tabs; no instruction for the owned-by-someone-else case). Recovery of my own access is trivial (use my owner name).

## Cleanup before 7a (closing all tabs I opened first, because stopping the service could drop them)

```
$ leash list --owner l44-acceptance
{"tabs":[{"tab":"t_1a3f641d248cb0ef95b027136642a7ce","url":"about:blank","title":"","origin":"agent","state":"owned","owner":"l44-acceptance","generation":2,"dialog":null,"expires":{"stage":"release","in_s":1652}},{"tab":"t_5bd503a6bb8d892d87ca26d868f441a2","url":"https://example.com/","title":"Example Domain","origin":"agent","state":"owned","owner":"l44-acceptance","generation":2,"dialog":null,"expires":{"stage":"release","in_s":1744}},{"tab":"t_63df913e8b7a1a0fbc976b9ab6c1410c","url":"https://the-internet.herokuapp.com/download","title":"The Internet","origin":"agent","state":"owned","owner":"l44-acceptance","generation":2,"dialog":null,"expires":{"stage":"release","in_s":1792}},{"tab":"t_9982af4b82686eed4d4aded0988bc3f1","url":"about:blank","title":"","origin":"agent","state":"owned","owner":"l44-acceptance","generation":2,"dialog":null,"expires":{"stage":"release","in_s":1509}},{"tab":"t_b3d3ee519319f57216a61350eebde8f1","url":"https://the-internet.herokuapp.com/windows/new","title":"the-internet.herokuapp.com/windows/new","origin":"agent","state":"owned","owner":"l44-acceptance","generation":2,"dialog":null,"expires":{"stage":"release","in_s":1483}}]}
[exit 0]

```

```
$ leash list --owner l44-intruder
{"tabs":[{"tab":"t_e4a6b3004fe332ff5548b36731004856","url":"https://example.org/","title":"Example Domain","origin":"agent","state":"owned","owner":"l44-intruder","generation":2,"dialog":null,"expires":{"stage":"release","in_s":1792}}]}
[exit 0]

```

```
$ leash close t_1a3f641d248cb0ef95b027136642a7ce --owner l44-acceptance
{"closed":true}
[exit 0]

```

```
$ leash close t_5bd503a6bb8d892d87ca26d868f441a2 --owner l44-acceptance
{"closed":true}
[exit 0]

```

```
$ leash close t_63df913e8b7a1a0fbc976b9ab6c1410c --owner l44-acceptance
{"closed":true}
[exit 0]

```

```
$ leash close t_9982af4b82686eed4d4aded0988bc3f1 --owner l44-acceptance
{"closed":true}
[exit 0]

```

```
$ leash close t_b3d3ee519319f57216a61350eebde8f1 --owner l44-acceptance
{"closed":true}
[exit 0]

```

```
$ leash close t_e4a6b3004fe332ff5548b36731004856 --owner l44-intruder
{"closed":true}
[exit 0]

```

```
$ leash list --all --owner l44-acceptance --table
TAB	URL	TITLE	ORIGIN	STATE	OWNER	REASON
t_04a0d8ee1428a0ae1504469b0adfc189	chrome://newtab/	New Tab	human	unowned	-	-
[exit 0]

```

All my tabs closed; only the human's pre-existing t_04a0… remains. (Note: 7a stops the service — which may close that human tab too, since Chrome belongs to the service; the user requested this deliberately.)

## Step 7a: service stopped

```
$ systemctl --user stop leash.service
[exit 0]

```

```
$ leash list --owner l44-acceptance
[exit 69]
[stderr]
{"code":"service-unreachable","message":"cannot reach the Leash service at /run/user/1000/leash/control.sock","hint":"`systemctl --user start leash`, or pass --socket","detail":{"socket":"/run/user/1000/leash/control.sock"}}

```
A leash command with the service stopped.

7a analysis: code `service-unreachable` (exit 69), hint '`systemctl --user start leash`, or pass --socket'. Note `leash help errors` also lists a more specific `service-stopped` ('the leash unit is installed but inactive') and `not-installed`; the CLI returned the generic `service-unreachable` for a stopped unit, so those codes weren't observed (help table vs behaviour mismatch, or they need a different probe). Following the hint: start the unit, then status.

```
$ systemctl --user start leash
[exit 0]

```

```
$ leash status --owner l44-acceptance
{"key_present":true,"commit":"8c17d96d01c366f66510a29106b8d39811b3dee6","skill":{"state":"missing","version":"0.0.0","commit":"8c17d96d01c366f66510a29106b8d39811b3dee6","installs":[{"path":"/home/ribelo/.claude/skills/leash","state":"missing","version":null,"commit":null},{"path":"/home/ribelo/.codex/skills/leash","state":"missing","version":null,"commit":null},{"path":"/home/ribelo/.agents/skills/leash","state":"missing","version":null,"commit":null}]},"generation":1,"tabs":{"open":0,"cap":32},"chrome":"running","uptime_s":0.050486087799072266,"models":{"configured":true,"jev_model":"typesafe/jev-1.13-20260917","text_model":"inception/mercury-2.5","systemone_endpoint":"https://openrouter.ai/api/v1/systemone","chat_base_url":"https://openrouter.ai/api/v1"},"version":"0.0.0","pid":null,"headed":true}
[exit 0]

```

```
$ leash list --all --owner l44-acceptance ; leash status
{"tabs":[{"tab":"t_dc58bcb02f31bd24e2422471c36b0ae3","url":"chrome://newtab/","title":"New Tab","origin":"human","state":"unowned","owner":null,"generation":1,"dialog":null,"expires":null}]}
[exit 0]
{"chrome":"running","tabs":{"open":1,"cap":32},"generation":1}

```
**Step 7a result: PASS; hint alone was enough.** After restart the service came up as generation 1 with 0 tabs open — the restart also dropped the human's pre-existing New Tab (t_04a0…) (collateral of the requested stop; the skill's lifecycle.md warns 'restarting loses live handles').

# FINAL REPORT

## Step table
| # | Step | Result | Notes |
|---|------|--------|-------|
| 1 | httpbin form: open, snap, fill, submit, verify | PASS (with workaround) | httpbin echoed custname "Leash Tester", custtel "555-0100", size large, topping bacon, comments "helloleash ok". Snapshot lacked rows for time input, Comments textarea and Submit button. |
| 2 | text + bounded eval | PASS | example.com title "Example Domain", 1 link. |
| 3 | net: find API request, read body | PASS | GET https://httpbin.org/spec.json (fetch), body read (41019 chars). |
| 4 | dialogs + popup | PASS | alert accepted, confirm dismissed (page: 'You clicked: Cancel'); popup /windows/new listed in click reply and read ('New Window'). |
| 5 | download | PASS | examplefile.json (source is 0 bytes) and sample.txt (16 bytes) reported completed with path. |
| 6 | drive mission | FAIL | 8 attempts: blocked on about:blank (no navigation, no playbook), model-unavailable/timeout x3 on real page, handoff (tab locked) once; 0 records in drive-out.jsonl. |
| 7a | service stopped | PASS | hint sufficient |
| 7b | stale snapshot | PASS | hint sufficient |
| 7c | not-owner | PASS (hint insufficient) | hint doesn't say what to do when another owner holds the tab |
| - | Cleanup | PASS | all tabs I opened (incl. drive-created and popup, and the l44-intruder tab) closed before 7a; final list shows none of mine (service restart left 0 tabs). |

## Recoveries
- 7a service-unreachable: hint 'systemctl --user start leash' → start → status OK. Enough.
- 7b stale-snapshot: hint 'run leash snap TAB again and use its snapshot id' → click OK. Enough.
- 7c not-owner: hint 'list --all to see the owner; claim takes an unowned tab' → list shows owner, claim → already-owned. NOT enough: no guidance for an owned-by-other tab (use the right --owner if it's yours, ask owner to release, or leash new). Also for my accidental not-owner (forgot --owner; fell back to dsh:$DSH_SESSION_ID) the hint pointed toward `claim`, which would have been wrong.

## Skill / help problems
1. **Snapshot omits controls**: on https://httpbin.org/forms/post `snap` (also --match Submit, --offset, after reload) gave 10 rows, no <input type=time>, <textarea> or <button type=submit>, though visible in-viewport and DOM. The skill says nothing about controls that can be missing and gives no fallback; I had to use `press Tab` chains and one-char `press` keys. Skill: 'Do not turn a whole form into a blind chain of guessed indices or repeated Enter presses' — but no alternative.
2. **press key names undocumented**: `press --help` only example is 'Enter'. 'ring the bell' → `unknown key name ring the bell`; ' ' → `unknown key name  `; hint 'fix the request; leash <command> --help names the arguments and one example' doesn't help. 'Space' and single characters work (guess). No text-typing command for textareas without a row.
3. **drive fallback can't navigate**: skill's own example `leash drive 'Open https://example.com and show the Example Domain page' --expect ... --deadline-s 60 --max-procedures 3` returns exit 0, status "blocked", tab on about:blank (no reason field). Skill says 'Include the intended site' and that drive selects a playbook or 'falls back to the single-goal operator', implying it can do work; but no playbook is installed by default (`playbook list` empty; skill says examples 'are not guaranteed to ship') and the operator does not navigate. The books collection mission in the task can't work without an authored playbook (skill's playbook section requires editing config, which I was told not to do). Skill should state that drive needs an installed playbook for data collection / a starting tab.
4. **drive leaves tabs**: each drive without --tab leaves an about:blank tab (skill notes 'use final.tab' — OK, but it cost 3 stray tabs).
5. **drive → spurious handoff**: with --tab on example.com, status "handoff", tab now with_human, reason is a planner self-note ('no chosen site or site playbook. Choose Example Domain as the site...'); drive exited, so nobody waiting; tab locked (with-human 77) until `resume` (parent authorised). Skill says 'The planner may ask for the human; ... communicate what is needed' — doesn't warn that a handoff can be spurious/leave a locked tab with no blocking process; `no-handoff` semantics vs this case unclear.
6. **model-unavailable hint misleading for timeout**: `{"code":"model-unavailable","message":"timed out","hint":"read detail.code; set OPENROUTER_API_KEY or fix the model config, then retry"}` with detail.code=timeout, status showing key_present true. Reproducible x3 (26 s each) on a real page tab, also for --dry-run; skill's 'Provider retries are already bounded' doesn't say what to do next.
7. **Help table vs behaviour**: `leash help errors` lists `not-installed`, `service-stopped` (69) and `service-restarting` (75), absent from the skill's errors.md exit table; with the unit stopped the CLI returned generic `service-unreachable` (hint fine). `stale-snapshot` help meaning 'the targeted snapshot is not current' but actual message 'there is no snapshot for this tab; snap first' after nav (OK).
8. **not-owner hint incomplete** (see 7c above); `claim` mention only fits the unowned case. Also skill errors.md does say 'Verify that your --owner or DSH_SESSION_ID has not changed' but the record's own hint doesn't.
9. **Owner default surprise**: forgetting --owner silently falls back to dsh:$DSH_SESSION_ID and produces not-owner rather than a message naming the identity used. The error should include the caller identity in detail.
10. **example.com snapshot degraded**: `snap` (784 rows, every row a single-character 'paragraph' e.g. 'T','h','i','s',' ') and no link row for 'Learn more' although `text` shows it; the skill's own runnable example ('opens the first observed link on example.com') can't work. (Today example.com renders a multilingual page.)
11. **Skill says after input take a fresh snapshot**; in practice a second fill with the same snapshot id worked (fill doesn't stale it). Conservative but slightly inaccurate; `--limit` of 12 fine.
12. **net timing**: right after nav `net --type fetch`/xhr returned [] though the fetch (spec.json) happened seconds later; skill doesn't say lists are point-in-time. `net` unfiltered is very long (data: URLs, fonts); `--type` accepted values not fully listed ('xhr, fetch, document, script, ...').
13. **playbook list rejects --owner** (cli-parse 'unknown option --owner') although browser.md says 'Pass --owner NAME on every service call'; correct per lifecycle.md but trips a reader.
14. **downloads** gives no byte size, so an empty file (examplefile.json is 0 bytes at source) can't be distinguished without `ls`; popup entry in click reply had empty url/title (still loading) — need list.
15. **drive --help examples**: 'Buy a Logitech MX Master 3S on allegro.pl' – a purchase example in a tool whose skill forbids purchases; worth replacing.
16. **Process notes**: I wrote /tmp/leash-l44/help.txt (help capture) and drive-*.json/jsonl files besides transcript.md (drive --out is the requested output file). Stopping the service dropped the human's New Tab (unavoidable, requested).

**Correction:** after the restart Chrome opened a new default tab (t_dc58…, chrome://newtab, origin human, unowned); the old human New Tab handle t_04a0… is gone. It is not mine; I left it alone. My own tabs: none open.
