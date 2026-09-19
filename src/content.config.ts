import { defineCollection } from 'astro:content';
import { markdownLoader } from './lib/markdown-loader';
import { experimentSchema, writingSchema } from './lib/schemas';

// Keep file identities separate from public slugs so duplicates cannot silently overwrite.
const writing = defineCollection({
  loader: markdownLoader('./src/content/writing'),
  schema: writingSchema,
});
const experiments = defineCollection({
  loader: markdownLoader('./src/content/experiments'),
  schema: experimentSchema,
});

export const collections = { writing, experiments };