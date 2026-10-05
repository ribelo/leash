---
status: ready-for-agent
milestone: 14
---

# Decision model: configured, multimodal-aware, with a screenshot as an action

## Problem Statement

JEV is the only decision model Leash knows. Cloudflare's Clef (27B, multimodal) and Clef Flash (9B, multimodal) speak the same Decisions API through OpenRouter. A multimodal model can look at a page that has no useful rows — a streamed browser, a canvas — and decide; JEV cannot. Which model is better for which page is not knowable by argument. OpenRouter's pages say Workers AI truncates text state to ~2K tokens; whether that holds through OpenRouter is unknown and must be measured.

## User Stories

1. As the operator, I want `[models] decision_model` to accept `typesafe/jev-1.13-20260917`, `cloudflare/clef`, `cloudflare/clef-flash` (any Decisions-API model id), with the request contract unchanged, so that the model is one config line. ^dmod-27vx
2. As a maintainer, I want the model's input modalities read once at start from OpenRouter's `/api/v1/models` (`architecture.input_modalities`) and cached for the service's life, reported by `status.models.decision_modalities`, so that Leash knows whether it may send an image. ^dmod-m3q5
3. As a runner, I want, when the model accepts images and the element table has no actionable rows (or fewer than `decision.image_when_rows_below`, default 3), the viewport screenshot sent as the state's image part beside the text, so that a picture-only page is decidable (mode B). ^dmod-7w26
4. As a runner, I want a multimodal model offered `LOOK` as an operation — the next turn's state carries the screenshot — bounded to one LOOK per two steps, so that the model may ask to see the page (mode C); the two modes are independent and both configurable. ^dmod-mcgn
5. As a runner, I want coordinate actions (`click_at` etc.) offered to a multimodal decision model as operations with the target chosen by it as a point on the image it was shown (returned as a typed `point` question, not free text), so that the picture path exists at the decision-model level as it does at the pilot's. ^dmod-4ky5
6. As a maintainer, I want the per-step state size measured against the model's effective limit: one probe at start sends a known-length state and a question whose answer depends on its tail, recording whether the tail was read, logged once and shown in `status`, so that the ~2K truncation claim is a fact per model. ^dmod-pjmy
7. As a maintainer, I want the request contract pinned for Clef exactly as it is for JEV (texts verbatim in `questions.ml`, one version per model family if they differ), so that a model swap is a config change with a known prompt. ^dmod-as71
8. As a maintainer, I want the fake Decisions server to serve any model id and to accept image parts, so that the seam covers multimodal requests. ^dmod-f4lf
9. As a maintainer, I want the cost report to name the decision model and count image parts sent, so that the corpus can price the modes. ^dmod-l44q
10. As a maintainer, I want the pilot's own model unchanged (the planner through chat), so that this row touches only the decision model. ^dmod-ibfy

## Out of Scope

Choosing the model per leg; any provider other than OpenRouter.
