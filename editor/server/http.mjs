import { createServer } from 'node:http';
import { randomBytes, timingSafeEqual } from 'node:crypto';
import { readFile, mkdir, rm } from 'node:fs/promises';
import { join, extname } from 'node:path';
import { Store, mediaTypes } from './store.mjs';
import { Publisher } from './publisher.mjs';
import { fail, json, inside, validId } from './files.mjs';
import { editorRoot } from './config.mjs';

async function body(req, limit = 2_000_000) {
  let size = 0; const chunks = [];
  for await (const chunk of req) { size += chunk.length; if (size > limit) fail('Request is too large.', 413); chunks.push(chunk); }
  return Buffer.concat(chunks);
}
export async function createApp({ root, port = 0, publisherOptions = {}, store = new Store(root) }) {
  await mkdir(root, { recursive: true, mode: 0o700 });
  // Old preview builds contain unpublished material. Keep only this session's previews.
  await rm(join(root, 'previews'), { recursive: true, force: true });
  const publisher = new Publisher(store, publisherOptions);
  for (const job of await publisher.jobs()) {
    if (['building', 'pushing', 'deploying'].includes(job.state)) {
      job.state = job.sha ? 'check-required' : 'failed';
      job.message = job.sha ? 'The editor stopped during publication. Check this commit before publishing again.' : 'The editor stopped before a commit was created. Your draft is safe.';
      await publisher.record(job);
    }
  }
  const token = randomBytes(32).toString('hex');
  let origin, mutating = false;
  const server = createServer(async (req, res) => {
    const send = (status, value) => { res.writeHead(status, { 'Content-Type': 'application/json' }); res.end(JSON.stringify(value)); };
    res.setHeader('Cache-Control', 'no-store');
    res.setHeader('X-Content-Type-Options', 'nosniff');
    res.setHeader('Referrer-Policy', 'no-referrer');
    res.setHeader('Cross-Origin-Resource-Policy', 'same-origin');
    res.setHeader('Content-Security-Policy', "default-src 'self'; script-src 'self'; style-src 'self' 'unsafe-inline'; img-src 'self' data:; media-src 'self'; connect-src 'self'; frame-src 'self'; frame-ancestors 'self'; object-src 'none'; base-uri 'none'; form-action 'none'");
    let locked = false;
    try {
      if (req.headers.host !== new URL(origin).host) fail('Unexpected host.', 403);
      if (req.headers.origin && req.headers.origin !== origin) fail('Cross-origin requests are not allowed.', 403);
      if (['cross-site', 'same-site'].includes(req.headers['sec-fetch-site'])) fail('Open the editor from its local launcher.', 403);
      const url = new URL(req.url, origin), path = decodeURIComponent(url.pathname);
      if (!['GET', 'POST', 'PUT'].includes(req.method)) fail('Method not allowed.', 405);
      if (req.method !== 'GET') {
        const supplied = Buffer.from(req.headers['x-jez-token'] ?? '');
        if (supplied.length !== token.length || !timingSafeEqual(supplied, Buffer.from(token))) fail('Invalid local session. Reload the editor.', 403);
        if (req.headers.origin !== origin) fail('A same-origin request is required.', 403);
        if (mutating) fail('Another operation is running. Try again shortly.', 409);
        mutating = locked = true;
      }
      if (path === '/api/session' && req.method === 'GET') {
        send(200, { token, root, production: 'https://jez.blog' }); return;
      }
      if (path === '/api/library' && req.method === 'GET') {
        send(200, { drafts: await store.list(), library: await json(join(root, 'library.json'), { entries: [], updatedAt: null }), jobs: await publisher.jobs() }); return;
      }
      if (path === '/api/sync' && req.method === 'POST') { send(200, await publisher.sync()); return; }
      if (path === '/api/entries' && req.method === 'POST') { send(201, await store.create(JSON.parse(await body(req)).section)); return; }
      if (path === '/api/import' && req.method === 'POST') { send(200, await store.import(join(root, 'library'), JSON.parse(await body(req)).path)); return; }
      const entryRoute = path.match(/^\/api\/entries\/([a-f0-9-]{36})(?:\/(media|preview|publish|recover))?$/);
      if (entryRoute) {
        const [, id, action] = entryRoute;
        if (!action && req.method === 'GET') { send(200, await store.get(id)); return; }
        if (!action && req.method === 'PUT') {
          if (publisher.busy) fail('Wait for the preview or publication to finish before saving.', 409);
          send(200, await store.save(id, JSON.parse(await body(req)))); return;
        }
        if (req.method === 'POST' && action === 'media') {
          if (publisher.busy) fail('Wait for the running operation.', 409);
          const name = decodeURIComponent(req.headers['x-file-name'] ?? '');
          send(201, await store.upload(id, name, await body(req, 25 * 1024 * 1024))); return;
        }
        if (req.method === 'POST' && action === 'preview') { send(200, await publisher.preview(await store.get(id))); return; }
        if (req.method === 'POST' && action === 'publish') {
          const input = JSON.parse(await body(req)), entry = await store.get(id);
          if (input.revision !== entry.revision) fail('The draft changed. Review it again before publishing.', 409);
          send(202, await publisher.start(entry, input.confirmation)); return;
        }
        if (req.method === 'POST' && action === 'recover') {
          if (publisher.busy) fail('Wait for the running operation.', 409);
          const previous = await json(join(root, 'drafts', id, 'previous.json'));
          const current = await store.get(id);
          send(200, await store.save(id, { ...previous, revision: current.revision })); return;
        }
      }
      const jobRoute = path.match(/^\/api\/jobs\/([a-f0-9-]{36})\/check$/);
      if (jobRoute && req.method === 'POST') { send(202, await publisher.recheck(validId(jobRoute[1]))); return; }
      if (path === '/api/stop' && req.method === 'POST') {
        if (publisher.busy) fail('Wait for publication or preview to finish before stopping.', 409);
        send(200, { stopped: true }); setTimeout(() => server.close(), 100); return;
      }
      if (req.method !== 'GET' || path.startsWith('/api/')) fail('Not found.', 404);
      let file;
      const preview = path.match(/^\/preview\/([a-f0-9-]{36})\/(.*)$/);
      if (preview) {
        const relative = preview[2].endsWith('/') || !preview[2] ? preview[2] + 'index.html' : preview[2];
        file = await inside(join(root, 'previews', preview[1], 'dist'), relative);
        res.setHeader('Content-Security-Policy', "sandbox allow-same-origin; default-src 'none'; style-src 'self' 'unsafe-inline'; img-src 'self' data:; media-src 'self'; frame-ancestors 'self'; base-uri 'none'; form-action 'none'");
      } else if (path.startsWith('/media/jez-editor/')) {
        const match = path.match(/^\/media\/jez-editor\/([a-f0-9-]{36})\/([a-f0-9-]{36}\.[a-z0-9]+)$/);
        if (!match) fail('Not found.', 404);
        const entry = await store.get(match[1]).catch(error => { if (error.code === 'ENOENT') return null; throw error; });
        if (entry?.assets.some(a => a.file === match[2])) file = await inside(join(root, 'drafts', match[1], 'media'), match[2]);
        else file = await inside(join(root, 'library/public'), path.slice(1));
      } else if (path === '/favicon.ico') { res.writeHead(204); res.end(); return; }
      else file = await inside(join(editorRoot, 'dist'), path === '/' ? 'index.html' : path.slice(1));
      const type = { '.html': 'text/html; charset=utf-8', '.js': 'text/javascript', '.css': 'text/css', '.svg': 'image/svg+xml', ...mediaTypes }[extname(file)] ?? 'application/octet-stream';
      res.writeHead(200, { 'Content-Type': type }); res.end(await readFile(file));
    } catch (error) { send(error.status ?? (error.code === 'ENOENT' ? 404 : 500), { error: error.code === 'ENOENT' ? 'Not found.' : error.message }); }
    finally { if (locked) mutating = false; }
  });
  await new Promise((resolve, reject) => { server.once('error', reject); server.listen(port, '127.0.0.1', resolve); });
  origin = `http://127.0.0.1:${server.address().port}`;
  return { server, origin, token, store, publisher };
}