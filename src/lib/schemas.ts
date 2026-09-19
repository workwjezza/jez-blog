import { z } from 'astro/zod';

const slug = z.string().regex(/^[a-z0-9]+(?:-[a-z0-9]+)*$/, 'Use lowercase words separated by hyphens.');
const publicationDate = z.string().regex(/^\d{4}-\d{2}-\d{2}$/).refine(value => {
  const date = new Date(`${value}T00:00:00Z`);
  return !Number.isNaN(date.valueOf()) && date.toISOString().slice(0, 10) === value;
}, 'Use a real calendar date in YYYY-MM-DD format.');
const common = {
  title: z.string().trim().min(1),
  draft: z.boolean().default(true),
  publicationDate: publicationDate.optional(),
  description: z.string().trim().min(1).optional(),
  order: z.number().int().optional(),
};

export const writingSchema = z.object({ ...common, slug });
export const experimentSchema = z.object({
  ...common,
  slug: slug.optional(),
  externalUrl: z.url({ protocol: /^https?$/ }).optional(),
}).refine(data => Boolean(data.slug) !== Boolean(data.externalUrl), {
  message: 'Supply exactly one destination: externalUrl or a local slug.',
});