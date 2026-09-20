import test from 'node:test';
import assert from 'node:assert/strict';
import { mkdtemp, rm, mkdir, readFile, writeFile } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { request } from 'node:http';
import { Store, checkMedia } from '../server/store.mjs';
import { createApp } from '../server/http.mjs';
import { Publisher } from '../server/publisher.mjs';
import { command } from '../server/commands.mjs';
import { markdown, parseContent, publicRoute } from '../server/content.mjs';
import { needsSource } from '../client/media.js';
import { atomicJson } from '../server/files.mjs';

const png = Buffer.from('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVQIHWP4z8DwHwAFgAI/ScLbtAAAAABJRU5ErkJggg==', 'base64');
async function temp(fn) { const root = await mkdtemp(join(tmpdir(), 'jez-editor-test-')); try { await fn(root); } finally { await rm(root, { recursive: true, force: true }); } }
const draft = async store => { const entry = await store.create(); return store.save(entry.id, { ...entry, title: 'Test post', slug: 'test-post', body: 'Author text.\n\n## Heading\n\n- One\n- Two' }); };

test('private autosave, restart, prior revision, and stale-save conflict', () => temp(async root => {
  const store = new Store(root), entry = await draft(store);
  const updated = await store.save(entry.id, { ...entry, body: 'Edited text' });
  assert.equal((await new Store(root).get(entry.id)).body, 'Edited text');
  assert.equal(JSON.parse(await readFile(join(root, 'drafts', entry.id, 'previous.json'), 'utf8')).body, entry.body);
  await assert.rejects(store.save(entry.id, { ...entry, body: 'Old tab' }), /another tab/);
  assert.equal(updated.revision, 2);
  await assert.rejects(store.get('../../etc/passwd'), /Invalid entry ID/);
}));

test('media validation, persistence, and only referenced assets materialized', () => temp(async root => {
  const store = new Store(join(root, 'data')); let entry = await draft(store);
  const uploaded = await store.upload(entry.id, 'image.png', png); entry = uploaded.entry;
  assert.equal(checkMedia('image.png', png).mime, 'image/png');
  assert.throws(() => checkMedia('image.png', Buffer.from('<script>')), /do not match/);
  assert.throws(() => checkMedia('bad.svg', png), /Supported files/);
  assert.throws(() => checkMedia('huge.png', Buffer.alloc(11 * 1024 * 1024)), /10 MB/);
  const checkout = join(root, 'site'); await mkdir(checkout);
  assert.equal((await store.materialize(entry, checkout, true)).changed.length, 1);
  entry = await store.save(entry.id, { ...entry, body: `![Alt](${uploaded.asset.url})` });
  const result = await store.materialize(entry, checkout, true);
  assert.equal(result.changed.length, 2);
  assert.deepEqual(await readFile(join(checkout, result.changed[1])), png);
  assert.equal((await new Store(join(root, 'data')).get(entry.id)).assets.length, 1);
}));

test('schema validation, source fidelity, and known lossy constructs stay in source mode', () => temp(async root => {
  const store = new Store(root), entry = await draft(store);
  assert.match(markdown(entry, true), /draft: false/);
  assert.match(markdown(entry, true), /publicationDate:/);
  assert.match(markdown(entry, true), /publicationDate: "\d{4}-\d{2}-\d{2}"/);
  assert.throws(() => markdown({ ...entry, slug: '../escape' }), /lowercase/);
  assert.throws(() => markdown({ ...entry, body: '' }), /Add your writing/);
  assert.equal(needsSource('## Heading\n\n**text**'), false);
  for (const body of ['<figure>x</figure>', '| a | b |', '# Title', '#### Deep heading', '- [x] task', '[x]: https://example.org']) assert.equal(needsSource(body), true);
}));

test('HTTP protection: loopback host, cross-origin rejection, CSRF and traversal', () => temp(async root => {
  const app = await createApp({ root });
  try {
    assert.equal((await fetch(`${app.origin}/api/session`)).status, 200);
    const badHost = await new Promise((resolve, reject) => {
      const req = request(`${app.origin}/api/session`, { headers: { Host: 'evil.example' } }, response => { response.resume(); resolve(response.statusCode); });
      req.on('error', reject); req.end();
    });
    assert.equal(badHost, 403);
    assert.equal((await fetch(`${app.origin}/api/session`, { headers: { Origin: 'https://evil.example' } })).status, 403);
    assert.equal((await fetch(`${app.origin}/api/entries`, { method: 'POST', body: '{}' })).status, 403);
    const response = await fetch(`${app.origin}/api/entries`, { method: 'POST', headers: { origin: app.origin, 'x-jez-token': app.token, 'content-type': 'application/json' }, body: JSON.stringify({ section: 'writing' }) });
    assert.equal(response.status, 201);
    assert.equal((await fetch(`${app.origin}/api/jobs/../../session.json/check`, { method: 'POST', headers: { origin: app.origin, 'x-jez-token': app.token } })).status, 404);
    assert.equal((await fetch(`${app.origin}/.env.local`)).status, 404);
  } finally { app.server.closeAllConnections(); await new Promise(resolve => app.server.close(resolve)); }
}));

async function repository(root) {
  const remote = join(root, 'remote.git'), seed = join(root, 'seed');
  await command('git', ['init', '--bare', '--initial-branch=main', remote]);
  await command('git', ['clone', remote, seed]);
  await command('git', ['config', 'user.name', 'Test Author'], { cwd: seed });
  await command('git', ['config', 'user.email', 'test@example.invalid'], { cwd: seed });
  await writeFile(join(seed, 'unrelated.txt'), 'Keep this.');
  await command('git', ['add', '.'], { cwd: seed });
  await command('git', ['commit', '-m', 'Seed'], { cwd: seed });
  await command('git', ['push', 'origin', 'main'], { cwd: seed });
  return { remote, seed };
}

test('isolated publication pushes only selected entry; revisions conflict safely; build failure never pushes', () => temp(async root => {
  const { remote, seed } = await repository(root), store = new Store(join(root, 'private'));
  let entry = await draft(store);
  await store.create('experiments');
  await writeFile(join(seed, 'unrelated.txt'), 'Uncommitted work must stay untouched.');
  const publisher = new Publisher(store, { remote, siteRoot: seed, build: async () => {}, monitor: async () => ({ state: 'live', message: 'Simulated deployment succeeded.' }) });
  await assert.rejects(publisher.start(entry, ''), /explicit confirmation/);
  const job = { id: crypto.randomUUID(), entryId: entry.id, revision: entry.revision, title: entry.title, state: 'building', pushed: false };
  await publisher.execute(entry, job);
  assert.equal(job.state, 'live');
  assert.equal(job.pushed, true);
  const files = await command('git', ['--git-dir', remote, 'ls-tree', '-r', '--name-only', 'main']);
  assert.deepEqual(files.split('\n'), ['src/content/writing/test-post.md', 'unrelated.txt']);
  assert.equal(await readFile(join(seed, 'unrelated.txt'), 'utf8'), 'Uncommitted work must stay untouched.');
  entry = await store.get(entry.id);
  assert.ok(entry.source.hash);
  const unchangedSha = await command('git', ['--git-dir', remote, 'rev-parse', 'main']);
  const failing = new Publisher(store, { remote, siteRoot: seed, build: async () => { throw new Error('Build deliberately failed'); } });
  entry = await store.save(entry.id, { ...entry, body: 'New revision' });
  const failed = { id: crypto.randomUUID(), entryId: entry.id, state: 'building', pushed: false };
  await failing.execute(entry, failed);
  assert.equal(failed.state, 'failed');
  assert.equal(await command('git', ['--git-dir', remote, 'rev-parse', 'main']), unchangedSha);
  const checkout = await publisher.checkout();
  try {
    await writeFile(join(checkout, entry.source.path), 'Changed upstream');
    await assert.rejects(publisher.assertUnchanged(entry, checkout), /remote post changed/);
  } finally { await rm(checkout, { recursive: true, force: true }); }
  const saved = await store.get(entry.id);
  await assert.rejects(store.save(saved.id, { ...saved, slug: 'different-url' }), /URLs and destinations are locked/);
}));

test('uncertain push failure is recorded as check-required, not unpublished', () => temp(async root => {
  const { remote, seed } = await repository(root), store = new Store(join(root, 'private')), entry = await draft(store);
  const publisher = new Publisher(store, { remote, siteRoot: seed, build: async () => {}, run: (exe, args, opts) => {
    if (exe === 'git' && args[0] === 'push') throw new Error('Simulated network loss');
    return command(exe, args, opts);
  } });
  const job = { id: crypto.randomUUID(), entryId: entry.id, state: 'building', pushed: false };
  await publisher.execute(entry, job);
  assert.equal(job.state, 'check-required'); assert.ok(job.sha);
  await assert.rejects(publisher.start(entry, 'PUBLISH TO JEZ.BLOG'), /previous publication/);
  await publisher.reconcile(job);
  assert.equal(job.state, 'failed');
}));

test('deployment failure after successful push stays public-but-not-confirmed', () => temp(async root => {
  const { remote, seed } = await repository(root), store = new Store(join(root, 'private')), entry = await draft(store);
  const publisher = new Publisher(store, { remote, siteRoot: seed, build: async () => {}, monitor: async () => { throw new Error('Simulated Vercel failure'); } });
  const job = { id: crypto.randomUUID(), entryId: entry.id, revision: entry.revision, state: 'building', pushed: false };
  await publisher.execute(entry, job);
  assert.equal(job.state, 'deployment-failed'); assert.equal(job.pushed, true);
  assert.equal(await command('git', ['--git-dir', remote, 'rev-parse', 'main']), job.sha);
  assert.match((await store.get(entry.id)).body, /Author text/);
}));

test('restart converts interrupted jobs without automatically republishing', () => temp(async root => {
  const beforeCommit = { id: crypto.randomUUID(), state: 'building', sha: null };
  const duringPush = { id: crypto.randomUUID(), state: 'pushing', sha: 'abc123' };
  for (const job of [beforeCommit, duringPush]) await atomicJson(join(root, 'jobs', `${job.id}.json`), job);
  const app = await createApp({ root, publisherOptions: { run: () => { throw new Error('Must not execute commands on restart'); } } });
  try {
    const jobs = await app.publisher.jobs();
    assert.equal(jobs.find(j => j.id === beforeCommit.id).state, 'failed');
    assert.equal(jobs.find(j => j.id === duringPush.id).state, 'check-required');
  } finally { app.server.closeAllConnections(); await new Promise(done => app.server.close(done)); }
}));

test('gallery upload, reorder, remove, restart, validation and materialization', () => temp(async root => {
  const store = new Store(join(root, 'private'));
  let entry = await store.create('media');
  assert.throws(() => markdown(entry, true), /Upload at least one/);
  entry = (await store.upload(entry.id, 'first.png', png)).entry;
  entry = (await store.upload(entry.id, 'second.png', png)).entry;
  assert.equal(entry.items.length, 2);
  assert.equal(entry.items[0].alt, '');
  const first = entry.items[0].src, second = entry.items[1].src;
  entry = await store.save(entry.id, { ...entry, items: [{ ...entry.items[1], caption: 'Second first' }, entry.items[0]] });
  assert.equal((await new Store(store.root).get(entry.id)).items[0].src, second);
  await assert.rejects(store.save(entry.id, { ...entry, items: [{ ...entry.items[0], src: first.replace('png', 'mp4'), kind: 'video' }] }), /uploaded or published/);
  await assert.rejects(store.save(entry.id, { ...entry, items: [entry.items[0], entry.items[0]] }), /Duplicate/);
  entry = await store.save(entry.id, { ...entry, items: [entry.items[0]] });
  const checkout = join(root, 'site');
  const result = await store.materialize(entry, checkout, true);
  assert.equal(result.changed.length, 2);
  assert.equal(result.changed[1], `public${second}`);
  const data = parseContent(await readFile(join(checkout, result.file), 'utf8')).data;
  assert.equal(data.items[0].caption, 'Second first');
  assert.equal(data.draft, false);
  assert.equal(publicRoute(entry), '#media');
  const imported = await new Store(join(root, 'imported')).import(checkout, result.file);
  assert.deepEqual(imported.items, entry.items);
  assert.equal(imported.createdAt, entry.createdAt);
  assert.doesNotThrow(() => markdown({ ...imported, items: [] }, true));
  // Removing all published tiles is a valid revision, not a forced replacement upload.
  entry.assets[0].bytes = 50 * 1024 * 1024;
  entry.items = [{ src: first, kind: 'image', alt: '', caption: '' }];
  await atomicJson(store.path(entry.id), entry);
  await assert.rejects(store.upload(entry.id, 'overflow.png', png), /exceed 50 MB/);
}));

test('legacy project drafts and source paths survive the rename', () => temp(async root => {
  const store = new Store(join(root, 'private'));
  const entry = await store.create('experiments');
  assert.equal(entry.section, 'projects');
  await atomicJson(store.path(entry.id), { ...entry, section: 'experiments' });
  assert.equal((await store.get(entry.id)).section, 'projects');
  assert.equal((await store.list())[0].section, 'projects');
  const checkout = join(root, 'site'), file = 'src/content/experiments/old.md';
  await mkdir(join(checkout, 'src/content/experiments'), { recursive: true });
  await writeFile(join(checkout, file), '---\ntitle: Legacy\nslug: legacy\ndraft: false\n---\n\nBody');
  const imported = await store.import(checkout, file);
  assert.equal(imported.section, 'projects');
  assert.equal(publicRoute(imported), 'projects/legacy/');
  assert.equal((await store.materialize(imported, checkout, true)).file, file);
}));

test('media publication stops on an old site, then publishes only the selected batch to an isolated remote', () => temp(async root => {
  const { remote, seed } = await repository(root), store = new Store(join(root, 'private'));
  let entry = await store.create('media');
  entry = (await store.upload(entry.id, 'one.png', png)).entry;
  entry = (await store.upload(entry.id, 'two.png', png)).entry;
  const other = await store.create('media'); await store.upload(other.id, 'private.png', png);
  const publisher = new Publisher(store, { remote, siteRoot: seed, build: async () => {}, monitor: async () => ({ state: 'live' }) });
  const job = () => ({ id: crypto.randomUUID(), entryId: entry.id, revision: entry.revision, state: 'building', pushed: false });
  const oldSha = await command('git', ['--git-dir', remote, 'rev-parse', 'main']);
  const blocked = job(); await publisher.execute(entry, blocked);
  assert.equal(blocked.state, 'failed'); assert.match(blocked.message, /Deploy the site update/);
  assert.equal(await command('git', ['--git-dir', remote, 'rev-parse', 'main']), oldSha);
  await atomicJson(join(seed, 'src/config/content-features.json'), { projects: 1, media: 1 });
  await command('git', ['add', '.'], { cwd: seed });
  await command('git', ['commit', '-m', 'Enable gallery'], { cwd: seed });
  await command('git', ['push', 'origin', 'main'], { cwd: seed });
  const published = job(); await publisher.execute(entry, published);
  assert.equal(published.state, 'live');
  const files = await command('git', ['--git-dir', remote, 'ls-tree', '-r', '--name-only', 'main']);
  assert.match(files, new RegExp(`src/content/media/${entry.slug}.md`));
  assert.equal(files.split('\n').filter(f => f.startsWith('public/')).length, 2);
  assert.ok(!files.includes(other.id));
  await publisher.sync();
  const fresh = new Store(join(root, 'fresh'));
  const imported = await fresh.import(join(store.root, 'library'), `src/content/media/${entry.slug}.md`);
  assert.equal(imported.items.length, 2);
  entry = await store.get(entry.id);
  entry = await store.save(entry.id, { ...entry, items: [] });
  const removed = job(); await publisher.execute(entry, removed);
  assert.equal(removed.state, 'live');
  assert.deepEqual(parseContent(removed.raw).data.items, []);
}));