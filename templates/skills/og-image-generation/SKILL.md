# Dynamic OG Image Generation Skill

You are an expert in dynamic Open Graph image generation using Next.js 16 and @vercel/og (ImageResponse API). You help developers create dynamic, personalized social media preview images programmatically at build time or request time for maximum engagement and scalability.

## Core Knowledge

### The Dynamic OG Image Revolution

**Problem**: Static OG images don't scale:
- Creating unique images for 1000s of blog posts is time-consuming
- Manual design work for each page is impractical
- Generic images get lower engagement than personalized ones
- Design changes require recreating all images

**Solution**: Generate images dynamically using code.

**Critical Insight**: Dynamic OG images can:
- **Increase CTR by 2-3x** compared to generic images
- **Scale to millions of pages** without manual design work
- **Update automatically** when content changes
- **Maintain brand consistency** across all pages
- **Be generated in ~800ms** using Edge Runtime

**Impact**: Companies like Vercel, GitHub, and Stripe use dynamic OG images for all content.

## ImageResponse API Overview

### How It Works

**Technology Stack**:
- **@vercel/og**: Vercel's OG image generation library
- **Satori**: Converts JSX/CSS to SVG
- **Resvg**: Converts SVG to PNG
- **Edge Runtime**: Fast execution (5x faster than serverless)

**Flow**:
```
JSX + CSS → Satori → SVG → Resvg → PNG → HTTP Response
```

**Performance**:
- **~800ms average** generation time
- **Edge deployment** for global low latency
- **No external dependencies** (fonts embedded)
- **Automatic caching** by platforms

## Basic Implementation

### Simple OG Image Route

```typescript
// app/api/og/route.tsx
import { ImageResponse } from 'next/og';

export const runtime = 'edge'; // REQUIRED: Edge Runtime

export async function GET() {
  return new ImageResponse(
    (
      <div
        style={{
          fontSize: 128,
          background: 'white',
          width: '100%',
          height: '100%',
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'center',
        }}
      >
        Hello World!
      </div>
    ),
    {
      width: 1200,
      height: 630,
    }
  );
}
```

**Usage in Metadata**:
```typescript
// app/page.tsx
export const metadata: Metadata = {
  openGraph: {
    images: ['/api/og'], // Points to OG image route
  },
};
```

### Dynamic OG Image with Parameters

```typescript
// app/api/og/route.tsx
import { ImageResponse } from 'next/og';
import { NextRequest } from 'next/server';

export const runtime = 'edge';

export async function GET(request: NextRequest) {
  const { searchParams } = new URL(request.url);
  const title = searchParams.get('title') || 'Default Title';
  const description = searchParams.get('description') || 'Default description';

  return new ImageResponse(
    (
      <div
        style={{
          height: '100%',
          width: '100%',
          display: 'flex',
          flexDirection: 'column',
          alignItems: 'center',
          justifyContent: 'center',
          backgroundColor: '#fff',
          padding: '40px',
        }}
      >
        <h1 style={{ fontSize: 60, marginBottom: 20 }}>{title}</h1>
        <p style={{ fontSize: 30, color: '#666' }}>{description}</p>
      </div>
    ),
    {
      width: 1200,
      height: 630,
    }
  );
}
```

**Usage**:
```typescript
// app/blog/[slug]/page.tsx
export async function generateMetadata({ params }: Props): Promise<Metadata> {
  const post = await getPost(params.slug);

  return {
    openGraph: {
      images: [
        `/api/og?title=${encodeURIComponent(post.title)}&description=${encodeURIComponent(post.excerpt)}`
      ],
    },
  };
}
```

## File-Based OG Image (Recommended)

### Using opengraph-image.tsx Convention

**File Structure**:
```
app/
├── opengraph-image.tsx          # Default OG image for site
├── blog/
│   ├── opengraph-image.tsx      # Default for /blog/*
│   └── [slug]/
│       └── opengraph-image.tsx  # Dynamic per blog post
```

**Implementation**:
```typescript
// app/blog/[slug]/opengraph-image.tsx
import { ImageResponse } from 'next/og';

export const runtime = 'edge';
export const alt = 'Blog Post';
export const size = {
  width: 1200,
  height: 630,
};
export const contentType = 'image/png';

interface Props {
  params: Promise<{ slug: string }>;
}

export default async function Image({ params }: Props) {
  const { slug } = await params;
  const post = await getPost(slug); // Fetch post data

  return new ImageResponse(
    (
      <div
        style={{
          background: 'linear-gradient(to bottom, #1e40af, #3b82f6)',
          width: '100%',
          height: '100%',
          display: 'flex',
          flexDirection: 'column',
          alignItems: 'center',
          justifyContent: 'center',
          padding: '40px',
          color: 'white',
        }}
      >
        <h1 style={{ fontSize: 72, fontWeight: 'bold', textAlign: 'center' }}>
          {post.title}
        </h1>
        <p style={{ fontSize: 32, marginTop: 20, opacity: 0.9 }}>
          {post.author.name} • {formatDate(post.publishedAt)}
        </p>
      </div>
    ),
    {
      ...size,
    }
  );
}
```

**Benefits**:
- Automatic routing (`/blog/post-slug/opengraph-image`)
- No manual metadata setup required
- Better file organization
- Type-safe with TypeScript
- Follows Next.js conventions

## Advanced Styling

### Flexbox Layouts

**Supported CSS Properties** (subset):
- display: 'flex', 'none'
- flexDirection: 'row', 'column'
- alignItems, justifyContent
- padding, margin
- width, height
- backgroundColor, color
- fontSize, fontWeight
- border, borderRadius
- opacity
- textAlign

**Example: Card Layout**:
```typescript
<div
  style={{
    display: 'flex',
    flexDirection: 'column',
    width: '100%',
    height: '100%',
    backgroundColor: '#f9fafb',
    padding: 60,
  }}
>
  {/* Header */}
  <div style={{ display: 'flex', alignItems: 'center', marginBottom: 40 }}>
    <img src="https://acme.com/logo.png" width={80} height={80} />
    <span style={{ fontSize: 40, marginLeft: 20 }}>Acme Blog</span>
  </div>

  {/* Content */}
  <div style={{ display: 'flex', flexDirection: 'column', flex: 1 }}>
    <h1 style={{ fontSize: 72, fontWeight: 'bold', marginBottom: 20 }}>
      {title}
    </h1>
    <p style={{ fontSize: 32, color: '#6b7280', lineHeight: 1.4 }}>
      {description}
    </p>
  </div>

  {/* Footer */}
  <div style={{ display: 'flex', alignItems: 'center', fontSize: 28 }}>
    <span>{author}</span>
    <span style={{ marginLeft: 20, marginRight: 20 }}>•</span>
    <span>{date}</span>
  </div>
</div>
```

### Gradients & Backgrounds

```typescript
// Linear gradient
<div
  style={{
    background: 'linear-gradient(to right, #ec4899, #8b5cf6)',
    width: '100%',
    height: '100%',
  }}
>
  Content
</div>

// Radial gradient
<div
  style={{
    background: 'radial-gradient(circle, #fbbf24, #f59e0b)',
    width: '100%',
    height: '100%',
  }}
>
  Content
</div>

// Background image (must be absolute URL)
<div
  style={{
    backgroundImage: 'url(https://acme.com/bg.png)',
    backgroundSize: 'cover',
    width: '100%',
    height: '100%',
  }}
>
  Content
</div>
```

### Text Styling

```typescript
<h1
  style={{
    fontSize: 72,
    fontWeight: 'bold',
    color: '#1f2937',
    lineHeight: 1.2,
    textAlign: 'center',
    letterSpacing: '-0.02em',
    maxWidth: 1000,
    overflow: 'hidden',
    textOverflow: 'ellipsis',
  }}
>
  {title}
</h1>
```

**Supported Text Properties**:
- fontSize, fontWeight, fontStyle
- color, opacity
- lineHeight, letterSpacing
- textAlign: 'left', 'center', 'right', 'justify'
- textOverflow: 'ellipsis'
- overflow: 'hidden'
- maxWidth, maxHeight

## Custom Fonts

### Loading Custom Fonts

```typescript
// app/api/og/route.tsx
import { ImageResponse } from 'next/og';

export const runtime = 'edge';

export async function GET() {
  // Fetch custom font
  const fontData = await fetch(
    new URL('../../../assets/Inter-Bold.ttf', import.meta.url)
  ).then((res) => res.arrayBuffer());

  return new ImageResponse(
    (
      <div
        style={{
          fontFamily: 'Inter',
          fontSize: 72,
          fontWeight: 700,
        }}
      >
        Custom Font Text
      </div>
    ),
    {
      width: 1200,
      height: 630,
      fonts: [
        {
          name: 'Inter',
          data: fontData,
          weight: 700,
          style: 'normal',
        },
      ],
    }
  );
}
```

### Multiple Font Weights

```typescript
export async function GET() {
  const [interRegular, interBold] = await Promise.all([
    fetch(new URL('../../../assets/Inter-Regular.ttf', import.meta.url))
      .then((res) => res.arrayBuffer()),
    fetch(new URL('../../../assets/Inter-Bold.ttf', import.meta.url))
      .then((res) => res.arrayBuffer()),
  ]);

  return new ImageResponse(
    (
      <div style={{ fontFamily: 'Inter' }}>
        <p style={{ fontWeight: 400 }}>Regular text</p>
        <p style={{ fontWeight: 700 }}>Bold text</p>
      </div>
    ),
    {
      width: 1200,
      height: 630,
      fonts: [
        {
          name: 'Inter',
          data: interRegular,
          weight: 400,
          style: 'normal',
        },
        {
          name: 'Inter',
          data: interBold,
          weight: 700,
          style: 'normal',
        },
      ],
    }
  );
}
```

### Google Fonts

```typescript
export async function GET() {
  // Fetch from Google Fonts
  const fontData = await fetch(
    'https://fonts.gstatic.com/s/roboto/v30/KFOmCnqEu92Fr1Mu4mxK.woff'
  ).then((res) => res.arrayBuffer());

  return new ImageResponse(
    (
      <div style={{ fontFamily: 'Roboto' }}>
        Google Font Text
      </div>
    ),
    {
      width: 1200,
      height: 630,
      fonts: [
        {
          name: 'Roboto',
          data: fontData,
          style: 'normal',
        },
      ],
    }
  );
}
```

## Images in OG Images

### Using Remote Images

```typescript
<div
  style={{
    display: 'flex',
    alignItems: 'center',
  }}
>
  <img
    src="https://acme.com/logo.png"
    width={100}
    height={100}
    style={{ borderRadius: 50 }}
  />
  <h1 style={{ marginLeft: 20 }}>Acme Company</h1>
</div>
```

**Requirements**:
- Must use absolute URLs (https://...)
- Images must be publicly accessible
- Recommended: Host on same domain or CDN

### Using Base64 Encoded Images

```typescript
// For small images (logos, icons)
const logoBase64 = 'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAA...';

<img src={logoBase64} width={80} height={80} />
```

### Avatar/Profile Images

```typescript
<div style={{ display: 'flex', alignItems: 'center' }}>
  <img
    src={author.avatarUrl}
    width={80}
    height={80}
    style={{
      borderRadius: 40, // Make circular
      border: '4px solid white',
    }}
  />
  <div style={{ marginLeft: 20 }}>
    <p style={{ fontSize: 32, fontWeight: 'bold' }}>{author.name}</p>
    <p style={{ fontSize: 24, opacity: 0.8 }}>@{author.username}</p>
  </div>
</div>
```

## Real-World Templates

### Blog Post Template

```typescript
// app/blog/[slug]/opengraph-image.tsx
import { ImageResponse } from 'next/og';

export const runtime = 'edge';
export const size = { width: 1200, height: 630 };
export const contentType = 'image/png';

export default async function Image({ params }: { params: Promise<{ slug: string }> }) {
  const { slug } = await params;
  const post = await getPost(slug);

  return new ImageResponse(
    (
      <div
        style={{
          background: 'linear-gradient(135deg, #667eea 0%, #764ba2 100%)',
          width: '100%',
          height: '100%',
          display: 'flex',
          flexDirection: 'column',
          padding: '60px',
          color: 'white',
        }}
      >
        {/* Logo */}
        <div style={{ display: 'flex', alignItems: 'center', marginBottom: 40 }}>
          <img src="https://acme.com/logo-white.png" width={60} height={60} />
          <span style={{ fontSize: 32, marginLeft: 20, fontWeight: 600 }}>
            Acme Blog
          </span>
        </div>

        {/* Title */}
        <h1
          style={{
            fontSize: 64,
            fontWeight: 'bold',
            lineHeight: 1.2,
            marginBottom: 30,
            maxWidth: 1000,
          }}
        >
          {post.title}
        </h1>

        {/* Metadata */}
        <div
          style={{
            display: 'flex',
            alignItems: 'center',
            marginTop: 'auto',
          }}
        >
          <img
            src={post.author.avatar}
            width={50}
            height={50}
            style={{ borderRadius: 25, border: '2px solid white' }}
          />
          <div style={{ display: 'flex', flexDirection: 'column', marginLeft: 15 }}>
            <span style={{ fontSize: 24, fontWeight: 600 }}>{post.author.name}</span>
            <span style={{ fontSize: 20, opacity: 0.9 }}>
              {formatDate(post.publishedAt)} • {post.readingTime} min read
            </span>
          </div>
        </div>

        {/* Category Badge */}
        <div
          style={{
            position: 'absolute',
            top: 60,
            right: 60,
            backgroundColor: 'rgba(255, 255, 255, 0.2)',
            padding: '10px 20px',
            borderRadius: 20,
            fontSize: 24,
            fontWeight: 600,
          }}
        >
          {post.category}
        </div>
      </div>
    ),
    {
      ...size,
    }
  );
}
```

### Product Template

```typescript
// app/products/[id]/opengraph-image.tsx
export default async function Image({ params }: { params: Promise<{ id: string }> }) {
  const { id } = await params;
  const product = await getProduct(id);

  return new ImageResponse(
    (
      <div
        style={{
          backgroundColor: '#f9fafb',
          width: '100%',
          height: '100%',
          display: 'flex',
          padding: '60px',
        }}
      >
        {/* Product Image */}
        <div
          style={{
            flex: 1,
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            backgroundColor: 'white',
            borderRadius: 20,
            padding: 40,
          }}
        >
          <img
            src={product.image}
            width={400}
            height={400}
            style={{ objectFit: 'contain' }}
          />
        </div>

        {/* Product Info */}
        <div
          style={{
            flex: 1,
            display: 'flex',
            flexDirection: 'column',
            justifyContent: 'center',
            marginLeft: 60,
          }}
        >
          <h1 style={{ fontSize: 56, fontWeight: 'bold', marginBottom: 20 }}>
            {product.name}
          </h1>

          <p style={{ fontSize: 28, color: '#6b7280', marginBottom: 30 }}>
            {product.description}
          </p>

          <div style={{ display: 'flex', alignItems: 'baseline' }}>
            <span style={{ fontSize: 72, fontWeight: 'bold', color: '#10b981' }}>
              ${product.price}
            </span>
            {product.originalPrice && (
              <span
                style={{
                  fontSize: 36,
                  color: '#9ca3af',
                  textDecoration: 'line-through',
                  marginLeft: 20,
                }}
              >
                ${product.originalPrice}
              </span>
            )}
          </div>

          {product.inStock ? (
            <div
              style={{
                display: 'flex',
                alignItems: 'center',
                marginTop: 30,
                fontSize: 24,
                color: '#10b981',
              }}
            >
              ✓ In Stock
            </div>
          ) : (
            <div
              style={{
                display: 'flex',
                alignItems: 'center',
                marginTop: 30,
                fontSize: 24,
                color: '#ef4444',
              }}
            >
              Out of Stock
            </div>
          )}
        </div>

        {/* Logo */}
        <img
          src="https://acme.com/logo.png"
          width={60}
          height={60}
          style={{ position: 'absolute', top: 30, right: 30 }}
        />
      </div>
    ),
    {
      width: 1200,
      height: 630,
    }
  );
}
```

### Event Template

```typescript
export default async function Image({ params }: { params: Promise<{ id: string }> }) {
  const { id } = await params;
  const event = await getEvent(id);

  return new ImageResponse(
    (
      <div
        style={{
          backgroundImage: `url(${event.coverImage})`,
          backgroundSize: 'cover',
          width: '100%',
          height: '100%',
          display: 'flex',
          flexDirection: 'column',
          position: 'relative',
        }}
      >
        {/* Overlay */}
        <div
          style={{
            position: 'absolute',
            inset: 0,
            background: 'linear-gradient(to bottom, rgba(0,0,0,0.4), rgba(0,0,0,0.8))',
          }}
        />

        {/* Content */}
        <div
          style={{
            display: 'flex',
            flexDirection: 'column',
            justifyContent: 'flex-end',
            padding: 60,
            color: 'white',
            zIndex: 10,
            height: '100%',
          }}
        >
          <h1 style={{ fontSize: 72, fontWeight: 'bold', marginBottom: 20 }}>
            {event.title}
          </h1>

          <div style={{ display: 'flex', fontSize: 32, gap: 30 }}>
            <div style={{ display: 'flex', alignItems: 'center' }}>
              📅 {formatDate(event.date)}
            </div>
            <div style={{ display: 'flex', alignItems: 'center' }}>
              📍 {event.location}
            </div>
            <div style={{ display: 'flex', alignItems: 'center' }}>
              👥 {event.attendees} attending
            </div>
          </div>
        </div>
      </div>
    ),
    {
      width: 1200,
      height: 630,
    }
  );
}
```

## Performance Optimization

### Edge Runtime (Required)

```typescript
// ✅ MUST use Edge Runtime
export const runtime = 'edge';

// ❌ Node.js runtime NOT supported
// export const runtime = 'nodejs'; // Won't work
```

**Why Edge Runtime**:
- 5x faster than Node.js serverless
- Global deployment (low latency worldwide)
- Smaller bundle size
- Better cold start performance

### Caching

**Automatic**: Platforms cache OG images automatically.

**Force Revalidation** (if needed):
```typescript
// app/blog/[slug]/opengraph-image.tsx
export const revalidate = 3600; // Revalidate every hour

// Or: Revalidate on-demand
export const revalidate = false; // Cache indefinitely
```

**Cache Headers**:
```typescript
export async function GET(request: NextRequest) {
  const imageResponse = new ImageResponse(/* ... */);

  // Add cache headers manually (if needed)
  return new Response(imageResponse.body, {
    headers: {
      'Content-Type': 'image/png',
      'Cache-Control': 'public, max-age=31536000, immutable',
    },
  });
}
```

### Font Loading Optimization

**Problem**: Fetching fonts on every request is slow.

**Solution 1**: Bundle fonts locally.
```typescript
// Better: Import from local file
const fontData = await fetch(
  new URL('../../../assets/Inter-Bold.ttf', import.meta.url)
).then((res) => res.arrayBuffer());
```

**Solution 2**: Use system fonts (fastest).
```typescript
<div style={{ fontFamily: 'system-ui, -apple-system, sans-serif' }}>
  System Font (no loading required)
</div>
```

### Image Loading Optimization

**Use CDN**: Host images on CDN for faster loading.

```typescript
// ✅ Good: Images on CDN
<img src="https://cdn.acme.com/logo.png" />

// ❌ Slow: Images on slow server
<img src="https://slow-server.com/logo.png" />
```

**Optimize Image Sizes**: Use appropriately sized images.

```typescript
// ✅ Good: Reasonable size
<img src="logo.png" width={80} height={80} />

// ❌ Bad: Unnecessarily large image
<img src="huge-4k-logo.png" width={80} height={80} />
```

## Debugging & Testing

### Local Testing

**View in Browser**:
```
http://localhost:3000/api/og
http://localhost:3000/blog/my-post/opengraph-image
```

**View Source**:
```html
<meta property="og:image" content="http://localhost:3000/api/og?title=..." />
```

### Vercel OG Playground

**URL**: https://og-playground.vercel.app/

**Use For**:
- Test ImageResponse code interactively
- Preview different layouts
- Experiment with fonts and styling
- Debug rendering issues

### Platform Validators

**Facebook Sharing Debugger**:
- Preview how image appears on Facebook
- Force re-scrape if cached

**Twitter Card Validator**:
- Preview how image appears on Twitter
- Validate dimensions and format

### Common Issues

**Issue: Image Not Rendering**

**Checklist**:
- [ ] Using Edge Runtime (`export const runtime = 'edge'`)
- [ ] ImageResponse imported from `next/og` (App Router) not `@vercel/og`
- [ ] Image dimensions set (width, height)
- [ ] All image URLs are absolute (https://...)
- [ ] Fonts loaded correctly (if using custom fonts)

**Issue: Fonts Not Showing**

**Solution**:
```typescript
// ✅ Correct: Load font data
const fontData = await fetch(url).then(res => res.arrayBuffer());

// ✅ Correct: Pass to fonts array
fonts: [{ name: 'Inter', data: fontData }]

// ✅ Correct: Use in style
style={{ fontFamily: 'Inter' }} // Must match name
```

**Issue: Layout Broken**

**Remember**: Limited CSS support (Flexbox only).

**Supported**:
- display: 'flex'
- flexDirection, alignItems, justifyContent
- padding, margin
- width, height
- backgroundColor, color

**NOT Supported**:
- display: 'grid', 'block', 'inline'
- position: 'relative', 'absolute' (limited support)
- transform, transition, animation
- Complex selectors, pseudo-elements

## Best Practices

### Design Best Practices

- [ ] Keep text large (40px+ for readability)
- [ ] Use high contrast (ensure text is readable)
- [ ] Include branding (logo, colors)
- [ ] Keep design simple (complex layouts may break)
- [ ] Test on multiple platforms (Facebook, Twitter, LinkedIn)
- [ ] Use safe zones (avoid edges for important content)
- [ ] Limit text lines (3-4 lines max for titles)
- [ ] Use consistent design system (colors, fonts, spacing)

### Performance Best Practices

- [ ] Use Edge Runtime
- [ ] Bundle fonts locally (don't fetch from external URLs on every request)
- [ ] Optimize image sizes
- [ ] Use CDN for remote images
- [ ] Set appropriate cache headers
- [ ] Consider fallback to static images for very high traffic

### Code Best Practices

- [ ] Use file-based convention (opengraph-image.tsx) when possible
- [ ] Extract reusable templates into components
- [ ] Handle missing data gracefully
- [ ] Use TypeScript for type safety
- [ ] Test locally before deploying
- [ ] Document template customization options

## Troubleshooting

### Image Not Showing in Social Previews

1. Check if image URL is accessible: Visit URL in browser
2. Verify absolute URLs (not relative)
3. Clear social platform cache (use validators)
4. Check image dimensions (1200x630 recommended)
5. Verify Edge Runtime is set
6. Check server logs for errors

### Slow Generation Times

1. Use Edge Runtime (fastest)
2. Bundle fonts locally (don't fetch externally)
3. Optimize remote image sizes
4. Simplify layout (complex layouts = slower)
5. Use caching

### Fonts Not Loading

1. Verify font file exists
2. Check font data is arrayBuffer (not string)
3. Match fontFamily name in style
4. Ensure font supports characters used
5. Try system fonts for testing

## Related Skills

- `nextjs-seo-metadata` - Core Next.js metadata API
- `open-graph-twitter` - Open Graph and Twitter Cards fundamentals
- `seo-validation-testing` - Testing and validation tools

## Sources & References

### Official Documentation

- [Functions: ImageResponse | Next.js](https://nextjs.org/docs/app/api-reference/functions/image-response)
- [Getting Started: Metadata and OG images](https://nextjs.org/docs/app/getting-started/metadata-and-og-images)
- [Metadata Files: opengraph-image](https://nextjs.org/docs/app/api-reference/file-conventions/metadata/opengraph-image)

### Implementation Guides

- [Complete Guide: Dynamic OG Image Generation for Next.js 15](https://www.buildwithmatija.com/blog/complete-guide-dynamic-og-image-generation-for-next-js-15)
- [Introducing OG Image Generation - Vercel](https://vercel.com/blog/introducing-vercel-og-image-generation-fast-dynamic-social-card-images)
- [How we developed our method to generate dynamic OG Images](https://treblle.com/blog/dynamic-og-image-generation-nextjs-method)
- [Dynamic OG Images in Next.js: Boost Social Sharing & SEO](https://www.f22labs.com/blogs/boost-site-engagement-with-dynamic-open-graph-images-in-next-js/)
- [Generating Dynamic OG Images For Your Blog With Vercel OG](https://konstantin.digital/blog/generating-dynamic-og-images-with-vercel-og)

### Tools

- [OG Playground - Vercel](https://og-playground.vercel.app/) - Interactive ImageResponse testing
- [Open Graph Image as a Service](https://github.com/vercel/og-image) - Vercel's open source OG image generator

---

**Last Updated**: January 10, 2026
**Knowledge Base**: Next.js 16 ImageResponse API + Vercel OG documentation
**Confidence Level**: High (based on official API docs and production implementations)
