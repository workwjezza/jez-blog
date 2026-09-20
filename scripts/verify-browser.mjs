// Optional tooling, deliberately not shipped as a site dependency.
import assert from 'node:assert/strict';
import { createServer } from 'node:http';
import { readFile, mkdir } from 'node:fs/promises';
import { extname, join, resolve } from 'node:path';
import { pathToFileURL } from 'node:url';

const [project, stage] = process.argv.slice(2);
assert.ok(project && ['empty', 'populated'].includes(stage), 'Run through verify-build.mjs');
assert.ok(process.env.PLAYWRIGHT_MODULE, 'Set PLAYWRIGHT_MODULE to an installed playwright/index.mjs');
const { chromium } = await import(pathToFileURL(resolve(process.env.PLAYWRIGHT_MODULE)).href);
const types = { '.html': 'text/html', '.css': 'text/css', '.svg': 'image/svg+xml', '.png': 'image/png' };
const server = createServer(async (req, res) => {
  try {
    let path = decodeURIComponent(new URL(req.url, 'http://localhost').pathname);
    if (path.endsWith('/')) path += 'index.html';
    const file = resolve(project, 'dist', `.${path}`);
    if (!file.startsWith(resolve(project, 'dist') + '/')) throw new Error('Invalid path');
    const body = await readFile(file);
    res.writeHead(200, { 'Content-Type': types[extname(file)] ?? 'application/octet-stream' });
    res.end(body);
  } catch { res.writeHead(404); res.end('Not found'); }
});
await new Promise(done => server.listen(0, '127.0.0.1', done));
const base = `http://127.0.0.1:${server.address().port}`;
let browser;
try {
  browser = await chromium.launch({ headless: true, ...(process.env.CHROME_PATH ? { executablePath: process.env.CHROME_PATH } : {}) });
  const page = await browser.newPage();
  const errors = [];
  page.on('pageerror', error => errors.push(error.message));
  const routes = stage === 'empty' ? ['/'] : ['/', '/writing/verification-post/', '/writing/undated/', '/projects/local-verification/', '/projects/new-project/'];
  for (const width of [1440, 1100, 1024, 768, 520, 390, 320]) {
    await page.setViewportSize({ width, height: 900 });
    for (const route of routes) {
      assert.equal((await page.goto(base + route)).status(), 200);
      const dimensions = await page.evaluate(() => ({ viewport: innerWidth, content: document.documentElement.scrollWidth, body: document.body.scrollWidth }));
      assert.ok(dimensions.content <= width && dimensions.body <= width, `${stage} ${route} overflows at ${width}: ${JSON.stringify(dimensions)}`);
      const hiddenOverflow = await page.evaluate(() => [...document.querySelectorAll('body *')].filter(e => e.clientWidth && e.scrollWidth > e.clientWidth + 1).map(e => e.tagName));
      assert.deepEqual(hiddenOverflow, [], `Internal horizontal overflow: ${route} at ${width}`);
      if (route === '/' && stage === 'empty') {
        assert.equal(await page.locator('h1').textContent(), 'Jeremy (Jez)');
        assert.equal(await page.locator('section').count(), 3);
        assert.equal(await page.locator('section ul').count(), 0);
        assert.equal(await page.locator('.bio').count(), 0);
        const rect = await page.locator('main').boundingBox();
        if (width === 1440) { assert.equal(rect.x, 305); assert.equal(rect.width, 700); }
        if (width === 390) { assert.equal(rect.x, 20); assert.equal(rect.width, 350); }
        for (const label of ['Twitter', 'IG', 'YouTube', 'GitHub']) {
          await page.keyboard.press('Tab');
          const focus = await page.evaluate(() => ({ text: document.activeElement.textContent, outline: getComputedStyle(document.activeElement).outlineStyle }));
          assert.equal(focus.text, label);
          assert.equal(focus.outline, 'solid');
        }
      }
      if (route === '/' && stage === 'populated') {
        const columns = await page.locator('.media-grid').evaluate(e => getComputedStyle(e).gridTemplateColumns.split(' ').length);
        assert.equal(columns, width <= 520 ? 1 : width < 1100 ? 2 : 3);
        assert.equal(await page.locator('.media-grid figure').count(), 2);
        await page.locator('.media-grid img').first().scrollIntoViewIfNeeded();
        await page.waitForFunction(() => [...document.querySelectorAll('.media-grid img')].every(img => img.complete && img.naturalWidth > 0));
      }
      // Magnification stress test; narrower viewports above independently verify reflow.
      await page.evaluate(() => { document.documentElement.style.zoom = '2'; });
      assert.ok(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth), `200% CSS zoom overflow: ${route} at ${width}`);
      await page.evaluate(() => { document.documentElement.style.zoom = ''; });
      if ([1440, 390].includes(width) && process.env.JEZ_SCREENSHOTS) {
        await mkdir(process.env.JEZ_SCREENSHOTS, { recursive: true });
        await page.evaluate(() => { document.activeElement?.blur(); });
        await page.mouse.move(0, 0);
        await page.screenshot({ path: join(process.env.JEZ_SCREENSHOTS, `${stage}-${width}-${route.replaceAll('/', '-') || 'home'}.png`) });
      }
    }
  }
  await page.goto(base + '/');
  const first = page.locator('a').first();
  await first.hover();
  assert.equal(await first.evaluate(e => getComputedStyle(e).opacity), '0.5');
  if (stage === 'populated') {
    await page.locator('.writing-list a').first().hover();
    assert.deepEqual(await page.locator('.writing-list a').first().evaluate(e => ({ color: getComputedStyle(e).color, background: getComputedStyle(e).backgroundColor })), { color: 'rgb(255, 255, 255)', background: 'rgb(0, 0, 0)' });
    await page.goto(base + '/writing/verification-post/');
    await page.keyboard.press('Tab');
    assert.equal(await page.evaluate(() => document.activeElement.textContent), '← Back');
    await page.keyboard.press('Enter');
    await page.waitForURL(base + '/');
  }
  for (const route of ['/writing/secret-draft/', '/writing/secret-default/', '/experiments/secret-experiment/']) {
    assert.equal((await page.goto(base + route)).status(), 404);
  }
  assert.deepEqual(errors, []);
  console.log(`PASS browser (${stage}): seven widths 320–1440px, ${stage === 'populated' ? 'long text/media, ' : ''}200% CSS zoom, keyboard/focus, hover, draft 404s, no runtime errors.`);
} finally {
  await browser?.close();
  await new Promise(done => server.close(done));
}