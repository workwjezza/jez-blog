import { glob, type Loader } from 'astro/loaders';

/** Validate all metadata, but never register draft Markdown modules or their assets. */
export function markdownLoader(base: string): Loader {
  const loader = glob({
    pattern: '**/*.md', base, generateId: ({ entry }) => entry, deferRender: true,
  });
  return {
    name: 'publication-safe-markdown',
    async load(context) {
      // Rebuild module registration from current status, including after unpublishing.
      context.store.clear();
      await loader.load({
        ...context,
        store: {
          ...context.store,
          set(entry) {
            if (entry.data.draft !== false || !entry.data.slug) {
              return context.store.set({ id: entry.id, data: entry.data, digest: entry.digest });
            }
            return context.store.set(entry);
          },
        },
      });
    },
  };
}