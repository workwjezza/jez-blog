type Entry = {
  id: string;
  data: { draft?: boolean; slug?: string; order?: number; publicationDate?: string };
};

function compareText(a: string, b: string) {
  return a < b ? -1 : a > b ? 1 : 0;
}

export function compareEntries(a: Entry, b: Entry): number {
  const aOrder = a.data.order ?? Infinity;
  const bOrder = b.data.order ?? Infinity;
  if (aOrder !== bOrder) return aOrder < bOrder ? -1 : 1;
  const dateOrder = compareText(b.data.publicationDate ?? '', a.data.publicationDate ?? '');
  return dateOrder || compareText(a.data.slug ?? a.id, b.data.slug ?? b.id) || compareText(a.id, b.id);
}

export function publicEntries<T extends Entry>(entries: T[]): T[] {
  const slugs = new Set<string>();
  for (const entry of entries) {
    if (!entry.data.slug) continue;
    if (slugs.has(entry.data.slug)) throw new Error(`Conflicting slug: ${entry.data.slug}`);
    slugs.add(entry.data.slug);
  }
  // Fail closed: only an explicit false may enter public output.
  return entries.filter(entry => entry.data.draft === false).sort(compareEntries);
}