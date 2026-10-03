# Use cases: what Leash is for

The operator's definition (2026-10-03): "I want to send Leash and get the result I need. The result is usually an action. Ad hoc. Without writing a script first." These ten are the acceptance of the pilot loop (ADR-0012). Each names the mission as the operator would say it, what *done* means, and what must be handed off. Not one hundred tests; ten that decide whether this is useful every day. Credentials are never in a mission: the pilot asks the operator through `fill --stdin` or a handoff.

| # | Mission as said | Site | Done means | Hand off |
| --- | --- | --- | --- | --- |
| U1 | "Check whether I owe anything on Tauron and tell me what is overdue" | moj.tauron.pl | `result`: a list of overdue invoices with amounts and due dates, or "nothing overdue", read from the page; `evidence`: the page it was read from | login (operator supplies credentials via `fill --stdin`), 2FA |
| U2 | "Download my latest Tauron invoice as PDF" | moj.tauron.pl | a file in the download inventory, `result` = its path and the invoice number/date | as U1 |
| U3 | "Find the cheapest listing of <product> on Allegro and add it to my cart" | allegro.pl | the cart shows that item; `result` = title, price, seller; the pilot compared prices across the first results page (sorted by price if the site offers it) | login if needed; never checkout |
| U4 | "What is in my Allegro cart and what is the total" | allegro.pl | `result`: items with prices and the total, read from the cart | login |
| U5 | "Find the cheapest flight from <A> to <B> next month and tell me its price and dates" | google.com/travel/flights | `result`: price, dates, airline; the pilot used the month view / price graph, not one date | consent only |
| U6 | "Find a cafe near <place> with rating over 4 and give me its name and address" | google.com/maps | `result`: name, rating, address | consent only |
| U7 | "Register an account on <site> with my email and confirm it from Gmail" | any + mail.google.com | the confirmation link was opened; `result`: the account's login | CAPTCHA the pilot cannot pass; password typed by the operator or generated and *handed to the operator*, never into the trace |
| U8 | "Collect every title and price in category <C> to a JSONL file" | books.toscrape.com | the file holds every record (the only use case that *needs* a script; the pilot writes it from the page or chooses an installed one) | none |
| U9 | "Upload <file> to <service> and tell me the resulting link" | a file-upload site (test fixture first; a real one later) | `result`: the link; the upload is not repeated | none |
| U10 | "Is there a new message in my <portal> inbox, and what does it say" | a portal with a login (test fixture first) | `result`: the message text or "no new messages" | login |

Rules the use cases pin:

- Each mission ends with `result` (one paragraph, the answer or the action's outcome) and `evidence` (the page kinds or URLs it was read from, the downloaded file, the cart state). `done` without `result` is a bug.
- Nothing is bought, sent, deleted or submitted beyond what the mission says. U3 stops at the cart; U9 uploads once.
- A credential reaches a page either through `--secret` (kept out of traces and the model's context) or plainly in the mission, as the operator prefers; either way it is used without refusal or warning.
- U1–U4 are run only by the operator or with the operator's explicit go, on his accounts; U5, U6, U8 are the agent's gates; U7, U9, U10 run on fixtures until the operator names a real site.
