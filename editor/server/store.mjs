import { randomUUID } from 'node:crypto';
import { mkdir, readFile, writeFile, copyFile } from 'node:fs/promises';
import { join, basename, relative, extname } from 'node:path';
import { atomicJson, json, validId, fail, hash, walk, inside } from './files.mjs';
import { parseContent, knownFields, referencesAsset } from './content.mjs';
import { mediaItemSchema } from '../../src/lib/schemas.ts';

const allowed = new Set(['section', 'title', 'slug', 'description', 'publicationDate', 'order', 'body', 'destination', 'externalUrl', 'mode', 'document', 'items']);
const normalize = entry => ({ ...entry, section: entry.section === 'experiments' ? 'projects' : entry.section });
export const mediaTypes = { '.png': 'image/png', '.jpg': 'image/jpeg', '.jpeg': 'image/jpeg', '.webp': 'image/webp', '.gif': 'image/gif', '.mp4': 'video/mp4', '.webm': 'video/webm', '.mp3': 'audio/mpeg', '.m4a': 'audio/mp4', '.ogg': 'audio/ogg', '.wav': 'audio/wav' };
export function checkMedia(name, bytes) {
  const ext = extname(name).toLowerCase(), mime = mediaTypes[ext];
  if (!mime) fail('Supported files: PNG, JPEG, WebP, GIF, MP4, WebM, MP3, M4A, OGG, WAV. Convert HEIC/SVG first.');
  const max = mime.startsWith('image/') ? 10 * 1024 * 1024 : 25 * 1024 * 1024;
  if (!bytes.length || bytes.length > max) fail(`File must be between 1 byte and ${max / 1024 / 1024} MB.`, 413);
  const hex = bytes.subarray(0, 16).toString('hex'), text = bytes.subarray(0, 16).toString('latin1');
  const signatures = {
    '.png': hex.startsWith('89504e470d0a1a0a'), '.jpg': hex.startsWith('ffd8ff'), '.jpeg': hex.startsWith('ffd8ff'),
    '.webp': text.startsWith('RIFF') && text.slice(8, 12) === 'WEBP', '.gif': /^GIF8[79]a/.test(text),
    '.mp4': text.slice(4, 8) === 'ftyp', '.m4a': text.slice(4, 8) === 'ftyp', '.webm': hex.startsWith('1a45dfa3'),
    '.mp3': text.startsWith('ID3') || (bytes[0] === 255 && (bytes[1] & 224) === 224), '.ogg': text.startsWith('OggS'),
    '.wav': text.startsWith('RIFF') && text.slice(8, 12) === 'WAVE',
  };
  if (!signatures[ext]) fail('File contents do not match the selected media type.');
  return { ext, mime };
}

export class Store {
  constructor(root) { this.root = root; }
  path(id) { return join(this.root, 'drafts', validId(id), 'entry.json'); }
  async get(id) { return normalize(await json(this.path(id))); }
  async list() {
    return Promise.all((await walk(join(this.root, 'drafts'))).filter(f => f.endsWith('/entry.json')).map(async f => normalize(await json(f))));
  }
  async create(section = 'writing') {
    if (section === 'experiments') section = 'projects';
    if (!['writing', 'projects', 'media'].includes(section)) fail('Unknown section.');
    const now = new Date().toISOString();
    const entry = { id: randomUUID(), section, title: '', slug: '', body: '', description: '', publicationDate: '', order: '', destination: 'local', externalUrl: '', mode: 'visual', document: null, revision: 0, createdAt: now, updatedAt: now, assets: [], extra: {}, source: null };
    if (section === 'media') Object.assign(entry, { title: `Media · ${now.slice(0, 10)}`, slug: entry.id, items: [] });
    await atomicJson(this.path(entry.id), entry);
    return entry;
  }
  async save(id, input) {
    const entry = await this.get(id);
    if (entry.revision !== input.revision) fail('This draft changed in another tab. Reload it before saving; your current text has not been overwritten.', 409);
    if (JSON.stringify(input).length > 2_000_000) fail('This entry is too large.', 413);
    const next = { ...entry };
    for (const key of allowed) if (Object.hasOwn(input, key)) next[key] = input[key];
    for (const key of ['title', 'slug', 'body', 'description', 'publicationDate', 'externalUrl']) if (typeof next[key] !== 'string') fail(`Invalid ${key}.`);
    if (next.section === 'experiments') next.section = 'projects';
    if (!['writing', 'projects', 'media'].includes(next.section) || !['local', 'external'].includes(next.destination) || !['visual', 'source'].includes(next.mode)) fail('Invalid editor settings.');
    if (next.section !== entry.section) fail('Create a new entry to change sections.');
    if (next.section === 'media') {
      if (next.destination !== 'local') fail('Media belongs to the homepage gallery.');
      const parsed = mediaItemSchema.array().max(500).safeParse(next.items);
      if (!parsed.success) fail('Invalid gallery items.');
      const available = new Set([...entry.assets.map(a => a.url), ...(entry.source ? parseContent(entry.source.raw).data.items ?? [] : []).map(item => item.src)]);
      if (parsed.data.some(item => !available.has(item.src))) fail('Gallery items must reference this entry’s uploaded or published media.');
      if (new Set(parsed.data.map(item => item.src)).size !== parsed.data.length) fail('Duplicate gallery item.');
      next.items = parsed.data;
      next.body = ''; next.document = null;
    }
    if (entry.source && (next.section !== entry.section || next.slug !== entry.slug || next.destination !== entry.destination)) fail('Published entry URLs and destinations are locked. Use your coding agent for a deliberate URL migration.');
    await atomicJson(join(this.root, 'drafts', id, 'previous.json'), entry);
    next.revision++; next.updatedAt = new Date().toISOString();
    await atomicJson(this.path(id), next);
    return next;
  }
  async upload(id, name, bytes) {
    const entry = await this.get(id), type = checkMedia(name, bytes);
    if (entry.section === 'media') {
      if (entry.items.length >= 500) fail('Start a new batch after 500 items.');
      const total = entry.assets.filter(a => referencesAsset(entry, a.url)).reduce((sum, a) => sum + a.bytes, 0);
      if (total + bytes.length > 50 * 1024 * 1024) fail('This batch would exceed 50 MB. Publish it, then start a new Media batch.');
    }
    const file = `${randomUUID()}${type.ext}`;
    const directory = join(this.root, 'drafts', id, 'media');
    await mkdir(directory, { recursive: true, mode: 0o700 });
    await writeFile(join(directory, file), bytes, { mode: 0o600 });
    const asset = { file, name: basename(name), mime: type.mime, bytes: bytes.length, url: `/media/jez-editor/${id}/${file}` };
    if (entry.section === 'media') entry.items.push({ src: asset.url, kind: type.mime.split('/')[0], alt: '', caption: '' });
    entry.assets.push(asset); entry.revision++; entry.updatedAt = new Date().toISOString();
    await atomicJson(this.path(id), entry);
    return { entry, asset };
  }
  async import(checkout, file) {
    if (!/^src\/content\/(writing|projects|experiments|media)\/[a-zA-Z0-9_./-]+\.md$/.test(file) || file.includes('..')) fail('Invalid content path.');
    const path = await inside(checkout, file), raw = await readFile(path, 'utf8');
    const { data, body } = parseContent(raw);
    const existing = (await this.list()).find(e => e.source?.path === file);
    if (existing) return existing;
    const entry = await this.create(file.split('/')[2]);
    Object.assign(entry, {
      title: data.title, slug: data.slug ?? '', body, description: data.description ?? '', publicationDate: data.publicationDate ?? '',
      order: data.order ?? '', externalUrl: data.externalUrl ?? '', destination: data.externalUrl ? 'external' : 'local', mode: 'source',
      extra: Object.fromEntries(Object.entries(data).filter(([k]) => !knownFields.includes(k))),
      source: { path: file, hash: hash(raw), raw },
    });
    if (entry.section === 'media') Object.assign(entry, { items: data.items, createdAt: data.createdAt, mode: 'visual' });
    await atomicJson(this.path(entry.id), entry);
    return entry;
  }
  async materialize(entry, checkout, publish = false) {
    const { markdown } = await import('./content.mjs');
    const file = entry.source?.path ?? `src/content/${entry.section}/${entry.slug || entry.id}.md`;
    const path = join(checkout, file);
    await mkdir(join(path, '..'), { recursive: true });
    await writeFile(path, markdown(entry, publish));
    const changed = [file];
    let total = 0;
    for (const asset of entry.assets) {
      if (!referencesAsset(entry, asset.url)) continue;
      total += asset.bytes;
      if (total > 50 * 1024 * 1024) fail('Attachments total more than 50 MB. Use external hosting for larger media.');
      const target = join(checkout, 'public', asset.url);
      await mkdir(join(target, '..'), { recursive: true });
      await copyFile(join(this.root, 'drafts', entry.id, 'media', asset.file), target);
      changed.push(relative(checkout, target));
    }
    return { file, changed };
  }
}