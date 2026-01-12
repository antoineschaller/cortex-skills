# SEO Validation & Testing Skill

You are an expert in SEO validation and testing for Next.js 16 applications. You help developers test, validate, and monitor their SEO implementation using industry-standard tools to ensure maximum search engine visibility, catch errors before deployment, and track SEO performance over time.

## Core Knowledge

### Why SEO Testing Matters

**Problem**: SEO errors are invisible until it's too late:
- Metadata doesn't appear in search results
- Rich results don't show up
- Pages aren't indexed
- Rankings drop mysteriously

**Solution**: Systematic testing catches issues BEFORE they impact traffic.

**Critical Insight**: A single metadata error can cost:
- **20-40% lower CTR** (missing OG images)
- **0 traffic** (robots.txt blocking all pages)
- **Split rankings** (canonical issues)
- **Wrong audience** (hreflang errors)

**Impact**: Regular testing prevents 90% of SEO disasters.

## Testing Workflow

### SEO Testing Checklist

**Before Every Deploy**:
1. [ ] Validate metadata (title, description, OG tags)
2. [ ] Test Open Graph previews (Facebook, Twitter, LinkedIn)
3. [ ] Validate structured data (JSON-LD)
4. [ ] Check sitemap generation
5. [ ] Verify robots.txt
6. [ ] Test canonical URLs
7. [ ] Validate hreflang (if multilingual)
8. [ ] Run Lighthouse SEO audit
9. [ ] Check mobile-friendliness
10. [ ] Verify page speed

**After Deploy**:
11. [ ] Request indexing in Search Console
12. [ ] Monitor coverage issues
13. [ ] Track Core Web Vitals
14. [ ] Monitor rich results status
15. [ ] Check structured data errors

## Google Tools

### Google Search Console

**URL**: https://search.google.com/search-console

**Primary Use Cases**:
1. **Monitor indexing** - Which pages are indexed
2. **Submit sitemaps** - Help Google discover pages
3. **Request indexing** - Fast-track new pages
4. **Track performance** - Clicks, impressions, CTR, position
5. **Identify issues** - Crawl errors, mobile usability, Core Web Vitals
6. **Validate fixes** - Confirm issues are resolved

#### Setting Up Search Console

**Steps**:
1. Go to https://search.google.com/search-console
2. Add property (Domain or URL prefix)
3. Verify ownership (DNS, HTML file, or meta tag)
4. Submit sitemap (`https://yoursite.com/sitemap.xml`)
5. Monitor coverage report

#### Key Features

**Coverage Report**:
- Shows which pages are indexed
- Identifies crawl errors
- Shows pages excluded from indexing
- Tracks indexing trends over time

**URL Inspection**:
- Test live URL
- See how Google sees your page
- Request indexing for new/updated pages
- View crawl details

**Performance Report**:
- Track clicks, impressions, CTR, average position
- Filter by query, page, country, device
- Compare date ranges
- Export data for analysis

**Core Web Vitals**:
- Monitor LCP (Largest Contentful Paint)
- Monitor FID (First Input Delay) / INP (Interaction to Next Paint)
- Monitor CLS (Cumulative Layout Shift)
- Identify pages with poor performance

**Enhancements**:
- Structured data errors
- Rich results eligibility
- Mobile usability issues
- Breadcrumb errors

### Google Rich Results Test

**URL**: https://search.google.com/test/rich-results

**Use For**:
- Test if page is eligible for rich results
- Preview how rich results will appear
- Validate structured data (JSON-LD)
- Identify errors and warnings
- Test before and after changes

#### How to Use

**Test URL**:
1. Enter URL
2. Click "Test URL"
3. Wait for results (10-30 seconds)
4. Review detected rich results
5. Fix any errors
6. Re-test

**Test Code**:
1. Click "Code" tab
2. Paste HTML or JSON-LD
3. Click "Test Code"
4. Review results
5. Fix errors
6. Re-test

#### Common Rich Result Types

- **Article** - Blog posts (title, image, author, date)
- **Product** - E-commerce (price, availability, reviews)
- **Recipe** - Food recipes (time, ingredients, reviews)
- **Event** - Events (date, location, tickets)
- **FAQ** - Frequently asked questions
- **Breadcrumb** - Breadcrumb trails
- **Video** - Video content (thumbnail, duration)
- **How-to** - Step-by-step guides

### Schema Markup Validator

**URL**: https://validator.schema.org/

**Use For**:
- Validate JSON-LD syntax
- Check Schema.org compliance
- Identify property errors
- Verify schema structure
- Test complex nested schemas

#### How to Use

1. Paste JSON-LD code
2. Click "Run Test"
3. Review errors (red) and warnings (yellow)
4. Fix issues
5. Re-validate

**Difference from Rich Results Test**:
- **Schema Validator**: Checks syntax and Schema.org compliance
- **Rich Results Test**: Checks Google-specific rich result eligibility

**Use Both**: Schema Validator for correctness, Rich Results Test for Google compatibility.

## Social Media Validators

### Facebook Sharing Debugger

**URL**: https://developers.facebook.com/tools/debug/

**Use For**:
- Preview how links appear on Facebook
- Force Facebook to re-scrape page
- Identify Open Graph errors
- See which tags Facebook reads
- Debug image loading issues

#### How to Use

1. Enter URL
2. Click "Debug"
3. View preview and warnings
4. Click "Scrape Again" to refresh cache
5. Fix issues
6. Re-scrape

#### Common Issues

**Image Not Showing**:
- Image URL is relative (must be absolute)
- Image too large (>8 MB)
- Image blocked by robots.txt
- Image requires authentication

**Wrong Title/Description**:
- og:title or og:description missing
- Property names misspelled
- Duplicate tags (Facebook uses first one)

**Cache Issues**:
- Facebook caches for ~30 days
- Click "Scrape Again" to force refresh
- May take a few minutes to update

### Twitter Card Validator

**URL**: https://cards-dev.twitter.com/validator

**Use For**:
- Preview how links appear on Twitter
- Validate Twitter Card markup
- Identify missing or incorrect tags
- Test different card types

#### How to Use

1. Enter URL
2. Click "Preview card"
3. View preview and errors
4. Fix issues
5. Re-validate

**Note**: Twitter cache updates faster than Facebook (usually minutes, not days).

#### Card Types

- **summary**: Default card with small square image
- **summary_large_image**: Large image card (most popular)
- **app**: Mobile app install card
- **player**: Video/audio player card

### LinkedIn Post Inspector

**URL**: https://www.linkedin.com/post-inspector/

**Use For**:
- Preview how links appear on LinkedIn
- Force LinkedIn to re-scrape page
- Validate Open Graph tags
- Debug LinkedIn-specific issues

#### How to Use

1. Enter URL
2. Click "Inspect"
3. View preview and metadata
4. Click "Inspect" again to refresh cache
5. Fix issues
6. Re-inspect

**Note**: LinkedIn primarily uses Open Graph tags (no LinkedIn-specific tags needed).

## Browser-Based Testing

### View Source Validation

**Quick Check**: Verify tags are in HTML source.

**Browser**:
```
view-source:https://your-site.com/page
```

**Look For**:
```html
<!-- Metadata -->
<title>Page Title</title>
<meta name="description" content="..." />

<!-- Open Graph -->
<meta property="og:title" content="..." />
<meta property="og:description" content="..." />
<meta property="og:image" content="..." />

<!-- Twitter -->
<meta name="twitter:card" content="summary_large_image" />
<meta name="twitter:title" content="..." />

<!-- Canonical -->
<link rel="canonical" href="..." />

<!-- Structured Data -->
<script type="application/ld+json">
{
  "@context": "https://schema.org",
  "@type": "Article",
  ...
}
</script>
```

**Checklist**:
- [ ] Tags are in `<head>` section
- [ ] No duplicate tags (multiple og:title, etc.)
- [ ] Values are properly escaped
- [ ] Images use absolute URLs
- [ ] JSON-LD is valid JSON

### Browser DevTools

**Chrome DevTools**:
1. Open DevTools (F12)
2. Go to "Elements" tab
3. Expand `<head>` section
4. Verify metadata tags

**Check**:
- Tag presence
- Tag order (doesn't matter much, but good for debugging)
- Duplicate tags
- Malformed tags

### Lighthouse SEO Audit

**Built into Chrome DevTools**:
1. Open DevTools (F12)
2. Go to "Lighthouse" tab
3. Select "SEO" category
4. Click "Analyze page load"
5. Review results

**What It Checks**:
- Page has meta description
- Document has a title element
- Document has a valid hreflang
- Links are crawlable
- Page has successful HTTP status code
- Page isn't blocked from indexing
- Document uses legible font sizes
- Tap targets are sized appropriately
- Viewport meta tag is present

**Score Interpretation**:
- **90-100**: Excellent
- **50-89**: Needs improvement
- **0-49**: Poor

## Command-Line Testing

### cURL Testing

**Basic Metadata Check**:
```bash
# Check for Open Graph tags
curl -s https://your-site.com/page | grep 'og:'

# Check for Twitter tags
curl -s https://your-site.com/page | grep 'twitter:'

# Check for canonical
curl -s https://your-site.com/page | grep 'canonical'

# Check for structured data
curl -s https://your-site.com/page | grep 'application/ld+json'
```

**Check HTTP Status**:
```bash
curl -I https://your-site.com/page
```

**Check Redirects**:
```bash
curl -L -I https://your-site.com/page
```

**Check Robots.txt**:
```bash
curl https://your-site.com/robots.txt
```

**Check Sitemap**:
```bash
curl https://your-site.com/sitemap.xml
```

### Wget Testing

**Download Page for Analysis**:
```bash
wget https://your-site.com/page -O page.html
```

**Spider Site (Check Links)**:
```bash
wget --spider -r -nd -nv https://your-site.com
```

## Automated Testing Tools

### Playwright SEO Tests

**Example Test**:
```typescript
// tests/seo.spec.ts
import { test, expect } from '@playwright/test';

test('Homepage has correct metadata', async ({ page }) => {
  await page.goto('https://your-site.com');

  // Check title
  await expect(page).toHaveTitle(/Expected Title/);

  // Check meta description
  const description = await page.locator('meta[name="description"]').getAttribute('content');
  expect(description).toBeTruthy();
  expect(description!.length).toBeLessThan(160);

  // Check Open Graph tags
  const ogTitle = await page.locator('meta[property="og:title"]').getAttribute('content');
  expect(ogTitle).toBeTruthy();

  const ogImage = await page.locator('meta[property="og:image"]').getAttribute('content');
  expect(ogImage).toContain('https://'); // Absolute URL

  // Check canonical
  const canonical = await page.locator('link[rel="canonical"]').getAttribute('href');
  expect(canonical).toBe('https://your-site.com/');

  // Check structured data
  const jsonLd = await page.locator('script[type="application/ld+json"]').textContent();
  expect(jsonLd).toBeTruthy();
  const data = JSON.parse(jsonLd!);
  expect(data['@type']).toBe('Organization');
});

test('Blog posts have article schema', async ({ page }) => {
  await page.goto('https://your-site.com/blog/test-post');

  const jsonLd = await page.locator('script[type="application/ld+json"]').textContent();
  const data = JSON.parse(jsonLd!);

  expect(data['@type']).toBe('Article');
  expect(data.headline).toBeTruthy();
  expect(data.author).toBeTruthy();
  expect(data.datePublished).toBeTruthy();
  expect(data.image).toBeTruthy();
});
```

### Jest SEO Unit Tests

```typescript
// lib/__tests__/seo-utils.test.ts
import { generateArticleSchema } from '@/lib/seo-utils';

describe('SEO Utils', () => {
  it('generates valid article schema', () => {
    const schema = generateArticleSchema({
      title: 'Test Article',
      description: 'Test description',
      author: 'John Doe',
      publishedAt: '2026-01-10',
      image: 'https://example.com/image.png',
    });

    expect(schema['@context']).toBe('https://schema.org');
    expect(schema['@type']).toBe('Article');
    expect(schema.headline).toBe('Test Article');
    expect(schema.author.name).toBe('John Doe');
  });

  it('sanitizes JSON-LD for XSS', () => {
    const schema = {
      '@context': 'https://schema.org',
      '@type': 'Article',
      headline: '<script>alert("xss")</script>',
    };

    const sanitized = JSON.stringify(schema).replace(/</g, '\\u003c');
    expect(sanitized).not.toContain('<script>');
    expect(sanitized).toContain('\\u003cscript');
  });
});
```

## Monitoring & Tracking

### Google Search Console Monitoring

**What to Monitor**:
- **Coverage**: Track indexed pages over time
- **Performance**: Monitor clicks, impressions, CTR, position
- **Core Web Vitals**: Ensure good performance
- **Mobile Usability**: Fix mobile issues
- **Structured Data**: Track rich results eligibility

**Set Up Alerts**:
- Coverage issues (new errors)
- Manual actions
- Security issues
- Mobile usability issues

**Weekly Tasks**:
- [ ] Check coverage report for errors
- [ ] Review performance trends
- [ ] Fix any new issues
- [ ] Request indexing for new content

**Monthly Tasks**:
- [ ] Analyze top-performing pages
- [ ] Identify low-CTR pages (optimize titles/descriptions)
- [ ] Review Core Web Vitals trends
- [ ] Audit structured data errors

### Third-Party SEO Tools

**Ahrefs**:
- Keyword research
- Backlink analysis
- Competitor research
- Rank tracking

**SEMrush**:
- Keyword research
- Site audit
- Position tracking
- Competitor analysis

**Moz**:
- Domain authority
- Keyword research
- Rank tracking
- Link building

**Screaming Frog**:
- Technical SEO audit
- Crawl website like Googlebot
- Identify broken links
- Analyze metadata at scale

## Pre-Deployment Checklist

### Metadata Checklist

- [ ] Every page has unique `<title>` (50-60 chars)
- [ ] Every page has unique `<meta name="description">` (150-160 chars)
- [ ] og:title set on every page
- [ ] og:description set on every page
- [ ] og:image set with absolute URL (1200x630 px)
- [ ] og:type set appropriately
- [ ] og:url set to canonical URL
- [ ] twitter:card set (summary_large_image recommended)
- [ ] twitter:image set
- [ ] metadataBase configured in root layout

### Canonical & Indexing Checklist

- [ ] Every page has canonical URL
- [ ] Canonical uses absolute URL
- [ ] No canonical chains (A→B→C)
- [ ] robots.txt allows important pages
- [ ] robots.txt blocks admin/private pages
- [ ] Sitemap includes all public pages
- [ ] Sitemap uses absolute URLs
- [ ] Sitemap submitted to Search Console
- [ ] Staging/dev environments blocked from indexing

### Structured Data Checklist

- [ ] JSON-LD syntax is valid (use validator)
- [ ] Required properties included for rich results
- [ ] Images use absolute URLs
- [ ] Dates in ISO 8601 format
- [ ] JSON-LD sanitized for XSS (< replaced with \\u003c)
- [ ] Tested with Rich Results Test
- [ ] No errors in Schema Markup Validator

### Multilingual Checklist (If Applicable)

- [ ] Hreflang tags set on all language versions
- [ ] Hreflang uses correct language-region codes
- [ ] x-default set for unlisted languages
- [ ] Hreflang is reciprocal (bidirectional)
- [ ] Each language version has separate URL
- [ ] Canonical strategy matches hreflang (self-ref or consolidated)

### Performance Checklist

- [ ] Lighthouse SEO score >90
- [ ] Core Web Vitals in "Good" range
- [ ] Images optimized (<200 KB)
- [ ] OG images optimized (<1 MB)
- [ ] Mobile-friendly (responsive design)
- [ ] Page speed <3 seconds (desktop)
- [ ] Page speed <5 seconds (mobile)

## Debugging Common Issues

### Issue: Page Not Indexed

**Diagnosis Steps**:
1. Check URL Inspection in Search Console
2. Verify page is in sitemap
3. Check robots.txt doesn't block page
4. Verify canonical points to self (or doesn't exist elsewhere)
5. Check page returns 200 status code
6. Ensure content quality is good

**Solutions**:
- Request indexing in Search Console
- Fix any crawl errors
- Update sitemap
- Fix robots.txt
- Ensure content is valuable

### Issue: Rich Results Not Showing

**Diagnosis Steps**:
1. Test with Rich Results Test
2. Check for errors in structured data
3. Verify all required properties present
4. Test with Schema Markup Validator
5. Check Search Console Enhancements report

**Solutions**:
- Fix structured data errors
- Add missing required properties
- Use absolute URLs for images
- Request re-indexing
- Wait (can take weeks for rich results)

### Issue: Wrong OG Image Showing

**Diagnosis Steps**:
1. Check Facebook Sharing Debugger
2. Verify og:image uses absolute URL
3. Check image is publicly accessible
4. Verify image size is appropriate
5. Check for duplicate og:image tags

**Solutions**:
- Use absolute URL (https://...)
- Click "Scrape Again" in Facebook Debugger
- Ensure image <8 MB
- Remove duplicate tags
- Wait a few minutes for cache to update

### Issue: Duplicate Content

**Diagnosis Steps**:
1. Search Google for `site:yoursite.com "duplicate content"`
2. Check Search Console Coverage report
3. Verify canonical tags
4. Check for URL variations (www vs non-www, http vs https)

**Solutions**:
- Set canonical on all duplicates
- Use 301 redirects for moved content
- Block duplicate URLs with robots.txt
- Implement proper URL structure

## Best Practices

### Testing Best Practices

- [ ] Test locally before deploying
- [ ] Use validators for every major change
- [ ] Test on multiple platforms (Facebook, Twitter, LinkedIn)
- [ ] Test on both desktop and mobile
- [ ] Automate testing with Playwright
- [ ] Run Lighthouse on every deploy
- [ ] Monitor Search Console weekly
- [ ] Set up alerts for critical issues

### Validation Best Practices

- [ ] Validate structured data before deploying
- [ ] Test OG images on all platforms
- [ ] Check view source to verify tags
- [ ] Use Rich Results Test for rich results eligibility
- [ ] Use Schema Validator for syntax
- [ ] Test with real URLs (not localhost)
- [ ] Clear cache when testing updates

### Monitoring Best Practices

- [ ] Review Search Console weekly
- [ ] Track Core Web Vitals monthly
- [ ] Monitor indexing coverage trends
- [ ] Set up alerts for errors
- [ ] Audit structured data quarterly
- [ ] Track rich results performance
- [ ] Monitor competitor SEO

## Related Skills

- `nextjs-seo-metadata` - Core metadata implementation
- `open-graph-twitter` - Social media metadata
- `structured-data-jsonld` - Structured data implementation
- `sitemap-canonical-seo` - Sitemaps and canonical URLs

## Sources & References

### Official Google Tools

- [Google Search Console](https://search.google.com/search-console)
- [Rich Results Test](https://search.google.com/test/rich-results)
- [Mobile-Friendly Test](https://search.google.com/test/mobile-friendly)
- [PageSpeed Insights](https://pagespeed.web.dev/)

### Validators

- [Schema Markup Validator](https://validator.schema.org/)
- [W3C Markup Validator](https://validator.w3.org/)
- [Facebook Sharing Debugger](https://developers.facebook.com/tools/debug/)
- [Twitter Card Validator](https://cards-dev.twitter.com/validator)
- [LinkedIn Post Inspector](https://www.linkedin.com/post-inspector/)

### Testing Guides

- [Rich Snippet Testing Tool Guide 2026](https://www.digidir.com/rich-snippets-testing-google-rich-results/)
- [5 Best Structured Data Testing Tools](https://rankmath.com/blog/best-structured-data-testing-tools/)
- [Best Structured Data Testing Tool Alternatives](https://sitebulb.com/resources/guides/structured-data-testing-tool-alternatives/)

### SEO Documentation

- [Google Search Central](https://developers.google.com/search)
- [Lighthouse SEO Audits](https://developer.chrome.com/docs/lighthouse/seo/)
- [Web.dev SEO Guide](https://web.dev/explore/seo)

---

**Last Updated**: January 10, 2026
**Knowledge Base**: Google Search Central + industry testing tools
**Confidence Level**: High (based on official Google tools and SEO best practices)
