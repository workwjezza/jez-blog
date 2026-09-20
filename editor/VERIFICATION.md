# Editor verification

Implemented and checked on macOS with Node 24.18.0 and Chrome 153.
Projects/Media checks rerun on 2026-09-20.
No test post was sent to GitHub or deployed to jez.blog.

## Automated checks

- Editor build: Vite production build succeeds. Editor dependencies are separate
  from the site's package manifest and excluded from Vercel uploads.
- Eleven Node tests cover private autosave and restart, prior-save recovery data,
  concurrent save rejection, validation and persistence of media, publication
  schema/date serialization, source-fallback detection, Host/Origin/CSRF/path
  protection, and temporary-repository publication.
- Gallery coverage includes direct-to-tile uploads, reorder/removal, restart,
  safe asset references, size limits, selective materialization, imported batches,
  removal of all published tiles, and legacy Experiments draft/source compatibility.
- Isolated publication tests refuse Media against an old remote site, then publish
  only the chosen batch and its assets after enabling support. No real remote is used.
- Publishing tests use temporary bare Git repositories, real Git commits/pushes,
  and simulated build/deployment success/failure. They verify only selected content
  is committed, unrelated working changes remain untouched, upstream content
  conflicts stop, build failure does not push, uncertain push failures require
  reconciliation, and deployment failure never falsely reports "Live".
- Restart tests verify interrupted jobs are marked failed or check-required without
  automatically running Git or deployment commands.
- Chrome browser tests exercise real Markdown shortcuts, local autosave, reload,
  server restart, image upload/insertion, alt text/caption editing, actual Astro
  preview generation and image rendering, publish-dialog cancellation, source-mode
  preservation, importing/editing a published fixture without changing its source,
  and layouts at 1350, 800, and 390px. No uncaught page errors.
- Gallery browser tests pass for multi-upload without an insertion dialog,
  captions/descriptions, reorder/remove, autosave/reopen, drag/drop and paste,
  private Astro homepage previews, cached public assets, confirmation cancellation,
  Projects creation, and 3/2/1 columns. A deliberately invalid image returns the
  expected HTTP 400; earlier valid files in that batch remain saved and visible.
- Public site unit tests, checked production build, and isolated empty/draft/public
  build tests still pass. Final real content collections contain no Markdown entries.
- Editor dependency audit reports zero known vulnerabilities. YAML was upgraded to
  2.9.1 after the initial audit identified a moderate advisory in 2.8.2.
- Existing Vercel deployment inspected read-only to verify the deployment-details
  API exposes the commit SHA used by the live-status check.

## Not run / deliberate limits

- A real user-authored post has not yet been published through the new button.
  Full end-to-end production writing/pushing remains deliberately untested until
  there is real content and the user confirms publication in the app.
- macOS Finder/Gatekeeper behavior can vary; the launcher shell syntax and executable
  permission are checked, but notarization and packaging as a native .app are not
  provided.
- No Safari/Firefox or screen-reader audit; browser tests use Chrome.
- Audio/video attachment signature/size handling is implemented. Real playback
  across codecs/devices, video transcoding, image optimization, and EXIF stripping
  are not verified/provided. HEIC/SVG import is rejected explicitly.
- Existing complex Markdown opens in source mode; it is not promised to be editable
  losslessly through the visual interface. Tiptap's Markdown integration is beta;
  source fallback and private previous-save recovery avoid silent conversion.
- No cloud backup, private hosted editor, multi-user collaboration, scheduling,
  destructive asset deletion, or automatic conflict merging. Media tiles may be
  removed from the gallery by publishing a revision, without erasing asset history.
- Already-published assets are retained conservatively. Removing them from the
  document is not a guarantee of deleting public Git history or cached copies.

Commands are in the editor README. Test fixtures are removed in `finally` blocks
and never added to the real blog collections or private working library.