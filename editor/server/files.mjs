import { mkdir, readFile, rename, writeFile, readdir, realpath } from 'node:fs/promises';
import { dirname, join, resolve, sep } from 'node:path';
import { createHash, randomUUID } from 'node:crypto';

export const hash = value => createHash('sha256').update(value).digest('hex');
export function fail(message, status = 400) { throw Object.assign(new Error(message), { status }); }
export function validId(id) {
  if (!/^[a-f0-9-]{36}$/.test(id)) fail('Invalid entry ID.');
  return id;
}
export async function atomicJson(path, data) {
  await mkdir(dirname(path), { recursive: true, mode: 0o700 });
  const temp = `${path}.${randomUUID()}.tmp`;
  await writeFile(temp, JSON.stringify(data, null, 2), { mode: 0o600 });
  await rename(temp, path);
}
export async function json(path, fallback) {
  try { return JSON.parse(await readFile(path, 'utf8')); }
  catch (error) { if (error.code === 'ENOENT' && fallback !== undefined) return fallback; throw error; }
}
export async function walk(root) {
  const entries = await readdir(root, { withFileTypes: true }).catch(e => { if (e.code === 'ENOENT') return []; throw e; });
  return (await Promise.all(entries.map(e => e.isDirectory() ? walk(join(root, e.name)) : e.isFile() ? [join(root, e.name)] : []))).flat();
}
export async function inside(root, relative) {
  const base = await realpath(root);
  const path = await realpath(resolve(root, relative));
  if (!path.startsWith(base + sep)) fail('Path is outside the allowed directory.', 403);
  return path;
}