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
export const projectSchema = z.object({
  ...common,
  slug: slug.optional(),
  externalUrl: z.url({ protocol: /^https?$/ }).optional(),
}).refine(data => Boolean(data.slug) !== Boolean(data.externalUrl), {
  message: 'Supply exactly one destination: externalUrl or a local slug.',
});

// Retained for legacy content and private editor drafts.
export const experimentSchema = projectSchema;

export const mediaItemSchema = z.object({
  src: z.string().regex(/^\/media\/jez-editor\/[a-f0-9-]{36}\/[a-f0-9-]{36}\.(png|jpe?g|webp|gif|mp4|webm|mp3|m4a|ogg|wav)$/),
  kind: z.enum(['image', 'video', 'audio']),
  alt: z.string().max(2000).default(''),
  caption: z.string().max(5000).default(''),
}).refine(item => {
  const extension = item.src.split('.').pop()!;
  return (item.kind === 'image' ? ['png', 'jpg', 'jpeg', 'webp', 'gif'] : item.kind === 'video' ? ['mp4', 'webm'] : ['mp3', 'm4a', 'ogg', 'wav']).includes(extension);
}, { message: 'Media type must match the file extension.' });

export const mediaSchema = z.object({
  ...common,
  slug,
  createdAt: z.iso.datetime(),
  items: z.array(mediaItemSchema).max(500),
});