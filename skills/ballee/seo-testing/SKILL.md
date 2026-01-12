# SEO Testing Skill

Comprehensive SEO testing and validation for Next.js applications.

## When to Use

- Before deploying SEO changes to production
- After adding new pages or modifying metadata
- When implementing structured data (JSON-LD)
- During regular SEO audits
- To prevent SEO regressions

## Quick Start

```bash
# Run automated tests
pnpm seo:test              # Playwright tests (30+ tests)
pnpm seo:validate          # Validate local server
pnpm seo:validate:prod     # Validate production

# Test specific areas
pnpm test:playwright e2e/seo/metadata.spec.ts
pnpm test:playwright e2e/seo/structured-data.spec.ts
pnpm test:playwright e2e/seo/social-sharing.spec.ts
```

## Test Coverage

### 1. Metadata Tests (`e2e/seo/metadata.spec.ts`)

**What's Tested**:
- Title tags (presence, length <60 chars)
- Meta descriptions (presence, 50-160 chars)
- Canonical URLs (presence, HTTPS)
- Robots directives (index/follow)
- Viewport meta tag (mobile SEO)

**Pages Validated**: Home, Services, Pricing, About, FAQ, Contact, Privacy, Terms, Cookie Policy

**Example Test**:
```typescript
test('Page has proper title tag', async ({ page }) => {
  await page.goto('/services');
  const title = await page.title();

  expect(title).toBeTruthy();
  expect(title.length).toBeGreaterThan(0);
  expect(title.length).toBeLessThanOrEqual(60);
});
```

### 2. Structured Data Tests (`e2e/seo/structured-data.spec.ts`)

**What's Tested**:
- JSON-LD syntax validation
- Organization schema (all pages)
- WebSite schema (home page)
- FAQPage schema (FAQ page)
- BreadcrumbList schema (applicable pages)
- HTTPS URL validation
- XSS prevention (no dangerous patterns)

**Example Test**:
```typescript
test('FAQ page has FAQPage schema', async ({ page }) => {
  await page.goto('/faq');

  const schemas = await page.evaluate(() => {
    const scripts = document.querySelectorAll('script[type="application/ld+json"]');
    return Array.from(scripts).map(s => JSON.parse(s.textContent));
  });

  const faqSchema = schemas.find(s => s['@type'] === 'FAQPage');
  expect(faqSchema).toBeTruthy();
  expect(faqSchema.mainEntity).toBeTruthy();
  expect(Array.isArray(faqSchema.mainEntity)).toBe(true);
});
```

### 3. Social Sharing Tests (`e2e/seo/social-sharing.spec.ts`)

**What's Tested**:
- Open Graph tags (og:title, og:description, og:image, og:type, og:url)
- Twitter Card tags (twitter:card, twitter:title, twitter:image)
- Image dimensions (recommended: 1200x630)
- OG/Twitter consistency
- Image format validation

**Example Test**:
```typescript
test('Page has og:title', async ({ page }) => {
  await page.goto('/');

  const ogTitle = await page
    .locator('meta[property="og:title"]')
    .getAttribute('content');

  expect(ogTitle).toBeTruthy();
  expect(ogTitle.length).toBeGreaterThan(0);
});
```

## Validation Script (`scripts/validate-seo.ts`)

**Pre-deployment validation tool** that checks SEO health across all pages.

**What It Validates**:
- Title tag (length, presence)
- Meta description (length, presence)
- Canonical URL (HTTPS, presence)
- Viewport meta tag
- Open Graph tags (all required)
- Twitter Card tags
- JSON-LD syntax

**Usage**:
```bash
# Validate local dev server (default: http://localhost:3012)
pnpm seo:validate

# Validate custom URL
pnpm seo:validate --url=https://staging.ballee.app

# Validate production
pnpm seo:validate:prod
```

**Output Example**:
```
🔍 Validating SEO for http://localhost:3012

Checking /... ✅ PASS
Checking /services... ✅ PASS
Checking /pricing... ⚠️  WARNINGS

============================================================
📊 SEO VALIDATION REPORT
============================================================
Total Pages: 9
✅ Passed: 8 (89%)
❌ Failed: 1 (11%)
============================================================

📄 /pricing
  ⚠️  WARNINGS:
     • Description too short (recommended: 50-160 chars)
     • Missing og:image dimensions

============================================================
```

## Testing Workflow

### Pre-Commit (Local)

```bash
# 1. Start dev server
pnpm dev

# 2. Run SEO tests
pnpm seo:test

# 3. Validate pages
pnpm seo:validate
```

### Pre-Deployment (Staging)

```bash
# 1. Deploy to staging
git push origin feat/my-branch

# 2. Validate staging
pnpm seo:validate --url=https://staging.ballee.app

# 3. Manual validation
# - Facebook Sharing Debugger: https://developers.facebook.com/tools/debug/
# - Twitter Card Validator: https://cards-dev.twitter.com/validator
# - Google Rich Results Test: https://search.google.com/test/rich-results
```

### Post-Deployment (Production)

```bash
# 1. Validate production
pnpm seo:validate:prod

# 2. Spot-check key pages
# - Home page
# - Blog posts
# - Dancer profiles

# 3. Clear social platform caches
# - Facebook Sharing Debugger (scrape again)
# - Twitter Card Validator (preview card)
```

## CI/CD Integration

### GitHub Actions Example

```yaml
name: SEO Tests

on:
  pull_request:
    paths:
      - 'apps/web/app/**'
      - 'apps/web/lib/seo/**'

jobs:
  seo-validation:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: pnpm/action-setup@v2
      - uses: actions/setup-node@v4
        with:
          node-version: 20
          cache: 'pnpm'

      - name: Install dependencies
        run: pnpm install --frozen-lockfile

      - name: Start dev server
        run: pnpm dev &
        working-directory: apps/web

      - name: Wait for server
        run: sleep 10

      - name: Run SEO validation
        run: pnpm seo:validate
        working-directory: apps/web

      - name: Run SEO Playwright tests
        run: pnpm seo:test
        working-directory: apps/web
```

## Common Issues & Fixes

### Issue: "Missing canonical URL"

**Fix**: Add canonical to page metadata
```typescript
export const generateMetadata = () => {
  return {
    title: 'Page Title',
    description: 'Page description',
    alternates: {
      canonical: '/page-path',  // Add this
    },
  };
};
```

### Issue: "Description too long"

**Fix**: Trim description to ≤160 characters
```typescript
const description = 'Keep descriptions under 160 chars for optimal display.';
```

### Issue: "Invalid JSON-LD syntax"

**Fix**: Use StructuredData component (prevents XSS)
```typescript
import { StructuredData } from '~/components/seo/structured-data';

const schema = {
  '@context': 'https://schema.org',
  '@type': 'Organization',
  name: 'Company Name',
};

// In component
<StructuredData data={schema} />
```

### Issue: "OG image not appearing on social platforms"

**Fixes**:
1. Clear platform cache (Facebook Sharing Debugger)
2. Verify image is absolute URL (https://...)
3. Check image dimensions (recommended: 1200x630px)
4. Ensure image is publicly accessible
5. Test opengraph-image.tsx runtime: 'edge'

### Issue: "Dynamic OG images not generating"

**Fixes**:
1. Verify @vercel/og is installed
2. Check opengraph-image.tsx has `runtime = 'edge'`
3. Verify font URLs are accessible
4. Check browser console for errors
5. Test image generation: `/page/opengraph-image`

## SEO Checklist

Use this checklist before deploying SEO changes:

**Metadata**:
- [ ] All pages have title tags (<60 chars)
- [ ] All pages have meta descriptions (50-160 chars)
- [ ] All pages have canonical URLs
- [ ] Robots meta tags set correctly
- [ ] Viewport meta tag present

**Structured Data**:
- [ ] JSON-LD syntax is valid
- [ ] All schemas have @context and @type
- [ ] Required properties present for each schema type
- [ ] URLs use HTTPS (not HTTP)

**Social Sharing**:
- [ ] og:title present on all pages
- [ ] og:description present on all pages
- [ ] og:image present on all pages
- [ ] og:type correct for page type
- [ ] twitter:card present
- [ ] OG images have proper dimensions (1200x630)

**Dynamic OG Images**:
- [ ] Blog posts have opengraph-image.tsx
- [ ] Dancer profiles have opengraph-image.tsx
- [ ] Images render correctly (test in production)
- [ ] Fonts load properly

**Testing**:
- [ ] `pnpm seo:test` passes
- [ ] `pnpm seo:validate` passes
- [ ] Manual test on Facebook Sharing Debugger
- [ ] Manual test on Twitter Card Validator

## Manual Testing Tools

### Facebook Sharing Debugger
**URL**: https://developers.facebook.com/tools/debug/

**Use Case**: Test Open Graph images and metadata on Facebook/LinkedIn

**Steps**:
1. Enter page URL
2. Click "Scrape Again" to refresh cache
3. Verify image, title, description

### Twitter Card Validator
**URL**: https://cards-dev.twitter.com/validator

**Use Case**: Test Twitter Card metadata and images

**Steps**:
1. Enter page URL
2. Click "Preview Card"
3. Verify card type, image, title, description

### Google Rich Results Test
**URL**: https://search.google.com/test/rich-results

**Use Case**: Validate structured data for Google Search

**Steps**:
1. Enter page URL or paste HTML
2. Click "Test URL" / "Test Code"
3. Verify all schemas are valid
4. Check for errors/warnings

### Schema Markup Validator
**URL**: https://validator.schema.org/

**Use Case**: Validate JSON-LD against schema.org specs

**Steps**:
1. Copy JSON-LD from page source
2. Paste into validator
3. Verify structure matches schema.org spec

## Best Practices

### 1. Metadata Length Limits

```typescript
// Title: 50-60 characters (optimal)
const title = 'Services - Ballee Platform Features'; // 36 chars ✅

// Description: 50-160 characters (optimal)
const description =
  'Discover how Ballee helps dancers find work and organizers find talent ' +
  'through our job marketplace and Fever show productions.'; // 141 chars ✅
```

### 2. Canonical URLs

```typescript
// Always use absolute paths
alternates: {
  canonical: '/services',  // ✅ Absolute path
}

// Or full URLs for cross-domain
alternates: {
  canonical: 'https://ballee.app/services',  // ✅ Full URL
}
```

### 3. Dynamic OG Images

```typescript
// opengraph-image.tsx
export const runtime = 'edge';  // Required!
export const size = {
  width: 1200,  // Recommended
  height: 630,
};
export const contentType = 'image/png';

export default async function Image({ params }) {
  // Generate image with @vercel/og
  return new ImageResponse(/* ... */);
}
```

### 4. Structured Data

```typescript
// Always use StructuredData component
import { StructuredData } from '~/components/seo/structured-data';

const schema = {
  '@context': 'https://schema.org',
  '@type': 'Organization',
  name: 'Company Name',
  url: 'https://example.com',
};

<StructuredData data={schema} />  // XSS-safe
```

### 5. Testing Before Deployment

```bash
# 1. Run automated tests
pnpm seo:test

# 2. Validate all pages
pnpm seo:validate

# 3. If all pass, commit and push
git add .
git commit -m "feat: update SEO metadata"
git push

# 4. After deployment, validate production
pnpm seo:validate:prod

# 5. Clear social platform caches
# - Facebook Sharing Debugger
# - Twitter Card Validator
```

## Resources

### Documentation
- [Next.js Metadata API](https://nextjs.org/docs/app/api-reference/functions/generate-metadata)
- [Open Graph Protocol](https://ogp.me/)
- [Schema.org](https://schema.org/)
- [Twitter Cards](https://developer.twitter.com/en/docs/twitter-for-websites/cards/overview/abouts-cards)
- [SEO Testing Guide](/docs/seo-testing-guide.md)

### Related Skills
- `nextjs-seo-metadata` - Comprehensive metadata patterns
- `open-graph-twitter` - Social sharing implementation
- `og-image-generation` - Dynamic OG image creation
- `structured-data-jsonld` - JSON-LD schemas
- `sitemap-canonical-seo` - Sitemaps and canonicals
- `seo-validation-testing` - Advanced testing strategies

## Examples

### Example 1: Test Page Metadata

```typescript
// e2e/seo/metadata.spec.ts
test('/about page has proper metadata', async ({ page }) => {
  await page.goto('/about');

  // Title
  const title = await page.title();
  expect(title).toBeTruthy();
  expect(title.length).toBeLessThanOrEqual(60);

  // Description
  const description = await page
    .locator('meta[name="description"]')
    .getAttribute('content');
  expect(description).toBeTruthy();
  expect(description.length).toBeGreaterThanOrEqual(50);
  expect(description.length).toBeLessThanOrEqual(160);

  // Canonical
  const canonical = await page
    .locator('link[rel="canonical"]')
    .getAttribute('href');
  expect(canonical).toBeTruthy();
  expect(canonical).toContain('/about');
});
```

### Example 2: Validate Structured Data

```typescript
// e2e/seo/structured-data.spec.ts
test('Home page has Organization schema', async ({ page }) => {
  await page.goto('/');

  const schemas = await page.evaluate(() => {
    const scripts = document.querySelectorAll(
      'script[type="application/ld+json"]'
    );
    return Array.from(scripts).map(s => JSON.parse(s.textContent));
  });

  const orgSchema = schemas.find(s => s['@type'] === 'Organization');
  expect(orgSchema).toBeTruthy();
  expect(orgSchema['@context']).toBe('https://schema.org');
  expect(orgSchema.name).toBe('Ballee');
  expect(orgSchema.url).toBeTruthy();
});
```

### Example 3: Test Social Sharing Tags

```typescript
// e2e/seo/social-sharing.spec.ts
test('Page has complete Open Graph tags', async ({ page }) => {
  await page.goto('/services');

  // OG Title
  const ogTitle = await page
    .locator('meta[property="og:title"]')
    .getAttribute('content');
  expect(ogTitle).toBeTruthy();

  // OG Description
  const ogDesc = await page
    .locator('meta[property="og:description"]')
    .getAttribute('content');
  expect(ogDesc).toBeTruthy();

  // OG Image
  const ogImage = await page
    .locator('meta[property="og:image"]')
    .getAttribute('content');
  expect(ogImage).toBeTruthy();

  // OG Type
  const ogType = await page
    .locator('meta[property="og:type"]')
    .getAttribute('content');
  expect(ogType).toBe('website');
});
```

### Example 4: Pre-Deployment Validation

```typescript
// scripts/validate-seo.ts (simplified)
async function validatePage(url: string) {
  const html = await fetch(url).then(r => r.text());
  const $ = cheerio.load(html);

  const errors = [];
  const warnings = [];

  // Title validation
  const title = $('title').text();
  if (!title) {
    errors.push('Missing title tag');
  } else if (title.length > 60) {
    warnings.push(`Title too long: ${title.length} chars`);
  }

  // Description validation
  const description = $('meta[name="description"]').attr('content');
  if (!description) {
    errors.push('Missing meta description');
  } else if (description.length > 160) {
    warnings.push(`Description too long: ${description.length} chars`);
  }

  // Canonical validation
  const canonical = $('link[rel="canonical"]').attr('href');
  if (!canonical) {
    warnings.push('Missing canonical URL');
  }

  return { errors, warnings };
}
```

## Summary

This skill provides:
- ✅ **30+ automated tests** covering metadata, structured data, and social sharing
- ✅ **Pre-deployment validation script** with detailed error reports
- ✅ **Complete testing workflow** from pre-commit to post-deployment
- ✅ **CI/CD integration examples** for automated SEO checks
- ✅ **Comprehensive documentation** with examples and best practices

**When to use**: Before every deployment that touches SEO, metadata, or page content. Run tests to ensure no regressions and optimal search engine/social media presence.
