import { defineCollection, z } from 'astro:content';

const blogCollection = defineCollection({
  type: 'content',
  schema: z.object({
    title: z.string(),
    description: z.string(),
    pubDate: z.coerce.date(),
    author: z.string(),
    category: z.enum(['abap-snippets', 'vim-enhancements', 'workflow', 'fi-mm', 'troubleshooting', 'performance', 'best-practices']),
    tags: z.array(z.string()).optional(),
    status: z.enum(['draft', 'published']).default('draft'),
    featured: z.boolean().default(false),
  }),
});

const authorCollection = defineCollection({
  type: 'content',
  schema: z.object({
    name: z.string(),
    role: z.string(),
    bio: z.string(),
    avatar: z.string().optional(),
    expertise: z.array(z.string()).optional(),
    social: z.object({
      linkedin: z.string().optional(),
      twitter: z.string().optional(),
    }).optional(),
  }),
});

export const collections = {
  blog: blogCollection,
  authors: authorCollection,
};
