---
name: ui-reference
description: Use for every frontend implementation task. Mandatory UI reference workflow — search the web for best-in-class UI references before implementing, extract their layout, spacing, typography, color, and component patterns, then build the UI to that reference quality.
---

# UI Reference

Mandatory workflow for all frontend implementation tasks. Before writing any UI code, search the web for the best UI references for the screen or component being built, extract their design patterns, and implement to that reference quality. Applies together with `oop-modularized`.

## When to run

- Before implementing any new screen, page, component, or visual change.
- When the task involves layout, styling, states, or interaction design.
- When the task description is vague about how the UI should look or behave.

Skip only for pure logic or API changes with zero visual surface — and when in doubt, run it.

## Reference sources

Search these best-in-class UI reference sources on the web (use the `websearch` skill; not all sources fit every query — pick the ones that match the screen type):

- **Pattern libraries & galleries**: godly.website, minimal.gallery, component.gallery, refero.design, land-book.com, saaslandingpage.com, pageflows.com, uimovement.com
- **Award-winning sites**: awwwards.com, siteinspire.com, httpster.net
- **Product UI libraries**: mobbin.com (real app screenshots), screenlane.com
- **Design showcases**: dribbble.com, behance.net
- **Best-in-class product sites** as direct exemplars: stripe.com, linear.app, vercel.com, github.com, notion.so — search for the specific screen on these when the task is a common SaaS/dashboard pattern.

## Procedure

1. **Define the target** — identify the exact screen, component, or interaction to build and its context (app type, audience, existing design system).
2. **Search** — run web searches combining the screen type with reference intent, e.g. `dashboard UI design awwwards`, `pricing page design refero`, `site:mobbin.com onboarding flow`. Run at least two distinct searches; use the `web-research` skill for evidence quality.
3. **Select** — pick 1–3 references that fit the project's stack, existing tokens, and constraints. Prefer references that match the product category (SaaS, e-commerce, dashboard, marketing).
4. **Extract** — from each reference, record: layout structure, spacing rhythm, typography hierarchy and scale, color palette and accent usage, component patterns (cards, tables, nav, forms), states (loading, empty, error, hover), and responsive behavior.
5. **Adapt to the project** — map the extracted patterns onto the project's existing design tokens, components, and conventions. The reference drives the design intent; the project's design system decides the concrete values.
6. **Implement** — build the UI following the extracted patterns.
7. **Verify** — compare the result against the chosen references (visually check changed screens); fix gaps in hierarchy, spacing, states, or responsiveness before reporting done.
8. **Report** — list which reference URLs were used and what was taken from each.

## Rules

- Cite every reference URL in your report to the Orchestrator; unverified or uncited references are not acceptable.
- Never copy copyrighted assets: no hotlinking or rip of images, logos, illustrations, fonts, or brand assets. Copy patterns and structure only.
- Adapt, do not clone: references must be reconciled with the project's existing tokens, components, and conventions — never invent colors or break the project's spacing/type scales to match a screenshot pixel-for-pixel.
- Accessibility and responsiveness are hard constraints; a reference never overrides them (contrast, focus states, mobile behavior).
- Keep the design cohesive: one reference-led direction per screen, not a patchwork of styles from many sources.
- If no acceptable reference is found after two searches, report that with the queries tried instead of improvising silently.

## DON'T

- Write UI code before searching for references.
- Use training knowledge of a design as a substitute for a current web reference.
- Copy assets, logos, or copyrighted material from references.
- Ignore the project's design tokens or existing component conventions.
- Claim completion without citing the references used.
