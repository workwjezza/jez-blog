# Verification report

Environment: macOS, Node 24.18.0, Astro 7.3.3, Chrome 153.0.8010.50.
Verification performed 2026-09-19. No production deployment was performed.

## Checks run

- `npm test`: all six unit tests pass (empty input, fail-closed drafts, sorting,
  conflicting slugs, experiment destinations, field validation).
- `npm run build`: succeeds; Astro check reports zero errors, warnings, or hints.
  The content loader separately logs expected empty-collection warnings.
- `npm run test:build` with optional Playwright tooling: isolated empty, populated,
  invalid, draft-only, and unpublish builds pass. Temporary projects are removed.
- Astro production preview serves the real empty build with HTTP 200. Its temporary
  verification server was stopped after the check.
- Empty and whitespace bios emit no paragraph or description metadata. A configured
  bio renders without changing a layout.
- Exact name and all four social labels, destinations, and their ordering verified.
- Both section headings remain visible with no entries, no lists, no placeholder
  paragraphs, no public creation controls, and no extra homepage sections.
- Final output contains one HTML page and no client scripts, demo entries, creator
  docs, reference-author content, or reference-author metadata.
- Draft and default-draft content is absent from every emitted file, not only the
  homepage. Direct draft URLs return 404 in the static browser test server.
- A relative image referenced only by a draft is not emitted. The loader prevents
  registering draft Markdown modules, because route filtering alone does not stop
  Astro from copying their assets. Assets placed in `public/` remain public by
  design and must never contain private/draft material.
- Published relative images are emitted; rebuilding after unpublishing removes
  those generated assets as well as the associated page routes.
- Public writing/local-experiment routes render Markdown paragraphs, headings,
  lists, quotes, links, code, images, tables, optional dates, and a working back link.
- Invalid destination combinations and duplicate slugs fail the build.
- Republishing an entry as a draft removes its previous generated route.
- Chrome checks at 1440, 1100, 1024, 768, 520, 390, and 320 CSS pixels: no horizontal
  page or container overflow, including long unbroken titles, URLs, code, and tables.
- 200% CSS zoom stress checks and narrow-viewport reflow checks pass.
- Keyboard Tab order, visible focus indicators, Enter on the back link, ordinary
  hover and writing-link hover pass. No page runtime errors were observed.
- Desktop/mobile screenshots reviewed against the reference at equivalent widths;
  the final homepage is intentionally much shorter. Wide-screen content x=305px,
  width=700px and mobile x=20px, width=350px at 390px are asserted.
- `npm audit`: zero known vulnerabilities at verification time.
- `git diff --check`: passes. Existing Swift/Xcode deletions were preserved.

## Not run / limitations

- Native browser-menu zoom was not automated. CSS zoom is a stress check, not an
  exact substitute; responsive reflow was separately tested down to 320px.
- Safari, Firefox, physical mobile devices, screen-reader speech, and a full formal
  accessibility audit were not tested. Semantic headings, landmark navigation, and
  visible focus were checked in Chrome.
- Audio/video playback was not tested with real supplied media (none exists yet).
- No hosting configuration, live production URLs, domain, feed, or sitemap was
  tested or created. Deploy only the static build, never the source tree.
- Visual differences are intentional and recorded in `docs/REFERENCE-DESIGN.md`:
  compact empty-page spacing, no sidebar, wider tablet column, inline social/back
  links, explicit focus styling, and unboxed experiments. No claim of pixel identity.

## Repeat browser verification

Install Playwright outside the project if desired, then supply its absolute module
path and an available browser executable as described in `docs/AUTHORING.md`.
No browser automation dependency or test fixture is included in public output.