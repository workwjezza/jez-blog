# Jeremy (Jez)'s personal blog

Astro + Markdown, static output, no client JavaScript. Launch content is deliberately
empty. Only the homepage is built until entries are explicitly published.

From the repository root:

```sh
nvm use
npm ci
npm run dev
```

Build and inspect locally:

```sh
npm test
npm run build
npm run test:build
npm run preview
```

- Configuration: `src/config/site.ts`
- Empty collections: `src/content/writing/`, `src/content/projects/`, `src/content/media/`
- Legacy project compatibility: `src/content/experiments/` is still read; old detail URLs redirect to `/projects/`.
- Reading template: `src/layouts/ReadingLayout.astro`
- Content templates: `docs/templates/` (not loaded as content)
- Authoring guide: `docs/AUTHORING.md`
- Reusable creator prompt: `docs/CREATOR-PROMPT.md`
- Measured design specification: `docs/REFERENCE-DESIGN.md`
- Checks and limitations: `docs/VERIFICATION.md`
- Optional local visual editor: `docs/LOCAL-EDITOR.md`

Production deployment is authorized on Vercel project `jez4/jez-blog`, with the
requested domain `jez.blog`. The project is connected to GitHub repository
`workwjezza/jez-blog`: pushes to `main` trigger production deployment. Publishing a
local entry and pushing it are therefore distinct actions; do not push without
deployment authorization. No feed or sitemap is configured.

Vercel runs `npm ci` and `npm run build`, and serves only `dist/`. Local Vercel
settings and credentials are ignored by Git. The current routes assume hosting at
the origin root; subdirectory hosting would require an explicit base-path decision.

The repository already contained deletions of an older Swift/Xcode application,
including its root README. Those deletions and the old editor launch settings were
left untouched. This documentation describes only the new static website.