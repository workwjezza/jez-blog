# Jez Editor — local authoring app

A separate local browser editor for `jez.blog`. The blog remains Astro + Markdown.
This app is **not deployed** with the public site. No post has been published to
test it.

## Open it

Double-click `/Users/studio-jd/Projects/jez-blog/Jez Editor.command` in Finder.
It starts the local server and opens `http://127.0.0.1:4319`. Keep its Terminal
window open while using the editor. The first launch can install dependencies.
Later launches rebuild only the small editor interface before opening it.
After a code update, use **Stop editor** first if it is already running, then reopen
the launcher. An existing server otherwise keeps its previously loaded server code.

If macOS refuses to open a downloaded launcher, inspect it first and then use
Finder's **Open** command. You can also run these commands yourself:

```sh
cd /Users/studio-jd/Projects/jez-blog
nvm use
npm ci
npm ci --prefix editor
npm run build --prefix editor
node editor/server/index.mjs --open
```

Stop with the **Stop editor** button, Ctrl+C in its terminal, or:

```sh
node /Users/studio-jd/Projects/jez-blog/editor/server/index.mjs --stop
```

Node 24 is required. Publishing also requires authenticated `git`, `gh`, and
`vercel` commands. The launcher discovers the existing nvm/Homebrew tools. If
authentication expires, sign in through your terminal; do not paste tokens into
posts, the app source, or browser storage.

## Write, preview, publish

1. Click **New writing** (or **Project**). Add your title and text. The slug is
   suggested until you edit it manually. The published slug is locked on revisions.
2. Use the toolbar, keyboard shortcuts, or `## ` / `- ` formatting shortcuts. Pasted
   rich text is stripped of font/color styling and active embeds. Formatting does
   not rewrite your words or send them to an AI service.
3. Watch for **Saved on this Mac**. Autosave occurs after a short typing pause.
   The last successful prior save is recoverable. Unsaved work triggers a browser
   close warning; a browser/OS crash before autosave can still lose recent keystrokes.
4. Add media, enter alt text and optional captions, and insert at the cursor. Select
   a media block to move it up/down, edit its description/caption, or remove it.
   Replace by removing the old block and inserting another upload. Unused uploads
   remain private; they are not published. Source mode supports media insertion too.
5. **Preview** builds a temporary, local Astro site using the real reading template.
   It uploads nothing. Preview scripts/embeds are blocked. External images/media
   are blocked locally for privacy; trusted remote media may behave differently live.
6. **Publish to jez.blog** opens a review dialog. It shows the destination, the
   saved remote version, and proposed content. Confirming authorizes both the
   selected post's public GitHub commit and its production deployment.
7. Leave the app running while it builds, pushes, and checks Vercel. **Live** means
   the production deployment's commit matches and the resulting URL returns HTTP
   success. A pushed commit alone is not labeled live.

New posts receive a date on publication if absent. Existing dates are preserved.
The Markdown file is written to the existing blog collection without changing a
layout. The first publish uses an isolated clone of GitHub's main branch, not the
dirty local working tree. It pushes only the selected Markdown and referenced new
media. It never force-pushes. The main local checkout is not automatically pulled;
use **Refresh** to read GitHub, or deliberately update your coding checkout later.

## Editing and Markdown fidelity

### Media gallery (no post composition needed)

1. Click **Media** to start a private batch.
2. Drop multiple files, click **Upload files**, or paste images into the upload area.
   Every successful upload becomes a tile immediately, without an Insert dialog.
   If a later file fails validation, earlier successful uploads remain saved and visible.
3. Optionally add captions and accessible descriptions. Leave descriptions blank for
   decorative images; describe meaningful images accurately. Use **Move earlier** /
   **Move later** to arrange this batch, or **Remove** to leave an upload out.
4. **Preview** shows this batch in the real homepage grid. **Publish to jez.blog**
   reviews and publishes all tiles in this batch with one confirmation.

Titles, slugs, and dates are automatic. New batches appear first; the public grid is
3 desktop / 2 tablet / 1 phone columns, with rows growing downward. No public upload
controls or third-party service are added. Select a local batch to continue editing;
use **Refresh** and select a GitHub Media batch to edit already-published tiles.
Removing every tile and publishing changes removes that batch from the gallery.
Already-public asset files/history are retained; removing a tile is not secure erasure.

Existing per-file and 50 MB publication limits apply. A batch holds up to 500 items;
start another batch as needed. These are upload safeguards, not a gallery row limit.
HEIC/SVG still require conversion; no transcoding or metadata stripping is performed.

**Deployment prerequisite:** the Projects/Media site update must reach GitHub main
before publishing those sections. The editor refuses to publish them against an old
site rather than silently creating invisible content. It never pushes local code changes.

Old Experiments drafts are displayed as Projects without deleting or moving private
files. Existing published Markdown paths stay unchanged; public links use `/projects/`.

### Writing and Projects

Click **Refresh** to read GitHub entries, then select one. This creates a private
working revision. Autosaving that revision does not edit the published Markdown.
Existing entries initially open in source mode so their Markdown is preserved
exactly. Simple text can be switched to visual mode with a normalization warning.
HTML, tables, reference links, existing image Markdown, and other advanced syntax
stay in source mode rather than being silently simplified. New visual drafts keep
their Tiptap document as well as Markdown, including image/video/audio blocks.

If a coding agent changes a post on GitHub after you opened it, publishing stops
with a conflict. Keep the draft and ask the agent to reconcile it. This first
version deliberately has no destructive merge/overwrite shortcut or public delete
button. Slug migrations, unpublishing, and restoring old Git history stay with your
coding agent.

## Media and privacy

Private data lives at:

`/Users/studio-jd/Library/Application Support/Jez Editor/`

- `drafts/`: text, editor documents, uploaded originals, previous save
- `library/`: cached GitHub content/assets for reading and preview
- `jobs/`: recoverable publication state and selected published snapshots
- `previews/`: local rendered previews, cleared on server startup
- `work/`: temporary publishing checkouts, removed after operations
- `session.json`: local session information, removed on a clean shutdown

Back up this folder using Time Machine or your chosen local backup. It is outside
the Git repository but **not encrypted by this app**. Local account access and
FileVault remain your responsibility. There is no cloud draft sync.

PNG/JPEG/WebP/GIF: maximum 10 MB each. MP4/WebM/MP3/M4A/OGG/WAV: maximum 25 MB each.
Only referenced attachments are copied; total referenced new media is capped at
50 MB per publication. Extensions and file signatures are checked, but this is not
antivirus scanning or codec transcoding. Convert HEIC/SVG before importing. Large
video needs a separate hosting decision. Browser codec support varies.

Publishing uploads source and media to the **public GitHub repository**. Published
assets use immutable UUID paths. Removing a block from a later revision does not
erase that asset from Git history or caches; the app conservatively retains already
published assets to avoid breaking other references. Ask your coding agent for a
deliberate public-media cleanup if needed. Originals may contain EXIF/location data;
strip sensitive metadata before importing. The app does not claim to scrub it.

## Failure handling

- Save conflict: another tab saved first. Current editor text remains visible; copy
  it before reloading. No silent last-write-wins overwrite.
- Build failure: nothing is pushed; draft and uploads remain local.
- Concurrent GitHub changes: normal Git non-fast-forward protection stops pushing.
- Network error during push: **check-required**, because the push may have landed.
  Use **Check deployment**, which checks remote ancestry before allowing a retry.
- Vercel failure after push: the commit is public, but deployment is not confirmed.
  Inspect Vercel / ask your coding agent to repair the build, then check again.
- Restart during publishing: the job is marked failed-before-commit or check-required.
  The editor never automatically republishes on startup.

## Security boundaries

The server binds only to `127.0.0.1`, verifies Host/Origin/Fetch-Site, and requires a
per-session token for mutation endpoints. Browser credentials are not used for Git
or Vercel. Commands run without a shell with fixed destinations. Path handling is
restricted, and previews are sandboxed. Do not expose this service through a tunnel
or reverse proxy; this is a single-user local tool, not a hosted CMS.

## Development and tests

```sh
npm run build --prefix /Users/studio-jd/Projects/jez-blog/editor
npm test --prefix /Users/studio-jd/Projects/jez-blog/editor
```

Optional browser tests use an external Playwright installation:

```sh
PLAYWRIGHT_MODULE=/absolute/path/to/playwright/index.mjs \
CHROME_PATH='/Applications/Google Chrome.app/Contents/MacOS/Google Chrome' \
node /Users/studio-jd/Projects/jez-blog/editor/tests/browser.mjs
```

Tests use temporary private directories and temporary bare Git repositories. They
never push to the real repository or deploy test content. Keep the editor's own
dependencies under `editor/`; the public site does not depend on Tiptap or Vite UI
code. See `editor/VERIFICATION.md` for checks run and limitations.