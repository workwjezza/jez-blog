// Run with PLAYWRIGHT_MODULE=/absolute/path/to/playwright/index.mjs node tests/browser.mjs
import assert from 'node:assert/strict';
import { mkdtemp, rm, readFile, mkdir, writeFile } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join, resolve } from 'node:path';
import { pathToFileURL } from 'node:url';
import { createApp } from '../server/http.mjs';
import { atomicJson } from '../server/files.mjs';

const { chromium } = await import(pathToFileURL(resolve(process.env.PLAYWRIGHT_MODULE)).href);
const root = await mkdtemp(join(tmpdir(), 'jez-editor-browser-'));
let app = await createApp({ root });
const browser = await chromium.launch({ headless: true, ...(process.env.CHROME_PATH ? { executablePath: process.env.CHROME_PATH } : {}) });
const page = await browser.newPage({ viewport: { width: 1350, height: 1000 } });
const errors = [];
page.on('pageerror', error => errors.push(error.message));
page.on('console', msg => { if (msg.type() === 'error') console.log('Browser console:', msg.text()); });
page.on('response', async response => { if (response.status() >= 400) console.log('HTTP error:', response.url(), await response.text().catch(() => '')); });
try {
  await page.goto(app.origin);
  await page.getByRole('button', { name: 'New writing', exact: true }).click();
  await page.locator('#title').fill('Browser test post');
  await page.locator('.tiptap').click();
  await page.keyboard.type('## Heading');
  await page.keyboard.press('Enter');
  await page.keyboard.type('Text in my voice.');
  await page.keyboard.press('Enter');
  await page.keyboard.type('- List item');
  await page.keyboard.press('Enter');
  await page.keyboard.type('Another item');
  await page.waitForTimeout(1200);
  assert.equal(await page.locator('#slug').inputValue(), 'browser-test-post');
  assert.equal(await page.locator('.tiptap h2').textContent(), 'Heading');
  assert.equal(await page.locator('.tiptap ul li').count(), 2);
  let entry = (await app.store.list())[0];
  assert.match(entry.body, /## Heading/);
  assert.match(entry.body, /Text in my voice\./);
  assert.ok(entry.document);
  await page.reload();
  await page.getByRole('button', { name: /Browser test post · writing/ }).click();
  assert.match(await page.locator('.tiptap').textContent(), /Text in my voice/);

  const png = Buffer.from('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVQIHWP4z8DwHwAFgAI/ScLbtAAAAABJRU5ErkJggg==', 'base64');
  await page.locator('#upload').setInputFiles({ name: 'test.png', mimeType: 'image/png', buffer: png });
  await page.locator('#media-dialog').waitFor({ state: 'visible' });
  await page.locator('#media-alt').fill('A verification image');
  await page.locator('#media-caption').fill('Local caption');
  await page.locator('#insert-media').click();
  await page.waitForTimeout(1100);
  entry = await app.store.get(entry.id);
  assert.match(entry.body, /<figure data-jez-media="image">/);
  assert.match(entry.body, /<figcaption>Local caption<\/figcaption>/);
  assert.equal(await page.locator('.tiptap figure').count(), 1);
  assert.equal(await page.locator('.tiptap img').evaluate(e => e.complete && e.naturalWidth > 0), true);
  await page.locator('.tiptap figure img').click();
  await page.locator('[data-command="edit-media"]').click();
  await page.locator('#media-caption').fill('Edited caption');
  await page.locator('#insert-media').click();
  await page.waitForTimeout(1000);
  assert.match((await app.store.get(entry.id)).body, /Edited caption/);

  await page.locator('#preview').click();
  await page.locator('#preview-dialog').waitFor({ state: 'visible', timeout: 60000 });
  const preview = page.frameLocator('#preview-frame');
  await preview.locator('h1').waitFor();
  assert.equal(await preview.locator('h1').textContent(), 'Browser test post');
  assert.equal(await preview.locator('figcaption').textContent(), 'Edited caption');
  assert.equal(await preview.locator('img').evaluate(e => e.complete && e.naturalWidth > 0), true);
  const previewUrl = await page.locator('#preview-frame').getAttribute('src');
  const response = await fetch(app.origin + previewUrl);
  assert.match(response.headers.get('content-security-policy'), /sandbox/);
  await page.locator('#close-preview').click();

  // Showing and canceling confirmation cannot trigger Git or production.
  await page.locator('#publish').click();
  await page.locator('#publish-dialog').waitFor({ state: 'visible' });
  assert.match(await page.locator('#publish-after').textContent(), /Edited caption/);
  await page.locator('#publish-dialog button[value="cancel"]').click();
  assert.equal((await app.publisher.jobs()).length, 0);
  await page.locator('#source-mode').click();
  assert.match(await page.locator('#source').inputValue(), /<figure/);
  await page.locator('#source').fill('<div class="custom">Preserve this exactly.</div>\n\n| A | B |\n|---|---|\n| 1 | 2 |');
  await page.waitForTimeout(1100);
  await page.locator('#visual-mode').click();
  assert.match(await page.locator('#notice').textContent(), /Keep source mode/);
  assert.equal(await page.locator('#source-label').isVisible(), true);
  const before = (await app.store.get(entry.id)).body;

  // Stop and recreate the local service using the same private data folder.
  app.server.closeAllConnections(); await new Promise(done => app.server.close(done));
  app = await createApp({ root });
  await page.goto(app.origin);
  await page.getByRole('button', { name: /Browser test post · writing/ }).click();
  await page.locator('#source-label').waitFor({ state: 'visible' });
  assert.equal(await page.locator('#source').inputValue(), before);
  assert.equal((await app.store.get(entry.id)).assets.length, 1);

  // Import an existing post without network/publishing; editing leaves source untouched.
  const sourcePath = 'src/content/writing/existing.md';
  await mkdir(join(root, 'library/src/content/writing'), { recursive: true });
  const raw = '---\ntitle: Existing post\nslug: existing\ndraft: false\npublicationDate: "2026-01-02"\n---\n\nOriginal text.\n';
  await writeFile(join(root, 'library', sourcePath), raw);
  await atomicJson(join(root, 'library.json'), { entries: [{ path: sourcePath, title: 'Existing post', section: 'writing' }], updatedAt: new Date().toISOString() });
  await page.reload();
  await page.getByRole('button', { name: 'Existing post · writing', exact: true }).click();
  await page.locator('#source-label').waitFor({ state: 'visible' });
  assert.equal(await page.locator('#slug').isDisabled(), true);
  await page.locator('#source').fill('Private new revision.');
  await page.waitForTimeout(1100);
  assert.equal(await readFile(join(root, 'library', sourcePath), 'utf8'), raw);
  const revision = (await app.store.list()).find(e => e.source);
  assert.equal(revision.publicationDate, '2026-01-02');
  assert.equal(revision.body, 'Private new revision.');
  for (const width of [1350, 800, 390]) {
    await page.setViewportSize({ width, height: 1000 });
    assert.ok(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth), `Overflow at ${width}`);
  }
  if (process.env.JEZ_SCREENSHOTS) {
    await mkdir(process.env.JEZ_SCREENSHOTS, { recursive: true });
    await page.setViewportSize({ width: 1350, height: 1000 });
    await page.screenshot({ path: join(process.env.JEZ_SCREENSHOTS, 'editor.png'), fullPage: true });
  }
  // Dedicated gallery: no title/slug/body setup and no per-file insertion dialog.
  await page.setViewportSize({ width: 1350, height: 1000 });
  await page.locator('#new-media').click();
  await page.locator('#gallery-workspace').waitFor({ state: 'visible' });
  assert.equal(await page.locator('#title').isVisible(), false);
  await page.locator('#gallery-upload').setInputFiles([
    { name: 'first.png', mimeType: 'image/png', buffer: png },
    { name: 'second.png', mimeType: 'image/png', buffer: png },
  ]);
  await page.waitForFunction(() => document.querySelectorAll('.gallery-tile').length === 2);
  assert.equal(await page.locator('#media-dialog').isVisible(), false);
  await page.locator('.gallery-tile').first().getByLabel('Description (optional)').fill('First description');
  await page.locator('.gallery-tile').first().getByLabel('Caption (optional)').fill('First caption');
  await page.locator('.gallery-tile').first().getByRole('button', { name: 'Move later' }).click();
  await page.waitForTimeout(1000);
  let gallery = (await app.store.list()).find(e => e.section === 'media');
  assert.equal(gallery.items[1].caption, 'First caption');
  await page.reload();
  await page.getByRole('button', { name: /Media · .* · media/ }).click();
  await page.locator('#gallery-workspace').waitFor({ state: 'visible' });
  assert.equal(await page.locator('.gallery-tile').count(), 2);
  assert.equal(await page.locator('.gallery-tile').last().getByLabel('Caption (optional)').inputValue(), 'First caption');
  await page.locator('#preview').click();
  await page.locator('#preview-dialog').waitFor({ state: 'visible', timeout: 90000 });
  const galleryFrame = page.frameLocator('#preview-frame');
  await galleryFrame.locator('.media-grid img').first().waitFor();
  assert.equal(await galleryFrame.locator('.media-grid figure').count(), 2);
  assert.equal(await galleryFrame.locator('.media-grid figcaption').textContent(), 'First caption');
  assert.equal(await galleryFrame.locator('.media-grid img').last().getAttribute('alt'), 'First description');
  await galleryFrame.locator('.media-grid img').first().scrollIntoViewIfNeeded();
  await page.waitForTimeout(300);
  assert.equal(await galleryFrame.locator('.media-grid img').first().evaluate(img => img.complete && img.naturalWidth > 0), true);
  await page.locator('#close-preview').click();
  // Drag/drop and paste both append directly, including after a partial upload failure.
  for (const eventName of ['drop', 'paste']) {
    await page.locator('#gallery-drop').evaluate((element, { eventName, bytes }) => {
      const transfer = new DataTransfer(); transfer.items.add(new File([new Uint8Array(bytes)], `${eventName}.png`, { type: 'image/png' }));
      const event = eventName === 'drop' ? new DragEvent('drop', { bubbles: true, cancelable: true, dataTransfer: transfer }) : new ClipboardEvent('paste', { bubbles: true, cancelable: true, clipboardData: transfer });
      element.dispatchEvent(event);
    }, { eventName, bytes: [...png] });
    await page.waitForFunction(count => document.querySelectorAll('.gallery-tile').length === count, eventName === 'drop' ? 3 : 4);
  }
  await page.locator('#gallery-upload').setInputFiles([
    { name: 'good.png', mimeType: 'image/png', buffer: png },
    { name: 'bad.png', mimeType: 'image/png', buffer: Buffer.from('not an image') },
  ]);
  await page.waitForFunction(() => document.querySelector('#notice').textContent.includes('do not match'));
  assert.equal(await page.locator('.gallery-tile').count(), 5);
  await page.locator('.gallery-tile').last().getByRole('button', { name: 'Remove', exact: true }).click();
  await page.locator('#publish').click();
  await page.locator('#publish-dialog').waitFor({ state: 'visible' });
  assert.match(await page.locator('#publish-summary').textContent(), /Media gallery \(4 tiles\)/);
  assert.match(await page.locator('#publish-after').textContent(), /First caption/);
  await page.locator('#publish-dialog button[value="cancel"]').click();
  assert.equal((await app.publisher.jobs()).length, 0);
  for (const [width, columns] of [[1350, 3], [800, 2], [390, 1]]) {
    await page.setViewportSize({ width, height: 1000 });
    assert.equal(await page.locator('#gallery-items').evaluate(e => getComputedStyle(e).gridTemplateColumns.split(' ').length), columns);
    assert.ok(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth));
  }
  // Public assets imported from the cached GitHub library render in the editor.
  gallery = await app.store.get(gallery.id);
  const importedStore = new (app.store.constructor)(join(root, 'import-helper'));
  const publishedGallery = await app.store.materialize(gallery, join(root, 'library'), true);
  const importedGallery = await importedStore.import(join(root, 'library'), publishedGallery.file);
  await atomicJson(app.store.path(importedGallery.id), importedGallery);
  await rm(join(root, 'drafts', gallery.id), { recursive: true });
  await page.reload();
  await page.getByRole('button', { name: /Media · .* · media · revision/ }).click();
  await page.locator('.gallery-tile img').first().scrollIntoViewIfNeeded();
  await page.waitForTimeout(300);
  assert.equal(await page.locator('.gallery-tile img').first().evaluate(img => img.complete && img.naturalWidth > 0), true);
  await page.locator('#new-project').click();
  await page.locator('#title').fill('Browser project');
  await page.locator('#destination').selectOption('external');
  await page.locator('#externalUrl').fill('https://example.org');
  await page.waitForTimeout(1000);
  assert.equal((await app.store.list()).find(e => e.title === 'Browser project').section, 'projects');
  assert.deepEqual(errors, []);
  console.log('PASS browser: writing regression checks; Projects; gallery batch upload, reorder/remove, autosave/reload, drag/drop, paste, partial failure recovery, real Astro gallery preview, cached public assets, publication cancellation, and 3/2/1 columns. No production publishing was invoked.');
} finally {
  await browser.close(); app.server.closeAllConnections(); await new Promise(done => app.server.close(done));
  await rm(root, { recursive: true, force: true });
}