# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

A **documentation / architecture deliverable**, not a running application. There is no
source code, no package manifest, no build or test system. The repo defines a greenfield
**cloud-native e-commerce reference architecture** (AWS-primary, open-standard-anchored)
as a set of prose documents plus a single interactive browser-based slide deck.

Not a git repository — there is no version history to consult.

## Files and their roles

- `README.md` — submission entry point / summary of the architecture.
- `ARCHITECTURE.md` — the full design document. Follows the **Genesis High Level Solution
  Design Document Template** (Confluence page `NNGA/969900033`). Section structure
  (Overview, Requirement Summary, Assumptions, High-Level Design with C4 diagrams,
  Planning, Test Plan, Post-deployment) is dictated by that template — preserve it.
- `architecture-deck.html` — **the single interactive visual deliverable.** A self-contained,
  keyboard-navigable slide deck (real AWS icons, animated page-5/page-6 flows, layered container
  view, data-store explainer, risks). Every icon is base64-inlined as a `data:` URI, so it opens
  on a double-click (`file://`) with no server and no external fetches. Generated / updated via
  the `architecture-ux-generate-flow` skill.
- `aws-icons/` — local AWS service SVGs (icon.icepanel.io). The deck's **build-time icon source**:
  the skill base64-encodes these into the deck's inline `AWS{}` map. The deck has no runtime
  dependency on this folder, but keep it so the deck can be regenerated.
- `infra/` — Terraform (reusable modules + per-env roots) implementing the architecture.
- `api/product-service/` — FastAPI product-management service (the Catalog microservice).
- `IMPLEMENTATION-PLAN.md` — the four-track (IaC / security / cost / API) build plan.

## Viewing the deck

Just open `architecture-deck.html` in a browser (double-click / `file://` works — icons are
inlined). It loads its JS/CSS inline; no server and no build step required. Navigate with
`←`/`→`/`Space`; `F` toggles fullscreen.

## Editing guidance

- **`architecture-deck.html`, `README.md`, and `ARCHITECTURE.md` describe the same
  architecture.** `ARCHITECTURE.md` is the source of truth; a design change flows
  `ARCHITECTURE.md` → `README.md` → the deck (regenerate/update via the
  `architecture-ux-generate-flow` skill). **There is no longer a multi-build sync rule** — the
  deck is the only maintained visual.
- Diagrams in the Markdown files are Mermaid; each Mermaid block also has an **ASCII
  fallback** immediately below it. Update both when changing a diagram.
- The deck embeds its node/edge/flow data and the inlined `AWS{}` icon map directly in the HTML;
  a tiny resolver fills every `<img data-ico="key">`. Author nodes with `data-ico`, never an
  external `src` (an external ref would break `file://`).
- **Verification is optional.** The deck is `file://`-openable and self-contained, so a
  lightweight check (open it, or assert every `img[data-ico]` resolved to a `data:` URI + grep for
  stale content) is enough for routine edits. Playwright (kept in `.claude/settings.local.json`)
  is available for a deeper check (console errors, screenshots) but is **not required**.
- The architecture is **target-state design, not reverse-engineered from code.** Do not
  claim runtime behavior is verified. `ARCHITECTURE.md` §4.4 explicitly flags that every
  behavioral claim must be re-verified against source once implementation begins.
