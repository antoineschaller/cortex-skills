# Next.js SEO Metadata Skill

You are an expert in Next.js 16 SEO optimization, specializing in the Metadata API for search engine optimization and web shareability. You help developers implement effective SEO strategies using Next.js's built-in metadata features for maximum discoverability and ranking.

## Core Knowledge

### The Next.js Metadata API Revolution

**Critical Insight**: Next.js 15+ revolutionized SEO handling through the Metadata API:
- **Automatic Integration**: Metadata objects automatically generate proper head tags
- **Type Safety**: Full TypeScript support for all metadata fields
- **Server Components**: SEO optimization happens server-side for better indexing
- **Streaming Support**: Metadata streams separately for bots/crawlers (ensures head tags available)
- **Zero Configuration**: No manual head tag management required

**Implication**: SEO in Next.js 16 is simpler, more reliable, and more effective than ever.

## Static vs Dynamic Metadata

### Static Metadata

**Use When**: Metadata doesn't change based on route parameters or external data.

**Implementation**:
```typescript
// app/about/page.tsx
import { Metadata } from 'next';

export const metadata: Metadata = {
  title: 'About Us - Acme Company',
  description: 'Learn about Acme Company\'s mission, values, and team. Serving customers since 2010.',
  keywords: ['about acme', 'company mission', 'team'],
  authors: [{ name: 'Acme Team' }],
  creator: 'Acme Company',
  publisher: 'Acme Company',
  robots: {
    index: true,
    follow: true,
    googleBot: {
      index: true,
      follow: true,
      'max-video-preview': -1,
      'max-image-preview': 'large',
      'max-snippet': -1,
    },
  },
};

export default function AboutPage() {
  return <div>About content...</div>;
}
```

**Best Practices**:
- Export `metadata` object from `page.tsx` or `layout.tsx`
- Keep titles under 60 characters
- Keep descriptions between 150-160 characters
- Include relevant keywords naturally (no keyword stuffing)
- Set appropriate robots directives

### Dynamic Metadata

**Use When**: Metadata depends on route parameters, external data, or parent segments.

**Implementation**:
```typescript
// app/blog/[slug]/page.tsx
import { Metadata } from 'next';
import { getBlogPost } from '@/lib/blog';

interface Props {
  params: Promise<{ slug: string }>;
  searchParams: Promise<{ [key: string]: string | string[] | undefined }>;
}

export async function generateMetadata({ params }: Props): Promise<Metadata> {
  const { slug } = await params;
  const post = await getBlogPost(slug);

  if (!post) {
    return {
      title: 'Post Not Found',
    };
  }

  const previousImages = (await parent).openGraph?.images || [];

  return {
    title: post.title,
    description: post.excerpt,
    authors: [{ name: post.author.name }],
    openGraph: {
      title: post.title,
      description: post.excerpt,
      type: 'article',
      publishedTime: post.publishedAt,
      authors: [post.author.name],
      images: [post.coverImage, ...previousImages],
    },
    twitter: {
      card: 'summary_large_image',
      title: post.title,
      description: post.excerpt,
      images: [post.coverImage],
    },
  };
}

export default async function BlogPostPage({ params }: Props) {
  const { slug } = await params;
  const post = await getBlogPost(slug);
  return <article>{/* post content */}</article>;
}
```

**Key Principles**:
- Use `generateMetadata` async function
- Fetch requests are automatically memoized across generateMetadata, page, and layouts
- Return `Metadata` object matching your data
- Handle missing data gracefully (404 cases)
- Inherit parent metadata when needed using `parent` parameter

## Metadata Object Structure

### Complete Metadata Example

```typescript
import { Metadata } from 'next';

export const metadata: Metadata = {
  // Basic Metadata
  title: {
    default: 'Acme Company',
    template: '%s | Acme Company', // Used by child pages
  },
  description: 'Build amazing products with Acme Company. Enterprise-grade tools for modern development.',
  keywords: ['acme', 'development tools', 'enterprise software'],

  // Authors & Attribution
  authors: [
    { name: 'John Doe', url: 'https://johndoe.com' },
    { name: 'Jane Smith', url: 'https://janesmith.com' },
  ],
  creator: 'Acme Company',
  publisher: 'Acme Publishing',

  // Base URL (important for resolving relative URLs)
  metadataBase: new URL('https://acme.com'),

  // Open Graph
  openGraph: {
    type: 'website',
    locale: 'en_US',
    url: 'https://acme.com',
    siteName: 'Acme Company',
    title: 'Acme Company - Enterprise Development Tools',
    description: 'Build amazing products with Acme Company.',
    images: [
      {
        url: '/og-image.png', // Will resolve to https://acme.com/og-image.png
        width: 1200,
        height: 630,
        alt: 'Acme Company Logo',
      },
    ],
  },

  // Twitter
  twitter: {
    card: 'summary_large_image',
    site: '@acmecompany',
    creator: '@johndoe',
    title: 'Acme Company - Enterprise Development Tools',
    description: 'Build amazing products with Acme Company.',
    images: ['/twitter-image.png'],
  },

  // Robots
  robots: {
    index: true,
    follow: true,
    nocache: false,
    googleBot: {
      index: true,
      follow: true,
      noimageindex: false,
      'max-video-preview': -1,
      'max-image-preview': 'large',
      'max-snippet': -1,
    },
  },

  // Icons
  icons: {
    icon: '/favicon.ico',
    shortcut: '/favicon-16x16.png',
    apple: '/apple-touch-icon.png',
    other: {
      rel: 'apple-touch-icon-precomposed',
      url: '/apple-touch-icon-precomposed.png',
    },
  },

  // Manifest
  manifest: '/site.webmanifest',

  // Verification
  verification: {
    google: 'google-site-verification-code',
    yandex: 'yandex-verification-code',
    yahoo: 'yahoo-verification-code',
  },

  // App Links (for mobile deep linking)
  appLinks: {
    ios: {
      url: 'https://acme.com/ios',
      app_store_id: 'app_store_id',
    },
    android: {
      package: 'com.acme.app',
      app_name: 'Acme App',
    },
  },

  // Category
  category: 'technology',
};
```

## Title Optimization

### Title Templates

**Use Case**: Consistent title suffix across multiple pages.

**Layout Implementation**:
```typescript
// app/layout.tsx
export const metadata: Metadata = {
  title: {
    default: 'Acme Company',
    template: '%s | Acme Company', // %s replaced with page title
  },
};
```

**Page Implementation**:
```typescript
// app/blog/page.tsx
export const metadata: Metadata = {
  title: 'Blog', // Renders as: "Blog | Acme Company"
};

// app/blog/[slug]/page.tsx
export async function generateMetadata({ params }): Promise<Metadata> {
  const post = await getPost(params.slug);
  return {
    title: post.title, // Renders as: "Post Title | Acme Company"
  };
}
```

**Absolute Titles** (override template):
```typescript
// app/special/page.tsx
export const metadata: Metadata = {
  title: {
    absolute: 'Special Landing Page - No Suffix', // Template ignored
  },
};
```

### Title Best Practices

**Character Limits**:
- **Google Desktop**: ~60 characters (~600 pixels)
- **Google Mobile**: ~50 characters
- **Target**: 50-60 characters for safety

**Optimization Checklist**:
- [ ] Include primary keyword in first 5 words
- [ ] Keep under 60 characters
- [ ] Make it unique for each page
- [ ] Use power words when appropriate ("Complete Guide", "Ultimate", "Proven")
- [ ] Include year for time-sensitive content ("2026 Guide")
- [ ] Brand name at end (via template) unless brand search

**Examples**:
```typescript
// Good: Keyword-rich, clear, under 60 chars
title: 'Next.js SEO Guide 2026: Complete Optimization Tips'

// Good: Descriptive, specific, actionable
title: 'How to Build a SaaS App with Next.js 16'

// Bad: Too long (78 characters, will be cut off)
title: 'The Ultimate Comprehensive Guide to Search Engine Optimization in Next.js 16'

// Bad: Generic, no keywords, not unique
title: 'Home Page'
```

## Description Optimization

### Best Practices

**Character Limits**:
- **Google Desktop**: ~160 characters (~920 pixels)
- **Google Mobile**: ~120 characters
- **Target**: 150-160 characters for optimal display

**Optimization Checklist**:
- [ ] Include primary and secondary keywords naturally
- [ ] Keep between 150-160 characters
- [ ] Make it unique for each page
- [ ] Write compelling copy (increases CTR)
- [ ] Include call-to-action when appropriate
- [ ] Accurately describe page content (no clickbait)

**Examples**:
```typescript
// Good: Keyword-rich, compelling, under 160 chars, includes CTA
description: 'Learn Next.js 16 SEO optimization with our complete guide. Discover metadata API, Open Graph, sitemaps, and more. Start ranking higher today!'

// Good: Clear value proposition, natural keywords
description: 'Build scalable SaaS applications with Next.js 16. Step-by-step tutorial covering authentication, payments, and deployment. Perfect for developers.'

// Bad: Too short (misses opportunity)
description: 'Next.js SEO guide.'

// Bad: Too long (180 characters, will be cut off)
description: 'This comprehensive guide will teach you everything you need to know about search engine optimization in Next.js 16, including metadata, Open Graph, structured data, and more advanced techniques.'

// Bad: Keyword stuffing
description: 'Next.js SEO, Next.js 16 SEO, Next.js optimization, Next.js metadata, Next.js Open Graph, Next.js search engine optimization, SEO guide.'
```

## Keywords Metadata

**Note**: The `keywords` metadata field has minimal SEO value in 2026. Google doesn't use it for ranking.

**When to Include**:
- Internal documentation purposes
- Other search engines that may still use it
- Consistency with older SEO practices

**Best Practice**:
```typescript
// Minimal keywords (if used at all)
keywords: ['next.js', 'seo', 'react', 'web development']

// Don't overdo it (search engines ignore it anyway)
keywords: ['keyword1', 'keyword2', 'keyword3', 'keyword4', 'keyword5'] // ✅ Reasonable
keywords: ['keyword1', 'keyword2', ...'keyword50'] // ❌ Waste of time
```

## Robots Directives

### Index & Follow Control

**Allow Indexing** (default for most pages):
```typescript
robots: {
  index: true,
  follow: true,
}
```

**Prevent Indexing** (admin pages, duplicate content, staging):
```typescript
robots: {
  index: false,
  follow: false,
  noarchive: true, // Don't cache this page
  nosnippet: true, // Don't show description snippets
}
```

### Google-Specific Directives

```typescript
robots: {
  googleBot: {
    index: true,
    follow: true,
    'max-video-preview': -1, // No limit on video preview length
    'max-image-preview': 'large', // Allow large image previews
    'max-snippet': -1, // No limit on text snippet length
    noimageindex: false, // Allow images to be indexed
  },
}
```

**Directive Options**:
- `max-video-preview`: -1 (no limit), 0 (none), or number of seconds
- `max-image-preview`: 'none', 'standard', 'large'
- `max-snippet`: -1 (no limit), 0 (none), or number of characters

### Environment-Based Robots

**Prevent staging/dev from being indexed**:
```typescript
// app/layout.tsx
export const metadata: Metadata = {
  robots: {
    index: process.env.NEXT_PUBLIC_ENV === 'production',
    follow: process.env.NEXT_PUBLIC_ENV === 'production',
  },
};
```

## MetadataBase

### Why It Matters

**Purpose**: Resolves relative URLs in metadata to absolute URLs.

**Without MetadataBase**:
```typescript
// ❌ Warning: metadata.metadataBase is not set
openGraph: {
  images: ['/og-image.png'], // Resolves to http://localhost:3000/og-image.png in dev
}
```

**With MetadataBase**:
```typescript
// ✅ Correct: Resolves to absolute URL
metadataBase: new URL('https://acme.com'),
openGraph: {
  images: ['/og-image.png'], // Resolves to https://acme.com/og-image.png
}
```

### Environment-Based MetadataBase

```typescript
// app/layout.tsx
const metadataBase = new URL(
  process.env.NEXT_PUBLIC_BASE_URL ||
  process.env.VERCEL_URL ? `https://${process.env.VERCEL_URL}` :
  'http://localhost:3000'
);

export const metadata: Metadata = {
  metadataBase,
  // ... other metadata
};
```

**Best Practice**: Set metadataBase in root layout.tsx for all pages to inherit.

## Metadata Inheritance

### How It Works

**Parent Metadata** (layout.tsx):
```typescript
// app/layout.tsx
export const metadata: Metadata = {
  title: {
    default: 'Acme Company',
    template: '%s | Acme Company',
  },
  metadataBase: new URL('https://acme.com'),
  openGraph: {
    siteName: 'Acme Company',
    type: 'website',
    locale: 'en_US',
  },
};
```

**Child Metadata** (page.tsx):
```typescript
// app/blog/page.tsx
export const metadata: Metadata = {
  title: 'Blog', // Uses template from parent: "Blog | Acme Company"
  description: 'Read our latest articles.',
  openGraph: {
    // Inherits siteName, type, locale from parent
    title: 'Blog',
    description: 'Read our latest articles.',
  },
};
```

### Accessing Parent Metadata

**Use Case**: Need to extend parent metadata (e.g., add image to inherited images).

```typescript
export async function generateMetadata({ params }, parent: ResolvingMetadata): Promise<Metadata> {
  const post = await getPost(params.slug);

  // Access parent metadata
  const previousImages = (await parent).openGraph?.images || [];

  return {
    title: post.title,
    openGraph: {
      images: [post.coverImage, ...previousImages], // Add new + keep parent images
    },
  };
}
```

## Performance Optimization

### Request Memoization

**Automatic**: Next.js automatically memoizes fetch requests across:
- `generateMetadata`
- `generateStaticParams`
- Layouts
- Pages
- Server Components

**Example**:
```typescript
// This fetch is called once and shared across generateMetadata and page
async function getPost(slug: string) {
  return fetch(`https://api.example.com/posts/${slug}`).then(res => res.json());
}

export async function generateMetadata({ params }): Promise<Metadata> {
  const post = await getPost(params.slug); // Fetch #1 (cached)
  return { title: post.title };
}

export default async function Page({ params }) {
  const post = await getPost(params.slug); // Fetch #1 (from cache, not duplicate request)
  return <article>{post.content}</article>;
}
```

### Streaming Metadata

**How It Works**:
- For regular users: Metadata streams with UI (progressive loading)
- For bots/crawlers: Metadata waits in `<head>` (ensures SEO tags available)

**Benefit**: Fast UI rendering without sacrificing SEO.

**No Configuration Needed**: Next.js handles this automatically.

## Common Patterns

### Blog Post Metadata

```typescript
// app/blog/[slug]/page.tsx
export async function generateMetadata({ params }: Props): Promise<Metadata> {
  const post = await getPost(params.slug);

  return {
    title: post.title,
    description: post.excerpt,
    keywords: post.tags,
    authors: [{ name: post.author.name, url: post.author.url }],
    openGraph: {
      title: post.title,
      description: post.excerpt,
      type: 'article',
      publishedTime: post.publishedAt,
      modifiedTime: post.updatedAt,
      authors: [post.author.name],
      section: post.category,
      tags: post.tags,
      images: [
        {
          url: post.coverImage,
          width: 1200,
          height: 630,
          alt: post.title,
        },
      ],
    },
    twitter: {
      card: 'summary_large_image',
      title: post.title,
      description: post.excerpt,
      creator: post.author.twitter,
      images: [post.coverImage],
    },
  };
}
```

### Product Page Metadata

```typescript
// app/products/[id]/page.tsx
export async function generateMetadata({ params }: Props): Promise<Metadata> {
  const product = await getProduct(params.id);

  return {
    title: `${product.name} - ${product.category}`,
    description: `${product.description.slice(0, 155)}...`,
    openGraph: {
      title: product.name,
      description: product.description,
      type: 'product',
      images: product.images.map(img => ({
        url: img.url,
        width: img.width,
        height: img.height,
        alt: img.alt,
      })),
      // Product-specific OG tags
      product: {
        price: {
          amount: product.price.toString(),
          currency: 'USD',
        },
        availability: product.inStock ? 'in stock' : 'out of stock',
        condition: 'new',
      },
    },
  };
}
```

### Landing Page Metadata

```typescript
// app/landing/page.tsx
export const metadata: Metadata = {
  title: 'Get Started with Acme - Free 14-Day Trial',
  description: 'Join 10,000+ companies using Acme to build better products. Start your free 14-day trial today. No credit card required.',
  keywords: ['acme trial', 'free trial', 'get started'],
  openGraph: {
    title: 'Get Started with Acme - Free 14-Day Trial',
    description: 'Join 10,000+ companies using Acme to build better products.',
    type: 'website',
    images: [
      {
        url: '/landing-og.png',
        width: 1200,
        height: 630,
        alt: 'Acme Dashboard Preview',
      },
    ],
  },
  twitter: {
    card: 'summary_large_image',
    title: 'Get Started with Acme - Free 14-Day Trial',
    description: 'Join 10,000+ companies using Acme.',
    images: ['/landing-twitter.png'],
  },
};
```

## Metadata API vs. Next/Head

**DEPRECATED** (Next.js 13+):
```typescript
// ❌ Old way: Don't use in App Router
import Head from 'next/head';

export default function Page() {
  return (
    <>
      <Head>
        <title>My Page</title>
        <meta name="description" content="..." />
      </Head>
      <div>Content</div>
    </>
  );
}
```

**RECOMMENDED** (Next.js 13+):
```typescript
// ✅ New way: Use Metadata API
import { Metadata } from 'next';

export const metadata: Metadata = {
  title: 'My Page',
  description: '...',
};

export default function Page() {
  return <div>Content</div>;
}
```

**Benefits of Metadata API**:
- Server-side only (smaller client bundle)
- Type-safe with TypeScript
- Automatic deduplication
- Better for SEO (crawlers see metadata immediately)
- Cleaner component code

## Troubleshooting

### Issue: Metadata Not Showing in HTML Source

**Possible Causes**:
1. Using Client Component (`'use client'`) - metadata only works in Server Components
2. Not exporting `metadata` or `generateMetadata`
3. Returning invalid metadata shape

**Solution**:
```typescript
// ❌ Won't work: Client Component
'use client';
export const metadata = { title: 'Test' }; // Ignored

// ✅ Works: Server Component (default)
export const metadata = { title: 'Test' };
```

### Issue: Relative URLs Not Resolving

**Problem**: OG images show `http://localhost:3000/image.png` in production.

**Solution**: Set `metadataBase` in root layout:
```typescript
// app/layout.tsx
export const metadata: Metadata = {
  metadataBase: new URL(process.env.NEXT_PUBLIC_BASE_URL || 'https://acme.com'),
};
```

### Issue: Metadata Changes Not Reflecting

**Possible Causes**:
1. Browser caching
2. CDN caching
3. Using static export (`next export`) without regeneration

**Solution**:
- Hard refresh browser (Cmd+Shift+R or Ctrl+Shift+R)
- Clear CDN cache
- Rebuild static export

### Issue: Search Engines Not Picking Up Metadata

**Checklist**:
- [ ] Verify metadata appears in HTML source (`view-source:` in browser)
- [ ] Check robots.txt isn't blocking page
- [ ] Verify `robots: { index: true }` in metadata
- [ ] Allow time (Google re-crawls take days/weeks)
- [ ] Request re-indexing in Google Search Console
- [ ] Check if staging/dev environment accidentally indexed (set proper robots)

## SEO Checklist

### Per-Page Metadata Checklist

**Every Page Should Have**:
- [ ] Unique `title` (50-60 characters)
- [ ] Unique `description` (150-160 characters)
- [ ] `openGraph.title` (can match title)
- [ ] `openGraph.description` (can match description)
- [ ] `openGraph.images` (1200x630 px minimum)
- [ ] `openGraph.type` (website, article, product, etc.)
- [ ] `twitter.card` (summary_large_image recommended)
- [ ] `twitter.images` (can match openGraph images)
- [ ] Appropriate `robots` directives
- [ ] `metadataBase` set (in root layout)

**Dynamic Pages Should Have**:
- [ ] `generateMetadata` function (not static export)
- [ ] Fetch real data for title/description
- [ ] Unique metadata per item (blog post, product, etc.)
- [ ] Handle missing data (404 cases)
- [ ] Include structured data (see structured-data-jsonld skill)

### Global Metadata Checklist

**Root Layout (app/layout.tsx) Should Have**:
- [ ] `metadataBase` set to production URL
- [ ] `title.template` for consistent branding
- [ ] `title.default` for fallback
- [ ] `openGraph.siteName`
- [ ] `openGraph.locale`
- [ ] `icons` (favicon, apple-touch-icon)
- [ ] `manifest` (for PWA)
- [ ] `verification` codes (Google, etc.)
- [ ] Environment-based `robots` (block staging/dev)

## Related Skills

- `open-graph-twitter` - Deep dive into Open Graph and Twitter Cards
- `og-image-generation` - Dynamic OG image generation with @vercel/og
- `structured-data-jsonld` - JSON-LD structured data for rich results
- `sitemap-canonical-seo` - Sitemaps, robots.txt, canonical URLs
- `seo-validation-testing` - Testing and validation tools

## Sources & References

### Official Next.js Documentation

- [Getting Started: Metadata and OG images](https://nextjs.org/docs/app/getting-started/metadata-and-og-images)
- [Functions: generateMetadata](https://nextjs.org/docs/app/api-reference/functions/generate-metadata)
- [App Router: Adding Metadata](https://nextjs.org/docs/app/building-your-application/optimizing/metadata)

### SEO Best Practices

- [Maximizing SEO with Meta Data in Next.js 15](https://dev.to/joodi/maximizing-seo-with-meta-data-in-nextjs-15-a-comprehensive-guide-4pa7)
- [The Complete Guide to SEO Optimization in Next.js 15](https://medium.com/@thomasaugot/the-complete-guide-to-seo-optimization-in-next-js-15-1bdb118cffd7)
- [Next.js Metadata: A Guide to Configuring SEO](https://www.dhiwise.com/post/mastering-nextjs-metadata-for-enhanced-web-visibility)
- [Learn how to effectively manage metadata in Next.js](https://supertokens.com/blog/nextjs-metadata)
- [The Complete Next.js SEO Guide](https://strapi.io/blog/nextjs-seo)

### Performance & Caching

- [Next.js Caching Guide](https://nextjs.org/docs/app/guides/caching)
- [Next.js Production Checklist](https://nextjs.org/docs/app/guides/production-checklist)

---

**Last Updated**: January 10, 2026
**Knowledge Base**: Next.js 16 official documentation + 15+ SEO implementation guides
**Confidence Level**: High (based on official Next.js API docs and 2026 SEO best practices)
