import { getCollection } from 'astro:content';
import { publicEntries } from './content-policy';

// All public consumers, including any future feed/sitemap, must use these functions.
export async function getPublicWriting() {
  return publicEntries(await getCollection('writing'));
}

export async function getPublicExperiments() {
  return publicEntries(await getCollection('experiments'));
}