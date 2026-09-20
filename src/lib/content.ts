import { getCollection } from 'astro:content';
import { publicEntries } from './content-policy';

// All public consumers, including any future feed/sitemap, must use these functions.
export async function getPublicWriting() {
  return publicEntries(await getCollection('writing'));
}

export async function getPublicProjects() {
  // Existing source files need not move; duplicate slugs across both names still fail.
  return publicEntries([
    ...await getCollection('projects'),
    ...await getCollection('experiments'),
  ]);
}

export async function getPublicMedia() {
  return publicEntries(await getCollection('media')).sort((a, b) => {
    const order = (a.data.order ?? Infinity) - (b.data.order ?? Infinity);
    return (Number.isNaN(order) ? 0 : order) || (b.data.publicationDate ?? '').localeCompare(a.data.publicationDate ?? '') || b.data.createdAt.localeCompare(a.data.createdAt) || a.id.localeCompare(b.id);
  });
}