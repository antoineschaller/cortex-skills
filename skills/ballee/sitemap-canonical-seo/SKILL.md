# Sitemap, Canonical & Robots SEO Skill

You are an expert in implementing sitemaps, canonical URLs, and robots.txt for Next.js 16 applications. You help developers ensure proper indexing, prevent duplicate content issues, and implement multilingual SEO for maximum search engine visibility and ranking.

## Core Knowledge

### The SEO Discovery Trinity

**Three Critical Components**:
1. **Sitemap.xml**: Tells search engines what pages exist
2. **Robots.txt**: Tells search engines what they can crawl
3. **Canonical URLs**: Tells search engines which version is authoritative

**Critical Insight**: Without these:
- Search engines may miss important pages (no sitemap)
- Search engines may crawl wrong pages (no robots.txt)
- Search engines may split ranking signals across duplicates (no canonicals)

**Impact**: Proper implementation can improve:
- **Indexing speed** by 50-70%
- **Crawl efficiency** (no wasted crawl budget)
- **Ranking signals** (consolidated, not split)
- **International SEO** (proper hreflang signals)

## Sitemap.xml

### Basic Sitemap Implementation

**File**: `app/sitemap.ts`

```typescript
// app/sitemap.ts
import { MetadataRoute } from 'next';

export default function sitemap(): MetadataRoute.Sitemap {
  return [
    {
      url: 'https://acme.com',
      lastModified: new Date(),
      changeFrequency: 'yearly',
      priority: 1,
    },
    {
      url: 'https://acme.com/about',
      lastModified: new Date(),
      changeFrequency: 'monthly',
      priority: 0.8,
    },
    {
      url: 'https://acme.com/blog',
      lastModified: new Date(),
      changeFrequency: 'weekly',
      priority: 0.5,
    },
  ];
}
```

**Generated Output** (`/sitemap.xml`):
```xml
<?xml version="1.0" encoding="UTF-8"?>
<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
  <url>
    <loc>https://acme.com</loc>
    <lastmod>2026-01-10T00:00:00.000Z</lastmod>
    <changefreq>yearly</changefreq>
    <priority>1</priority>
  </url>
  <url>
    <loc>https://acme.com/about</loc>
    <lastmod>2026-01-10T00:00:00.000Z</lastmod>
    <changefreq>monthly</changefreq>
    <priority>0.8</priority>
  </url>
  <url>
    <loc>https://acme.com/blog</loc>
    <lastmod>2026-01-10T00:00:00.000Z</lastmod>
    <changefreq>weekly</changefreq>
    <priority>0.5</priority>
  </url>
</urlset>
```

### Dynamic Sitemap (Recommended)

**Fetch from Database/CMS**:

```typescript
// app/sitemap.ts
import { MetadataRoute } from 'next';
import { getBlogPosts, getProducts } from '@/lib/data';

export default async function sitemap(): Promise<MetadataRoute.Sitemap> {
  const baseUrl = process.env.NEXT_PUBLIC_BASE_URL || 'https://acme.com';

  // Static pages
  const staticPages: MetadataRoute.Sitemap = [
    {
      url: baseUrl,
      lastModified: new Date(),
      changeFrequency: 'monthly',
      priority: 1,
    },
    {
      url: `${baseUrl}/about`,
      lastModified: new Date(),
      changeFrequency: 'yearly',
      priority: 0.8,
    },
  ];

  // Dynamic blog posts
  const posts = await getBlogPosts();
  const blogPages: MetadataRoute.Sitemap = posts.map((post) => ({
    url: `${baseUrl}/blog/${post.slug}`,
    lastModified: new Date(post.updatedAt),
    changeFrequency: 'monthly',
    priority: 0.6,
  }));

  // Dynamic products
  const products = await getProducts();
  const productPages: MetadataRoute.Sitemap = products.map((product) => ({
    url: `${baseUrl}/products/${product.id}`,
    lastModified: new Date(product.updatedAt),
    changeFrequency: 'weekly',
    priority: 0.7,
  }));

  return [...staticPages, ...blogPages, ...productPages];
}
```

### Sitemap Priority Guidelines

**Priority Values** (0.0 to 1.0):
- **1.0**: Homepage only
- **0.8**: Major sections (About, Contact, Products landing)
- **0.6-0.7**: Important content (blog posts, products)
- **0.4-0.5**: Secondary content (tags, categories)
- **0.1-0.3**: Low priority (archives, pagination)

**Note**: Priority is relative to YOUR site, not the web. It's a hint, not a directive.

### Change Frequency Guidelines

**Values**:
- `always`: Changes every access (rare, usually just for real-time data)
- `hourly`: News sites, stock tickers
- `daily`: Active blogs, frequently updated products
- `weekly`: Normal blogs, most product pages
- `monthly`: About pages, documentation
- `yearly`: Legal pages, terms of service
- `never`: Archived content

**Note**: Google largely ignores `changefreq` in 2026. Focus on accurate `lastModified`.

### Multiple Sitemaps (Large Sites)

**Use When**: More than 50,000 URLs or sitemap exceeds 50 MB.

**Sitemap Index**:
```typescript
// app/sitemap.ts
export default function sitemap(): MetadataRoute.Sitemap {
  return [
    {
      url: 'https://acme.com/sitemap-blog.xml',
      lastModified: new Date(),
    },
    {
      url: 'https://acme.com/sitemap-products.xml',
      lastModified: new Date(),
    },
    {
      url: 'https://acme.com/sitemap-pages.xml',
      lastModified: new Date(),
    },
  ];
}
```

**Individual Sitemaps**:
```typescript
// app/sitemap-blog.xml/route.ts
import { MetadataRoute } from 'next';

export async function GET() {
  const posts = await getBlogPosts();

  const sitemap: MetadataRoute.Sitemap = posts.map((post) => ({
    url: `https://acme.com/blog/${post.slug}`,
    lastModified: new Date(post.updatedAt),
    changeFrequency: 'monthly',
    priority: 0.6,
  }));

  // Return XML
  return new Response(generateSitemapXML(sitemap), {
    headers: {
      'Content-Type': 'application/xml',
    },
  });
}
```

## Robots.txt

### Basic Robots.txt Implementation

**File**: `app/robots.ts`

```typescript
// app/robots.ts
import { MetadataRoute } from 'next';

export default function robots(): MetadataRoute.Robots {
  return {
    rules: {
      userAgent: '*',
      allow: '/',
      disallow: '/private/',
    },
    sitemap: 'https://acme.com/sitemap.xml',
  };
}
```

**Generated Output** (`/robots.txt`):
```txt
User-Agent: *
Allow: /
Disallow: /private/

Sitemap: https://acme.com/sitemap.xml
```

### Environment-Based Robots.txt

**Block Indexing in Staging/Dev**:

```typescript
// app/robots.ts
import { MetadataRoute } from 'next';

export default function robots(): MetadataRoute.Robots {
  const baseUrl = process.env.NEXT_PUBLIC_BASE_URL || 'https://acme.com';
  const isProduction = process.env.NEXT_PUBLIC_ENV === 'production';

  if (!isProduction) {
    // Block all crawlers in staging/dev
    return {
      rules: {
        userAgent: '*',
        disallow: '/',
      },
    };
  }

  // Allow crawlers in production
  return {
    rules: [
      {
        userAgent: '*',
        allow: '/',
        disallow: ['/admin/', '/api/', '/private/'],
      },
      {
        userAgent: 'GPTBot', // Block AI bots (optional)
        disallow: '/',
      },
    ],
    sitemap: `${baseUrl}/sitemap.xml`,
  };
}
```

### Advanced Robots.txt Rules

**Multiple User Agents**:
```typescript
export default function robots(): MetadataRoute.Robots {
  return {
    rules: [
      {
        userAgent: '*',
        allow: '/',
        disallow: ['/admin/', '/private/'],
        crawlDelay: 10, // Optional: delay between requests (seconds)
      },
      {
        userAgent: 'Googlebot',
        allow: '/',
        disallow: ['/admin/'],
        // No crawl delay for Google
      },
      {
        userAgent: ['GPTBot', 'CCBot', 'anthropic-ai'],
        disallow: '/', // Block AI crawlers
      },
    ],
    sitemap: 'https://acme.com/sitemap.xml',
  };
}
```

### What to Block with Robots.txt

**Always Block**:
- `/admin/` - Admin panels
- `/api/` - API endpoints
- `/_next/` - Next.js internals (usually auto-blocked)
- `/private/` - Private content
- `/thank-you/` - Thank you pages (low SEO value)
- `/cart/` - Cart pages (duplicate content)
- `*?*sort=*` - Sorted URLs (duplicate content)
- `*?*page=*` - Paginated URLs (if canonical is set)

**Example**:
```typescript
disallow: [
  '/admin/',
  '/api/',
  '/private/',
  '/thank-you/',
  '/cart/',
  '/*?sort=*',
  '/*?page=*',
]
```

### Common Crawler User Agents

```typescript
// Search engines
'Googlebot'      // Google
'Bingbot'        // Bing
'Slurp'          // Yahoo
'DuckDuckBot'    // DuckDuckGo
'Baiduspider'    // Baidu
'YandexBot'      // Yandex

// AI crawlers
'GPTBot'         // OpenAI (ChatGPT)
'anthropic-ai'   // Anthropic (Claude)
'CCBot'          // Common Crawl
'Claude-Web'     // Claude web search

// Social media
'facebookexternalhit'  // Facebook
'Twitterbot'           // Twitter
'LinkedInBot'          // LinkedIn

// SEO tools
'AhrefsBot'      // Ahrefs
'SemrushBot'     // Semrush
'MJ12bot'        // Majestic
```

## Canonical URLs

### What Are Canonical URLs?

**Purpose**: Indicate the preferred URL when duplicates exist.

**Problem**: Same content accessible via multiple URLs:
```
https://acme.com/blog/my-post
https://acme.com/blog/my-post?ref=twitter
https://acme.com/blog/my-post?utm_source=email
```

**Solution**: All point to canonical version:
```html
<link rel="canonical" href="https://acme.com/blog/my-post" />
```

### Basic Canonical Implementation

**Using Next.js Metadata API**:

```typescript
// app/blog/[slug]/page.tsx
import { Metadata } from 'next';

export async function generateMetadata({ params }: Props): Promise<Metadata> {
  const { slug } = await params;

  return {
    alternates: {
      canonical: `https://acme.com/blog/${slug}`,
    },
  };
}
```

**Generated Output**:
```html
<link rel="canonical" href="https://acme.com/blog/my-post" />
```

### Self-Referencing Canonicals

**Best Practice**: Every page should have a canonical, even if it's itself.

```typescript
// app/blog/page.tsx
export const metadata: Metadata = {
  alternates: {
    canonical: 'https://acme.com/blog', // Points to itself
  },
};
```

**Why**: Makes your canonical strategy explicit and prevents future issues.

### Dynamic Canonical URLs

```typescript
// app/blog/[slug]/page.tsx
export async function generateMetadata({ params }: Props): Promise<Metadata> {
  const { slug } = await params;
  const baseUrl = process.env.NEXT_PUBLIC_BASE_URL || 'https://acme.com';

  return {
    alternates: {
      canonical: `${baseUrl}/blog/${slug}`,
    },
  };
}
```

### Canonical with metadataBase (Recommended)

**Root Layout**:
```typescript
// app/layout.tsx
export const metadata: Metadata = {
  metadataBase: new URL(
    process.env.NEXT_PUBLIC_BASE_URL || 'https://acme.com'
  ),
};
```

**Pages** (can use relative URLs):
```typescript
// app/blog/[slug]/page.tsx
export const metadata: Metadata = {
  alternates: {
    canonical: './', // Resolves to current page URL
  },
};
```

**Generated**: Automatically resolves to absolute URL.

### Handling Query Parameters

**Problem**: Query params create duplicate URLs.

**Solution**: Canonical should point to clean URL (no params).

```typescript
// app/blog/[slug]/page.tsx
export async function generateMetadata({ params }: Props): Promise<Metadata> {
  const { slug } = await params;

  // Always canonical to clean URL (no query params)
  return {
    alternates: {
      canonical: `https://acme.com/blog/${slug}`, // No ?ref=twitter, etc.
    },
  };
}
```

### Cross-Domain Canonicals

**Use Case**: Syndicated content published on multiple sites.

**Example**: Content published on both your blog and Medium.

```typescript
// If original is on acme.com
export const metadata: Metadata = {
  alternates: {
    canonical: 'https://acme.com/blog/my-post', // Points to self (original)
  },
};

// If republished on Medium
// Medium should canonical to acme.com (your original)
```

**Rule**: Canonical should point to the **original source**.

## Multilingual SEO (Hreflang)

### What is Hreflang?

**Purpose**: Tell search engines which language version to show users.

**Problem**: Same content in multiple languages creates duplicates.

**Solution**: Hreflang links indicate language/region relationships.

### Basic Hreflang Implementation

```typescript
// app/en/page.tsx
export const metadata: Metadata = {
  alternates: {
    canonical: 'https://acme.com/en',
    languages: {
      'en-US': 'https://acme.com/en',
      'es-ES': 'https://acme.com/es',
      'fr-FR': 'https://acme.com/fr',
      'de-DE': 'https://acme.com/de',
    },
  },
};
```

**Generated Output**:
```html
<link rel="canonical" href="https://acme.com/en" />
<link rel="alternate" hreflang="en-US" href="https://acme.com/en" />
<link rel="alternate" hreflang="es-ES" href="https://acme.com/es" />
<link rel="alternate" hreflang="fr-FR" href="https://acme.com/fr" />
<link rel="alternate" hreflang="de-DE" href="https://acme.com/de" />
```

### Language Codes

**Format**: `language-REGION` (ISO 639-1 + ISO 3166-1)

**Examples**:
- `en-US` - English (United States)
- `en-GB` - English (United Kingdom)
- `es-ES` - Spanish (Spain)
- `es-MX` - Spanish (Mexico)
- `fr-FR` - French (France)
- `fr-CA` - French (Canada)
- `pt-BR` - Portuguese (Brazil)
- `pt-PT` - Portuguese (Portugal)
- `zh-CN` - Chinese (Simplified, China)
- `zh-TW` - Chinese (Traditional, Taiwan)

**Language Only** (no region):
- `en` - English (any region)
- `es` - Spanish (any region)
- `fr` - French (any region)

### X-Default for Unlisted Languages

**Purpose**: Fallback for users whose language isn't listed.

```typescript
export const metadata: Metadata = {
  alternates: {
    canonical: 'https://acme.com/en',
    languages: {
      'x-default': 'https://acme.com/en', // Default fallback
      'en-US': 'https://acme.com/en',
      'es-ES': 'https://acme.com/es',
      'fr-FR': 'https://acme.com/fr',
    },
  },
};
```

**Use Case**: User speaks German (de-DE) but you only have en/es/fr versions. x-default sends them to English.

### Dynamic Multilingual Pages

```typescript
// app/[lang]/blog/[slug]/page.tsx
interface Props {
  params: Promise<{ lang: string; slug: string }>;
}

export async function generateMetadata({ params }: Props): Promise<Metadata> {
  const { lang, slug } = await params;
  const baseUrl = 'https://acme.com';

  return {
    alternates: {
      canonical: `${baseUrl}/${lang}/blog/${slug}`,
      languages: {
        'x-default': `${baseUrl}/en/blog/${slug}`,
        'en-US': `${baseUrl}/en/blog/${slug}`,
        'es-ES': `${baseUrl}/es/blog/${slug}`,
        'fr-FR': `${baseUrl}/fr/blog/${slug}`,
        'de-DE': `${baseUrl}/de/blog/${slug}`,
      },
    },
  };
}
```

### Canonical Strategy for Multilingual Sites

**Option 1: Self-Referencing Canonicals** (Recommended)
- Each language version canonicals to itself
- Use hreflang to show language relationships

```typescript
// app/en/page.tsx
alternates: {
  canonical: 'https://acme.com/en', // Points to self
  languages: { ... },
}

// app/es/page.tsx
alternates: {
  canonical: 'https://acme.com/es', // Points to self
  languages: { ... },
}
```

**Option 2: Consolidated Canonicals**
- All language versions canonical to primary language
- Use when translations aren't unique enough

```typescript
// app/en/page.tsx
alternates: {
  canonical: 'https://acme.com/en', // Primary version
  languages: { ... },
}

// app/es/page.tsx (Spanish translation)
alternates: {
  canonical: 'https://acme.com/en', // Points to English original
  // No languages (not indexed as separate version)
}
```

**When to Use Each**:
- **Option 1**: When each language version has unique, valuable content
- **Option 2**: When translations are machine-translated or low-quality

## Best Practices

### Sitemap Best Practices

- [ ] Use absolute URLs (https://acme.com/page, not /page)
- [ ] Update `lastModified` when content changes
- [ ] Include only public, indexable pages
- [ ] Exclude pages blocked by robots.txt
- [ ] Exclude duplicate pages (use canonical instead)
- [ ] Split into multiple sitemaps if >50K URLs
- [ ] Submit to Google Search Console
- [ ] Compress large sitemaps (gzip)
- [ ] Update dynamically (fetch from database)
- [ ] Include image/video sitemaps if applicable

### Robots.txt Best Practices

- [ ] Allow Googlebot to crawl important pages
- [ ] Block admin panels and private content
- [ ] Block API endpoints
- [ ] Block duplicate content (filtered/sorted URLs)
- [ ] Include sitemap URL
- [ ] Test with Google Search Console robots.txt tester
- [ ] Don't use robots.txt for sensitive data (use authentication)
- [ ] Block staging/dev environments completely
- [ ] Consider blocking AI crawlers (GPTBot, etc.)
- [ ] Keep rules simple and specific

### Canonical URL Best Practices

- [ ] Every page should have a canonical
- [ ] Use absolute URLs (https://..., not relative)
- [ ] Canonical should be the preferred version
- [ ] Self-reference when no duplicates exist
- [ ] Point to clean URL (remove query params)
- [ ] Be consistent across all duplicates
- [ ] Use metadataBase for automatic resolution
- [ ] Don't canonical across different content
- [ ] Monitor Google Search Console for canonical issues
- [ ] Use 301 redirects for moved content (not just canonical)

### Multilingual Best Practices

- [ ] Implement hreflang for all language versions
- [ ] Include x-default for unlisted languages
- [ ] Use correct language-region codes (en-US, not en)
- [ ] Hreflang must be reciprocal (bidirectional)
- [ ] Canonical strategy should match hreflang (self-ref or consolidated)
- [ ] Test with Google Search Console international targeting
- [ ] Ensure each language version is on separate URL
- [ ] Don't use IP-based redirects (breaks hreflang)
- [ ] Include all language versions in sitemap
- [ ] Monitor indexing for each language version

## Common Issues

### Issue: Pages Not Indexed

**Possible Causes**:
1. Missing from sitemap
2. Blocked by robots.txt
3. Canonical points elsewhere
4. Low quality content
5. Recently published (needs time)

**Solution**:
- Add to sitemap
- Check robots.txt
- Verify canonical points to self
- Request indexing in Search Console
- Wait (indexing takes days/weeks)

### Issue: Duplicate Content

**Problem**: Same content on multiple URLs.

**Solution**:
```typescript
// Set canonical on all duplicates
export const metadata: Metadata = {
  alternates: {
    canonical: 'https://acme.com/preferred-version',
  },
};
```

### Issue: Wrong Language Version Showing

**Problem**: Users see wrong language in search results.

**Solution**:
```typescript
// Ensure hreflang is correct and reciprocal
alternates: {
  canonical: 'https://acme.com/en/page',
  languages: {
    'en-US': 'https://acme.com/en/page',
    'es-ES': 'https://acme.com/es/page', // Must exist and link back
  },
}
```

## Related Skills

- `nextjs-seo-metadata` - Core Next.js metadata API
- `seo-validation-testing` - Testing and validation tools
- `structured-data-jsonld` - Rich results and structured data

## Sources & References

### Official Documentation

- [Metadata Files: sitemap.xml | Next.js](https://nextjs.org/docs/app/api-reference/file-conventions/metadata/sitemap)
- [Metadata Files: robots.txt | Next.js](https://nextjs.org/docs/app/api-reference/file-conventions/metadata/robots)
- [Functions: generateMetadata | Next.js](https://nextjs.org/docs/app/api-reference/functions/generate-metadata)

### Implementation Guides

- [Generating dynamic robots.txt and sitemap.xml](https://dev.to/arfatapp/generating-dynamic-robotstxt-and-sitemapxml-in-a-nextjs-app-router-with-typescript-35l9)
- [Next.js SEO: Metadata, Sitemaps & Canonical Tags](https://prateeksha.com/blog/nextjs-app-router-seo-metadata-sitemaps-canonicals)
- [How to Use Canonical Tags and Hreflang in Next.js 15](https://www.buildwithmatija.com/blog/nextjs-advanced-seo-multilingual-canonical-tags)
- [Implementing Dynamic and Multilingual Canonical Tags](https://github.com/vercel/next.js/discussions/57794)

### Google Documentation

- [Sitemaps - Google Search Central](https://developers.google.com/search/docs/crawling-indexing/sitemaps/overview)
- [Robots.txt - Google Search Central](https://developers.google.com/search/docs/crawling-indexing/robots/intro)
- [Canonicalization - Google Search Central](https://developers.google.com/search/docs/crawling-indexing/consolidate-duplicate-urls)
- [Hreflang - Google Search Central](https://developers.google.com/search/docs/specialty/international/localized-versions)

---

**Last Updated**: January 10, 2026
**Knowledge Base**: Next.js 16 metadata API + Google SEO guidelines
**Confidence Level**: High (based on official Next.js and Google documentation)
