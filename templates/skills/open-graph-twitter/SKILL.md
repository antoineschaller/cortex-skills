# Open Graph & Twitter Cards Skill

You are an expert in Open Graph protocol and Twitter Cards optimization for social media sharing. You help developers implement effective social media metadata to maximize engagement, click-through rates, and brand visibility when content is shared on platforms like Facebook, Twitter/X, LinkedIn, and others.

## Core Knowledge

### The Open Graph Protocol

**Origin**: Created by Facebook in 2010, now adopted by virtually all social platforms.

**Purpose**: Standardizes how web pages are represented when shared on social media.

**Critical Insight**: Open Graph tags control:
- How your content appears in social feeds
- Click-through rates (CTR) from social platforms
- First impressions of your brand
- Whether users engage with shared links

**Impact**: Proper OG optimization can increase social CTR by 2-3x.

### Four Required Properties

Every page must include these four properties:

```typescript
openGraph: {
  title: 'Your Page Title',        // og:title
  type: 'website',                  // og:type
  url: 'https://example.com/page',  // og:url
  images: ['https://example.com/image.png'], // og:image
}
```

## Open Graph Implementation in Next.js 16

### Basic Open Graph Setup

```typescript
// app/page.tsx
import { Metadata } from 'next';

export const metadata: Metadata = {
  metadataBase: new URL('https://acme.com'),
  openGraph: {
    type: 'website',
    locale: 'en_US',
    url: 'https://acme.com',
    siteName: 'Acme Company',
    title: 'Acme Company - Enterprise Development Tools',
    description: 'Build amazing products with Acme Company. Enterprise-grade tools for modern developers.',
    images: [
      {
        url: '/og-image.png', // Relative URL (resolved via metadataBase)
        width: 1200,
        height: 630,
        alt: 'Acme Company - Enterprise Development Tools',
      },
    ],
  },
};
```

### Complete Open Graph Object

```typescript
export const metadata: Metadata = {
  metadataBase: new URL('https://acme.com'),
  openGraph: {
    // Required
    title: 'Your Page Title',
    type: 'website', // or 'article', 'product', 'video', etc.
    url: 'https://acme.com/page',
    images: [
      {
        url: 'https://acme.com/og-image.png',
        width: 1200,
        height: 630,
        alt: 'Description of image',
        type: 'image/png',
        secureUrl: 'https://acme.com/og-image.png', // HTTPS URL
      },
    ],

    // Recommended
    description: 'Your page description that appears in social previews.',
    siteName: 'Acme Company',
    locale: 'en_US',
    alternateLocale: ['en_GB', 'fr_FR', 'es_ES'],

    // Optional (but useful)
    determiner: 'the', // "the Acme Company" vs "Acme Company"
    countryName: 'USA',
    ttl: 3600, // Cache time-to-live in seconds

    // Audio/Video (if applicable)
    audio: [
      {
        url: 'https://acme.com/audio.mp3',
        type: 'audio/mpeg',
      },
    ],
    videos: [
      {
        url: 'https://acme.com/video.mp4',
        width: 1920,
        height: 1080,
        type: 'video/mp4',
      },
    ],
  },
};
```

## Open Graph Types

### Website (default)

**Use For**: Homepage, landing pages, general pages.

```typescript
openGraph: {
  type: 'website',
  title: 'Acme Company - Homepage',
  description: 'Enterprise development tools.',
  url: 'https://acme.com',
  siteName: 'Acme Company',
  images: [{ url: '/og-home.png', width: 1200, height: 630 }],
}
```

### Article (blog posts, news)

**Use For**: Blog posts, news articles, editorial content.

```typescript
openGraph: {
  type: 'article',
  title: 'How to Build a SaaS App in 2026',
  description: 'Complete guide to building scalable SaaS applications.',
  url: 'https://acme.com/blog/how-to-build-saas',
  siteName: 'Acme Blog',
  images: [{ url: '/blog/saas-guide-og.png', width: 1200, height: 630 }],

  // Article-specific properties
  article: {
    publishedTime: '2026-01-10T08:00:00Z',
    modifiedTime: '2026-01-10T12:00:00Z',
    expirationTime: '2027-01-10T08:00:00Z', // Optional
    authors: ['https://acme.com/authors/john-doe'],
    section: 'Technology', // Category
    tags: ['SaaS', 'Next.js', 'Development'],
  },
}
```

### Product (e-commerce)

**Use For**: Product pages, e-commerce listings.

```typescript
openGraph: {
  type: 'product',
  title: 'Premium Widget Pro - Acme Store',
  description: 'The best widget on the market. Free shipping.',
  url: 'https://acme.com/products/premium-widget-pro',
  siteName: 'Acme Store',
  images: [{ url: '/products/widget-og.png', width: 1200, height: 630 }],

  // Product-specific properties
  product: {
    price: {
      amount: '99.99',
      currency: 'USD',
    },
    availability: 'in stock', // or 'out of stock', 'preorder'
    condition: 'new', // or 'used', 'refurbished'
    retailerItemId: 'WIDGET-PRO-001',
    brand: 'Acme',
  },
}
```

### Profile (user profiles)

**Use For**: User profile pages, author pages.

```typescript
openGraph: {
  type: 'profile',
  title: 'John Doe - Acme Developer',
  description: 'Full-stack developer specializing in Next.js and React.',
  url: 'https://acme.com/profile/johndoe',
  images: [{ url: '/profiles/johndoe-og.png', width: 1200, height: 630 }],

  // Profile-specific properties
  profile: {
    firstName: 'John',
    lastName: 'Doe',
    username: 'johndoe',
    gender: 'male', // Optional
  },
}
```

### Video

**Use For**: Video content pages.

```typescript
openGraph: {
  type: 'video.other', // or 'video.movie', 'video.episode', 'video.tv_show'
  title: 'Next.js Tutorial - Getting Started',
  description: 'Learn Next.js from scratch in this comprehensive tutorial.',
  url: 'https://acme.com/videos/nextjs-tutorial',
  siteName: 'Acme Video',
  images: [{ url: '/videos/nextjs-tutorial-thumbnail.png', width: 1200, height: 630 }],

  // Video-specific properties
  videos: [
    {
      url: 'https://acme.com/videos/nextjs-tutorial.mp4',
      secureUrl: 'https://acme.com/videos/nextjs-tutorial.mp4',
      type: 'video/mp4',
      width: 1920,
      height: 1080,
      duration: 600, // seconds
      releaseDate: '2026-01-10T08:00:00Z',
      tags: ['Next.js', 'Tutorial', 'React'],
    },
  ],
}
```

## Twitter Cards Implementation

### Twitter Card Types

**Four Card Types**:
1. **summary**: Default card with small square image
2. **summary_large_image**: Large image card (most popular)
3. **app**: Mobile app install card
4. **player**: Video/audio player card

### Summary Large Image (Recommended)

**Most Common**: Use for 90% of content.

```typescript
twitter: {
  card: 'summary_large_image',
  site: '@acmecompany', // Site's Twitter handle
  creator: '@johndoe', // Content creator's handle
  title: 'How to Build a SaaS App in 2026',
  description: 'Complete guide to building scalable SaaS applications.',
  images: ['https://acme.com/blog/saas-guide-twitter.png'],
}
```

**Rendered Output**:
```html
<meta name="twitter:card" content="summary_large_image" />
<meta name="twitter:site" content="@acmecompany" />
<meta name="twitter:creator" content="@johndoe" />
<meta name="twitter:title" content="How to Build a SaaS App in 2026" />
<meta name="twitter:description" content="Complete guide to building scalable SaaS applications." />
<meta name="twitter:image" content="https://acme.com/blog/saas-guide-twitter.png" />
```

### Summary Card

**Use For**: Content where image is secondary (text-focused).

```typescript
twitter: {
  card: 'summary',
  site: '@acmecompany',
  title: 'Latest Developer News',
  description: 'Stay up to date with the latest in web development.',
  images: ['/twitter-logo.png'], // Small square image
}
```

### App Card

**Use For**: Promoting mobile app installs.

```typescript
twitter: {
  card: 'app',
  site: '@acmecompany',
  title: 'Download Acme App',
  description: 'The best productivity app for iOS and Android.',
  images: ['/app-preview.png'],
  app: {
    id: {
      iphone: '123456789',
      ipad: '123456789',
      googleplay: 'com.acme.app',
    },
    url: {
      iphone: 'acme://open',
      ipad: 'acme://open',
      googleplay: 'acme://open',
    },
    name: {
      iphone: 'Acme App',
      ipad: 'Acme App',
      googleplay: 'Acme App',
    },
  },
}
```

### Player Card

**Use For**: Embedded audio/video players.

```typescript
twitter: {
  card: 'player',
  site: '@acmecompany',
  title: 'Next.js Tutorial Video',
  description: 'Learn Next.js in 10 minutes.',
  images: ['/video-thumbnail.png'],
  players: [
    {
      url: 'https://acme.com/embed/video',
      width: 1920,
      height: 1080,
      stream: 'https://acme.com/video.mp4',
    },
  ],
}
```

## Complete Twitter + Open Graph Example

**Best Practice**: Combine both for maximum compatibility.

```typescript
// app/blog/[slug]/page.tsx
export async function generateMetadata({ params }: Props): Promise<Metadata> {
  const post = await getBlogPost(params.slug);

  return {
    title: post.title,
    description: post.excerpt,

    // Open Graph
    openGraph: {
      type: 'article',
      locale: 'en_US',
      url: `https://acme.com/blog/${params.slug}`,
      siteName: 'Acme Blog',
      title: post.title,
      description: post.excerpt,
      images: [
        {
          url: post.ogImage,
          width: 1200,
          height: 630,
          alt: post.title,
        },
      ],
      article: {
        publishedTime: post.publishedAt,
        modifiedTime: post.updatedAt,
        authors: [post.author.name],
        section: post.category,
        tags: post.tags,
      },
    },

    // Twitter
    twitter: {
      card: 'summary_large_image',
      site: '@acmeblog',
      creator: post.author.twitter,
      title: post.title,
      description: post.excerpt,
      images: [post.twitterImage || post.ogImage], // Fallback to OG image
    },
  };
}
```

## Image Specifications

### Open Graph Image Requirements

**Recommended Dimensions**:
- **1200 x 630 pixels** (1.91:1 aspect ratio) - RECOMMENDED
- **1200 x 1200 pixels** (1:1 aspect ratio) - Alternative for square images
- **Minimum**: 600 x 314 pixels
- **Maximum**: 8 MB file size

**Best Practices**:
- Use PNG or JPG format
- Include branding (logo/colors)
- Make text large and readable (40px+ font size)
- Use high contrast
- Test on both desktop and mobile
- Avoid text-heavy designs (keep it visual)

**Platform-Specific Guidelines**:
| Platform | Recommended Size | Aspect Ratio | Max File Size |
|----------|------------------|--------------|---------------|
| Facebook | 1200 x 630 px | 1.91:1 | 8 MB |
| LinkedIn | 1200 x 627 px | 1.91:1 | 5 MB |
| Twitter | 1200 x 675 px | 16:9 | 5 MB |
| WhatsApp | 300 x 300 px | 1:1 | 300 KB |
| Slack | 1200 x 630 px | 1.91:1 | 5 MB |

### Twitter Image Requirements

**Summary Large Image**:
- **Recommended**: 1200 x 675 pixels (16:9)
- **Minimum**: 300 x 157 pixels
- **Maximum**: 5 MB
- **Aspect Ratio**: 2:1 (width to height)

**Summary Card**:
- **Recommended**: 1:1 square (e.g., 400 x 400 px)
- **Minimum**: 144 x 144 pixels
- **Maximum**: 5 MB

**Format Support**:
- JPG, PNG, WEBP, GIF (static only, no animated)
- WEBP recommended for smaller file sizes

### Image Alt Text

**Required**: Always include alt text for accessibility and fallback.

```typescript
openGraph: {
  images: [
    {
      url: '/og-image.png',
      width: 1200,
      height: 630,
      alt: 'Acme Company dashboard showing analytics and user metrics', // ✅ Descriptive
    },
  ],
}

// ❌ Bad alt text examples:
alt: 'Image' // Too generic
alt: '' // Empty (missing accessibility benefit)
alt: 'og-image.png' // Filename (not descriptive)

// ✅ Good alt text examples:
alt: 'Graph showing 200% increase in website traffic over 6 months'
alt: 'Smiling customer holding Acme product with 5-star rating'
alt: 'Next.js code editor with TypeScript syntax highlighting'
```

## Dynamic Images Based on Content

### Blog Post with Custom OG Image

```typescript
// app/blog/[slug]/page.tsx
export async function generateMetadata({ params }: Props): Promise<Metadata> {
  const post = await getBlogPost(params.slug);

  // Different images for different platforms
  const ogImage = {
    url: post.ogImage || '/default-og.png',
    width: 1200,
    height: 630,
    alt: post.ogImageAlt || post.title,
  };

  const twitterImage = post.twitterImage || post.ogImage || '/default-twitter.png';

  return {
    openGraph: {
      images: [ogImage],
    },
    twitter: {
      images: [twitterImage],
    },
  };
}
```

### Multiple Images for Different Platforms

```typescript
export const metadata: Metadata = {
  openGraph: {
    images: [
      {
        url: '/og-primary.png', // First image is primary
        width: 1200,
        height: 630,
        alt: 'Primary image',
      },
      {
        url: '/og-secondary.png', // Fallback images
        width: 1200,
        height: 630,
        alt: 'Secondary image',
      },
    ],
  },
};
```

## Platform-Specific Optimizations

### Facebook & LinkedIn

**Prefer Open Graph**: Facebook and LinkedIn primarily use Open Graph tags.

```typescript
openGraph: {
  type: 'article',
  locale: 'en_US',
  siteName: 'Acme Blog',
  title: 'Article Title',
  description: 'Article description.',
  images: [
    {
      url: '/og-image.png',
      width: 1200,
      height: 630,
      alt: 'Image description',
    },
  ],
}
```

**Note**: Twitter also reads Open Graph tags as fallback if Twitter tags missing.

### Twitter/X Specific

**Use Twitter Tags**: For Twitter-specific optimizations.

```typescript
twitter: {
  card: 'summary_large_image',
  site: '@acmecompany', // Site's Twitter handle
  creator: '@johndoe', // Author's Twitter handle (appears as "by @johndoe")
  title: 'Custom Twitter Title', // Can differ from OG title
  description: 'Custom Twitter description.',
  images: ['/twitter-specific-image.png'], // Twitter-optimized image
}
```

**Creator vs. Site**:
- `site`: Organization/website Twitter handle (e.g., @acmecompany)
- `creator`: Individual content creator handle (e.g., @johndoe)
- Both are optional but recommended for attribution

### WhatsApp

**Uses Open Graph**: WhatsApp reads Open Graph tags.

**Optimization**:
- Keep images under 300 KB (faster loading on mobile)
- Use 1:1 square images for better mobile display
- Compress images without losing quality

### Slack

**Uses Open Graph**: Slack reads Open Graph tags.

**Optimization**:
- 1200 x 630 px images recommended
- Clear, readable text in images
- Include logo/branding

## Debugging & Validation

### Facebook Sharing Debugger

**URL**: https://developers.facebook.com/tools/debug/

**Use For**:
- Preview how your page appears on Facebook
- Force Facebook to re-scrape your page
- Identify Open Graph errors
- See which tags Facebook reads

**How to Use**:
1. Enter your URL
2. Click "Debug"
3. View preview and warnings
4. Click "Scrape Again" to refresh cache

### Twitter Card Validator

**URL**: https://cards-dev.twitter.com/validator

**Use For**:
- Preview how your page appears on Twitter
- Validate Twitter Card markup
- Identify missing or incorrect tags

**How to Use**:
1. Enter your URL
2. Click "Preview card"
3. View preview and any errors
4. Fix issues and re-validate

**Note**: Twitter's cache updates more frequently than Facebook (usually within minutes).

### LinkedIn Post Inspector

**URL**: https://www.linkedin.com/post-inspector/

**Use For**:
- Preview how your page appears on LinkedIn
- Force LinkedIn to re-scrape your page
- Validate Open Graph tags

**How to Use**:
1. Enter your URL
2. Click "Inspect"
3. View preview and metadata
4. Click "Inspect" again to refresh cache

### Browser View Source

**Quick Check**: View page source to verify tags are present.

```bash
# In browser: view-source:https://your-site.com/page

# Or use curl:
curl -s https://your-site.com/page | grep 'og:'
curl -s https://your-site.com/page | grep 'twitter:'
```

**Verify**:
- Tags are in `<head>` section
- No duplicate tags
- Values are properly escaped
- Images use absolute URLs (not relative)

## Common Issues & Solutions

### Issue: Images Not Showing in Social Previews

**Possible Causes**:
1. Using relative URLs without `metadataBase`
2. Image file too large (>5-8 MB)
3. Image dimensions too small
4. Image blocked by robots.txt or authentication
5. HTTPS issues (mixed content)
6. Image format not supported

**Solutions**:
```typescript
// ✅ Fix 1: Set metadataBase
export const metadata: Metadata = {
  metadataBase: new URL('https://acme.com'),
  openGraph: {
    images: ['/og-image.png'], // Resolves to https://acme.com/og-image.png
  },
};

// ✅ Fix 2: Use absolute URLs
openGraph: {
  images: ['https://acme.com/og-image.png'], // Fully qualified
}

// ✅ Fix 3: Compress images
// Use tools like TinyPNG, ImageOptim, or Next.js Image Optimization

// ✅ Fix 4: Ensure images are publicly accessible
// Check robots.txt doesn't block /images/* or /og-*
// Remove authentication requirements for OG images

// ✅ Fix 5: Use HTTPS for all image URLs
images: ['https://acme.com/image.png'] // ✅ HTTPS
images: ['http://acme.com/image.png']  // ❌ HTTP (may be blocked)
```

### Issue: Social Platform Showing Old Image/Content

**Problem**: Updated metadata but social platforms show cached version.

**Solution**: Force platforms to re-scrape.

**Facebook**:
1. Go to https://developers.facebook.com/tools/debug/
2. Enter URL
3. Click "Scrape Again"

**Twitter**:
1. Wait a few minutes (Twitter cache is shorter)
2. Or use Card Validator: https://cards-dev.twitter.com/validator

**LinkedIn**:
1. Go to https://www.linkedin.com/post-inspector/
2. Enter URL
3. Click "Inspect" again

**General Tip**: After metadata changes, always test with validators before sharing.

### Issue: Missing or Incorrect Title/Description

**Problem**: Social preview shows wrong title or description.

**Checklist**:
- [ ] Verify `openGraph.title` and `openGraph.description` are set
- [ ] Check for typos in property names
- [ ] Ensure metadata is exported from Server Component
- [ ] Confirm page isn't using `'use client'` (metadata doesn't work in Client Components)
- [ ] View page source to verify tags in HTML

**Solution**:
```typescript
// ✅ Correct implementation
export const metadata: Metadata = {
  title: 'Page Title',
  description: 'Page description.',
  openGraph: {
    title: 'OG Title', // Can differ from page title
    description: 'OG description.',
  },
};
```

### Issue: Twitter Shows OG Image Instead of Twitter Image

**Behavior**: Twitter falls back to Open Graph if Twitter tags missing.

**Solution**: Explicitly set Twitter tags.

```typescript
export const metadata: Metadata = {
  openGraph: {
    images: ['/og-image.png'],
  },
  twitter: {
    card: 'summary_large_image',
    images: ['/twitter-image.png'], // Twitter-specific image
  },
};
```

**When to Use Different Images**:
- Twitter uses 16:9 aspect ratio (1200x675)
- Facebook uses 1.91:1 aspect ratio (1200x630)
- Create platform-optimized versions for best appearance

## Best Practices Summary

### Image Best Practices

- [ ] Use 1200 x 630 px for Open Graph
- [ ] Use 1200 x 675 px for Twitter (16:9)
- [ ] Keep file size under 5 MB (ideally <1 MB)
- [ ] Use PNG or JPG format
- [ ] Include descriptive alt text
- [ ] Use absolute URLs (set metadataBase)
- [ ] Test images on multiple devices (desktop, mobile)
- [ ] Compress images without quality loss
- [ ] Include branding (logo, colors)
- [ ] Make text readable (40px+ font size)

### Metadata Best Practices

- [ ] Set unique metadata for every page
- [ ] Include all four required OG properties (title, type, url, images)
- [ ] Use appropriate `type` for content (article, product, etc.)
- [ ] Set both Open Graph and Twitter tags
- [ ] Keep titles under 60 characters
- [ ] Keep descriptions under 160 characters
- [ ] Include author/creator attribution when applicable
- [ ] Set `metadataBase` in root layout
- [ ] Use descriptive, engaging copy (increases CTR)
- [ ] Test with social platform validators

### Performance Best Practices

- [ ] Optimize image file sizes
- [ ] Use Next.js Image Optimization for OG images
- [ ] Set appropriate cache headers for images
- [ ] Use CDN for faster image delivery
- [ ] Consider dynamic OG image generation (see og-image-generation skill)
- [ ] Lazy load social share preview (if using client-side preview)

## Related Skills

- `nextjs-seo-metadata` - Core Next.js metadata API and SEO fundamentals
- `og-image-generation` - Dynamic OG image generation with @vercel/og
- `structured-data-jsonld` - JSON-LD structured data for rich results
- `seo-validation-testing` - Testing and validation tools for SEO

## Sources & References

### Official Documentation

- [The Open Graph Protocol (Official)](https://ogp.me/)
- [Next.js Metadata: opengraph-image](https://nextjs.org/docs/app/api-reference/file-conventions/metadata/opengraph-image)
- [Twitter Card Documentation](https://developer.twitter.com/en/docs/twitter-for-websites/cards/overview/abouts-cards)

### Implementation Guides

- [Understand Open Graph in Next.js: A Practical Guide](https://dev.to/danmugh/understand-open-graph-og-in-next-js-a-practical-guide-3ade)
- [SEO in Next.js — Metadata, OG Images & Canonicals](https://prateeksha.com/blog/seo-nextjs-metadata-og-canonical)
- [What Are Open Graph Tags And Why It Matters](https://seosetups.com/blog/open-graph/)
- [Open Graph SEO: Maximize Social Media Engagement](https://nogood.io/blog/open-graph-seo/)

### Validation Tools

- [Facebook Sharing Debugger](https://developers.facebook.com/tools/debug/)
- [Twitter Card Validator](https://cards-dev.twitter.com/validator)
- [LinkedIn Post Inspector](https://www.linkedin.com/post-inspector/)
- [OpenGraph Preview Tool](https://www.opengraph.xyz/)

---

**Last Updated**: January 10, 2026
**Knowledge Base**: Open Graph Protocol specification + Next.js 16 implementation guides
**Confidence Level**: High (based on official protocol docs and platform guidelines)
