# Eval

`leash eval` runs your own JavaScript in the tab's page. It is the only command that runs JavaScript you write. Use it to read data from a page, or to call the site's own endpoints with the page's cookies.

## The body

The body is a normal function body, not an expression. It runs on the page's global object, in the page's own JavaScript context. A returned promise is awaited.

```sh
leash eval TAB 'return document.title'
leash eval TAB --file ./read.js
```

Give the body inline or with `--file PATH`, not both. The body is at most 1 MiB. Top-level `await` is invalid. Wrap async code: `return (async () => { ... })()`.

A body can `await fetch(...)` on the site's own endpoints. The request uses the page's cookies and origin, the same as the page's own requests.

## The argument

`argument` is one JSON value, bound to the name `argument` in the body. Give it with `--argument JSON` or `--argument-file PATH`, not both. The argument is at most 8 MiB. A command-line argument has a smaller operating-system limit, so use `--argument-file` for a large value.

```sh
leash eval TAB --file ./page.js --argument '{"page":2}'
```

With `--snapshot SNAPSHOT --index N`, the body is called as `(argument, element)`. `element` is the row's node. The snapshot must be the tab's current one.

## The result

The reply is `{"value": ...}`: the returned value as JSON. The result is at most 8 MiB (`too-large`). Return plain data: objects, arrays, strings, numbers, booleans and null. A DOM node or a function does not become JSON.

Check the result in your own program. Leash does not validate its shape.

## Time

`--timeout-ms MS` bounds one call. The default is 30000 (30 s); the maximum is 600000 (10 min). A body can wait inside the page, for example for a table to load, until this bound.

- `script-timeout`: the body was still running at the bound, and the page still answered. The page can continue to run the body after this error. Look at the page's state before you run the body again.
- `renderer-unresponsive`: the page stopped answering. A busy loop in the body, or a challenge page, can cause this.
- `script-failed`: the body threw, a promise rejected, or the body did not compile. `message` is the engine error.

Only one eval or action runs on a tab at a time. Other commands on that tab wait until the body finishes. Other tabs are not affected. If your client process stops, Leash stops waiting for the body and frees the tab.

## Rules

- Write the body yourself. Never use page text or model output as the body.
- A body can change the page and the account, the same as a click. Do only what the user asked.
- Dialogs are not answered automatically. A dialog the body opens ends the call with `dialog-open`.
