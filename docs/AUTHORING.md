# Authoring Jeremy (Jez)'s blog

This directory is documentation, not a public route. Never put guides, templates,
private notes, or draft media in `public/`: everything there is copied to the site.

## Configuration

Edit `src/config/site.ts` for the display name, optional plain-text bio, and ordered
social links. An empty or whitespace-only bio emits no paragraph or description
metadata. Design belongs in layouts and the stylesheet, not content frontmatter.

## Add or edit content

1. Use the prompt in `docs/CREATOR-PROMPT.md`. Preserve the author's voice; make
   only light edits unless a rewrite is requested. Never invent facts or experiences.
2. Copy a template from `docs/templates/` into the appropriate directory:
   `src/content/writing/` or `src/content/experiments/`. Replace all bracketed fields.
   Do not copy templates into public output or create demonstration entries.
3. Choose an unused lowercase, hyphen-separated filename and slug. Search existing
   drafts as well as published entries before editing. Duplicate local slugs within
   a collection fail the build. The two collections have separate route prefixes.
4. Keep `draft: true` unless publication is explicitly requested. Omitting `draft`
   also defaults to true. Drafts are excluded even in development; review their
   Markdown in your editor. There is no browser editor or draft preview route.
5. Run `npm test`, `npm run build`, and `npm run test:build`.
6. Report the changed file, its draft/publication status, and blocking information.
   Publishing does not authorize deployment.

## Fields and destinations

Both collections accept `title`, `draft`, optional `description`, optional integer
`order`, and optional **quoted** `publicationDate: "YYYY-MM-DD"`. Dates must be real
calendar dates. Lower order numbers appear first. Entries with an explicit order
precede unordered entries; ties use newest publication date, then slug (or filename
for external experiments), then filename. Dated entries precede undated entries.

Writing requires `slug` and an author-supplied Markdown body. Its route is
`/writing/<slug>/`. Descriptions are optional page metadata, not a visible subtitle.

Experiments require **exactly one** of:
- `externalUrl`: a full HTTP(S) destination; no local page is generated.
- `slug`: creates `/experiments/<slug>/`, with an optional Markdown body.

Ask if an experiment's intended destination is unclear. Never guess project details.
Experiment descriptions appear next to titles, stacking on mobile. Homepage lists
never show publication dates or other metadata. Reading pages show a quiet date only
when supplied. Add headings starting at `##` beneath the page's automatic title.

## Publish, unpublish, and deploy

On an explicit publication request, set `draft: false` and set today's publication
date if missing (do not replace an existing date). The entry appears automatically;
no layout edit is needed. To unpublish, set `draft: true` and rebuild. Deploying that
updated build is a separate authorized action. Previously deployed copies and
third-party caches do not disappear simply because a local file changed.

There is no feed or sitemap at launch. If either is added later, use only
`getPublicWriting()` and `getPublicExperiments()` from `src/lib/content.ts`.
Never publish `.astro/`, `src/`, `docs/`, or tests; only deploy `dist/`.

## Markdown and media

Paragraphs, headings, ordered/unordered lists, block quotations, links, fenced code,
images, and tables are supported. Code uses a plain monospace style without a
client-side highlighter. Use meaningful image alt text, and native `video`/`audio`
controls for supplied media. Never add autoplay or third-party embeds unrequested.

For local images, keep files alongside Markdown and use relative image paths.
The publication-safe loader validates draft metadata but does not register draft
Markdown modules or their images with the asset pipeline. Do not place draft assets
in `public/`. That directory is only for intentionally public assets such as a
published video. A public asset stays public independently of its entry's draft
status; remove it separately when necessary. Raw HTML in Markdown is trusted author
input, not a submission interface. Avoid scripts and remote tracking embeds.

## Local commands

- `npm install` (or `npm ci` from the lockfile)
- `npm run dev` — local development, normally `http://localhost:4321`
- `npm run check` — Astro/TypeScript diagnostics
- `npm test` — schema, draft, slug, and ordering unit tests
- `npm run build` — checked static build to `dist/`
- `npm run preview` — serve that production build locally
- `npm run test:build` — isolated empty/populated/draft/unpublish build checks

Use Node 24 (`nvm use`); Astro requires at least Node 22.12. Astro emits benign
"No files found" / "collection ... empty" warnings for genuinely empty collections.
Do not add dummy files or suppress unrelated warnings to silence those messages.

Optional browser checks use an external Playwright installation, not a shipped site
dependency. Set `JEZ_BROWSER=1`, `PLAYWRIGHT_MODULE` to its absolute `index.mjs` path,
and optionally `CHROME_PATH` to a Chrome executable, then run `npm run test:build`.
Set `JEZ_SCREENSHOTS` to an absolute temporary directory to retain screenshots.
Fixtures are created only in an isolated temporary project and removed in `finally`.