import { defineCollection } from 'astro:content';
import { markdownLoader } from './lib/markdown-loader';
import { projectSchema, writingSchema, mediaSchema } from './lib/schemas';

// Keep file identities separate from public slugs so duplicates cannot silently overwrite.
const writing = defineCollection({
  loader: markdownLoader('./src/content/writing'),
  schema: writingSchema,
});
const experiments = defineCollection({
  loader: markdownLoader('./src/content/experiments'),
  schema: projectSchema,
});

const projects = defineCollection({
  loader: markdownLoader('./src/content/projects'),
  schema: projectSchema,
});
const media = defineCollection({
  loader: markdownLoader('./src/content/media'),
  schema: mediaSchema,
});

export const collections = { writing, projects, experiments, media };