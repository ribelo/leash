# L30 upper-level JEV state measurement (throwaway)

Decision: **use B**, with mission + title/URL + page kind + recent procedure outcomes, but no page text (known arguments were not varied or supplied in this probe). B selected 4/5 hand labels; A and C each 2/5. B cost $0.000128730 over five calls versus A $0.000116214 and C $0.000236418. This is a five-page probe, not a general statistical guarantee. Keep operator-level perception unchanged.

## Capture and transfer limits

Allegro home and listing returned HTTP 403 with DataDome cookies, including an independent HTTP HEAD. No spoofing, stealth, account action or bypass was attempted. The first alternate shop with the complete real workflow was automationexercise.com. A private Leash service launched an isolated Chrome profile with headless=true; the primary process had --headless=new and its Chrome children exited after SIGTERM to Leash. Its regular Google consent dialog was accepted through Leash’s keyboard action on the visible Consent button. No JavaScript click circumvented row safety. The preliminary probe of demo.opencart.com returned HTTP 403; books.toscrape.com served pages but has no cart. The alternate site tests semantic workflow shape and real JEV behavior, **not** Allegro DOM, blocking policy, prices or anti-bot reliability. L34 Allegro acceptance may require an operator’s headed run.

capture.py records actual Leash text --max-chars 8000, URL/title, page kind and observed procedure outcomes into five JSON fixtures. Hand labels: home → find-product; submitted search results at /products?search=Blue%20Top → open-offer; Blue Top product detail → add-to-cart; visible successful Added! modal with View Cart → go-to-cart; cart visibly containing Blue Top → DONE. Assertions reject an empty cart or missing modal. The fourth state shares the offer URL and title but differs in visible modal and recent successful add. Page kinds and recent procedure outcomes are hand-labeled from the observed workflow, not outputs from an unbuilt run loop. The capture took a product-detail href from the submitted results and navigated to it through Leash, then navigated to the cart URL through Leash rather than pressing the modal View Cart button. The cart contained Blue Top; no checkout or payment action occurred (despite the site setting the cart page title to “Checkout”). The matching example is examples/playbooks/automationexercise.com.json.

An earlier exploratory 15-call pass contained a login page reached by direct navigation and falsely labeled as a login-required blocker. It was discarded, and the **entire corrected 15-call matrix rerun**. Costs below cover only that final valid matrix, not the extra exploratory calls. No simulated model or handcrafted probabilities.

## Method and raw results

spike.ml uses Eta_ai_systemone.Client.evaluate with model typesafe/jev-1.13-20260917, one choice question and fixed eight criteria (six playbook procedures plus DONE/BLOCKED). Each fixture is evaluated once per shape: A = mission/title/URL; B = A + page kind/recent outcomes; C = B + bounded actual page text. Goal and criteria stay identical. results.pretty.json contains all eight criterion probabilities, confidence, provider-reported usage/cost per reply; results.json is the exact compact spike output. Displayed p(choice) and p(expected) are model-reported probabilities, not empirical frequencies.

| State | Shape | Hand label | Chosen | p(choice) | p(expected) | Correct | Input/output tokens | Cost USD |
| --- | --- | --- | --- | ---: | ---: | :---: | ---: | ---: |
| home | A | find-product | find-product | 0.95 | 0.95 | yes | 548/90 | $0.000023016 |
| home | B | find-product | find-product | 0.99 | 0.99 | yes | 567/90 | $0.000023814 |
| home | C | find-product | add-to-cart | 0.75 | 0.19 | no | 2389/91 | $0.000100338 |
| search | A | open-offer | find-product | 0.67 | 0.20 | no | 560/90 | $0.000023520 |
| search | B | open-offer | open-offer | 0.80 | 0.80 | yes | 598/91 | $0.000025116 |
| search | C | open-offer | add-to-cart | 0.89 | 0.02 | no | 813/91 | $0.000034146 |
| offer | A | add-to-cart | add-to-cart | 0.52 | 0.52 | yes | 554/91 | $0.000023268 |
| offer | B | add-to-cart | add-to-cart | 0.96 | 0.96 | yes | 613/91 | $0.000025746 |
| offer | C | add-to-cart | add-to-cart | 0.99 | 0.99 | yes | 802/91 | $0.000033684 |
| post-add | A | go-to-cart | add-to-cart | 0.63 | 0.04 | no | 554/91 | $0.000023268 |
| post-add | B | go-to-cart | DONE | 0.58 | 0.41 | no | 635/89 | $0.000026670 |
| post-add | C | go-to-cart | DONE | 0.83 | 0.17 | no | 846/89 | $0.000035532 |
| cart | A | DONE | find-product | 0.51 | 0.21 | no | 551/90 | $0.000023142 |
| cart | B | DONE | DONE | 0.76 | 0.76 | yes | 652/89 | $0.000027384 |
| cart | C | DONE | DONE | 1.00 | 1.00 | yes | 779/89 | $0.000032718 |

| Shape | Correct | Input/output tokens | Provider cost USD |
| --- | ---: | ---: | ---: |
| A | 2/5 | 2,767/452 | $0.000116214 |
| B | 4/5 | 3,065/450 | $0.000128730 |
| C | 2/5 | 5,629/451 | $0.000236418 |
| **All final calls** | **8/15** | **11,461/1,353** | **$0.000481362** |

All 15 replies succeeded. A mistakes search for product listing and misses the cart. C overweights visible product cards: home and search choose add-to-cart because that label appears on both pages, and costs ~84% more than B. B nevertheless selects DONE on the successful **post-add modal** before cart verification; C does likewise. Current run-4j1v allows last-procedure expectations to justify DONE, but after add-to-cart those expectations only establish Added!, not item-in-cart. L31 must demand a mission-level cart expectation or a distinct cart/item check before DONE for this task. The page-kind matcher must prioritize the post-add modal text marker above the offer URL kind. Consent/ads alter page text between captures. One sample per shape/state cannot establish reliability on other sites.

## Reproduce

From repository root, run:

    nix develop -c python3 .scratch/research/state-measurement/capture.py
    bash .scratch/research/state-measurement/run.sh

The second command runs paid calls under secret-env ai --; do not run it merely to review saved results. The built CLI playbook check validated the matching example and resolved its checkers. Both scripts are throwaway research, not production run implementation.
