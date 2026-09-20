import { parse, stringify } from 'yaml';
import { writingSchema, projectSchema, mediaSchema } from '../../src/lib/schemas.ts';
import { fail } from './files.mjs';

export function parseContent(raw) {
  const match = raw.match(/^---\r?\n([\s\S]*?)\r?\n---(?:\r?\n|$)([\s\S]*)$/);
  if (!match) fail('Expected Markdown with YAML frontmatter.');
  return { data: parse(match[1], { maxAliasCount: 0 }), body: match[2].replace(/^\r?\n/, '') };
}
export function metadata(draft, publish = false) {
  const data = { ...draft.extra, title: draft.title, draft: !publish };
  if (draft.section === 'writing' || draft.destination === 'local') data.slug = draft.slug;
  else data.externalUrl = draft.externalUrl;
  if (draft.description?.trim()) data.description = draft.description.trim();
  if (draft.order !== '' && draft.order !== undefined) data.order = Number(draft.order);
  if (draft.publicationDate) data.publicationDate = draft.publicationDate;
  else if (publish) data.publicationDate = new Date().toISOString().slice(0, 10);
  if (draft.section === 'media') {
    delete data.externalUrl;
    data.slug = draft.slug;
    data.createdAt = draft.createdAt;
    data.items = draft.items ?? [];
    if (!data.items.length && !draft.source) fail('Upload at least one file before previewing or publishing.');
  }
  const schema = draft.section === 'media' ? mediaSchema : draft.section === 'writing' ? writingSchema : projectSchema;
  const result = schema.safeParse(data);
  if (!result.success) fail(result.error.issues.map(i => `${i.path.join('.') || 'Entry'}: ${i.message}`).join('\n'));
  return { ...data, ...result.data };
}
export function markdown(draft, publish = false) {
  if (draft.section === 'writing' && !draft.body.trim()) fail('Add your writing before previewing or publishing.');
  if (draft.body.includes('/api/media/') || draft.body.includes('blob:')) fail('A temporary media URL remains in the post. Reinsert that attachment.');
  // Astro's frontmatter reader uses YAML 1.1 date inference: explicitly quote strings.
  return `---\n${stringify(metadata(draft, publish), { defaultStringType: 'QUOTE_DOUBLE', defaultKeyType: 'PLAIN' }).trimEnd()}\n---\n\n${draft.body.trimEnd()}\n`;
}
export function referencesAsset(entry, url) {
  return entry.section === 'media' ? entry.items?.some(item => item.src === url) : entry.body.includes(url);
}
export function publicRoute(entry) {
  if (entry.section === 'media') return '#media';
  if (entry.destination === 'external') return '#projects';
  return `${entry.section === 'experiments' ? 'projects' : entry.section}/${entry.slug}/`;
}
export const knownFields = ['title', 'slug', 'draft', 'externalUrl', 'description', 'order', 'publicationDate', 'items', 'createdAt'];