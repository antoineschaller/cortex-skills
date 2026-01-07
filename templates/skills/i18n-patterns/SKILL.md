# Internationalization Patterns

Internationalization (i18n) and localization patterns for multi-language applications.

> **Template Usage:** Customize for your i18n library (react-i18next, next-intl, vue-i18n, etc.).

## File Structure

```
public/
└── locales/
    ├── en/
    │   ├── common.json      # Shared translations
    │   ├── auth.json        # Auth-related
    │   ├── dashboard.json   # Feature-specific
    │   └── errors.json      # Error messages
    ├── es/
    │   ├── common.json
    │   ├── auth.json
    │   └── ...
    └── fr/
        └── ...
```

## Translation File Format

```json
// public/locales/en/common.json
{
  "app": {
    "name": "My Application",
    "tagline": "Build something amazing"
  },
  "navigation": {
    "home": "Home",
    "dashboard": "Dashboard",
    "settings": "Settings",
    "logout": "Log out"
  },
  "actions": {
    "save": "Save",
    "cancel": "Cancel",
    "delete": "Delete",
    "edit": "Edit",
    "loading": "Loading..."
  },
  "validation": {
    "required": "This field is required",
    "email": "Please enter a valid email",
    "minLength": "Must be at least {{min}} characters"
  }
}

// public/locales/en/auth.json
{
  "login": {
    "title": "Welcome back",
    "subtitle": "Sign in to your account",
    "email": "Email address",
    "password": "Password",
    "submit": "Sign in",
    "forgotPassword": "Forgot your password?",
    "noAccount": "Don't have an account?",
    "signUp": "Sign up"
  },
  "errors": {
    "invalidCredentials": "Invalid email or password",
    "accountLocked": "Account temporarily locked. Try again in {{minutes}} minutes."
  }
}
```

## Key Naming Conventions

```json
// GOOD: Hierarchical, descriptive keys
{
  "user": {
    "profile": {
      "title": "Profile Settings",
      "name": "Full name",
      "email": "Email address"
    }
  }
}

// BAD: Flat, unclear keys
{
  "profile_title": "Profile Settings",
  "user_name": "Full name",
  "email_label": "Email address"
}

// Key naming rules:
// - Use camelCase for key names
// - Use dot notation for nesting
// - Group by feature/page
// - Keep keys semantic (what it represents, not where it's used)
```

## React i18next Setup

```typescript
// lib/i18n.ts
import i18n from 'i18next';
import { initReactI18next } from 'react-i18next';
import Backend from 'i18next-http-backend';
import LanguageDetector from 'i18next-browser-languagedetector';

i18n
  .use(Backend)
  .use(LanguageDetector)
  .use(initReactI18next)
  .init({
    fallbackLng: 'en',
    supportedLngs: ['en', 'es', 'fr', 'de'],
    defaultNS: 'common',
    ns: ['common', 'auth', 'dashboard', 'errors'],

    interpolation: {
      escapeValue: false, // React already escapes
    },

    detection: {
      order: ['cookie', 'localStorage', 'navigator'],
      caches: ['cookie'],
    },

    backend: {
      loadPath: '/locales/{{lng}}/{{ns}}.json',
    },
  });

export default i18n;
```

## Usage Patterns

```typescript
// Hook usage
import { useTranslation } from 'react-i18next';

function LoginForm() {
  const { t } = useTranslation('auth');

  return (
    <form>
      <h1>{t('login.title')}</h1>
      <label>{t('login.email')}</label>
      <input type="email" />
      <button>{t('login.submit')}</button>
    </form>
  );
}

// With interpolation
function WelcomeMessage({ name }: { name: string }) {
  const { t } = useTranslation();

  return <p>{t('welcome', { name })}</p>;
  // JSON: "welcome": "Hello, {{name}}!"
}

// Trans component for rich text
import { Trans } from 'react-i18next';

function Terms() {
  return (
    <Trans i18nKey="terms.agreement">
      By signing up, you agree to our
      <a href="/terms">Terms of Service</a>
      and <a href="/privacy">Privacy Policy</a>.
    </Trans>
  );
}
// JSON: "agreement": "By signing up, you agree to our <0>Terms of Service</0> and <1>Privacy Policy</1>."
```

## Pluralization Rules

Different languages have different pluralization rules. The CLDR (Unicode Common Locale Data Repository) defines 6 plural categories:

| Category | Description | Example Languages |
|----------|-------------|-------------------|
| `zero` | Zero items | Arabic, Latvian, Welsh |
| `one` | One item (singular) | Most languages |
| `two` | Two items (dual) | Arabic, Hebrew, Slovenian |
| `few` | Few items | Russian, Polish, Czech |
| `many` | Many items | Russian, Polish, Arabic |
| `other` | Default/remaining | All languages |

### English (Simple: one, other)

```json
{
  "items": {
    "count_one": "{{count}} item",
    "count_other": "{{count}} items"
  },
  "messages": {
    "unread_zero": "No unread messages",
    "unread_one": "{{count}} unread message",
    "unread_other": "{{count}} unread messages"
  }
}
```

### Russian (Complex: one, few, many, other)

```json
{
  "items": {
    "count_one": "{{count}} товар",      // 1, 21, 31...
    "count_few": "{{count}} товара",     // 2-4, 22-24...
    "count_many": "{{count}} товаров",   // 5-20, 25-30...
    "count_other": "{{count}} товаров"   // Fractions
  }
}
```

### Arabic (All 6 categories)

```json
{
  "items": {
    "count_zero": "لا توجد عناصر",        // 0
    "count_one": "عنصر واحد",             // 1
    "count_two": "عنصران",                // 2
    "count_few": "{{count}} عناصر",       // 3-10
    "count_many": "{{count}} عنصرًا",     // 11-99
    "count_other": "{{count}} عنصر"       // 100+
  }
}
```

### Usage

```typescript
t('items.count', { count: 0 });   // Uses _zero if available, else _other
t('items.count', { count: 1 });   // Uses _one
t('items.count', { count: 2 });   // Uses _two if available, else _other
t('items.count', { count: 5 });   // Uses _few or _many based on language rules
t('items.count', { count: 100 }); // Uses _many or _other

// Ordinals (1st, 2nd, 3rd...)
t('rank', { count: 1, ordinal: true });  // Requires ordinal plural rules
```

## Date, Time, and Number Formatting

### Comprehensive Intl Formatters

```typescript
// lib/formatters.ts

// Date formatting
export function formatDate(
  date: Date | string,
  locale: string,
  options: Intl.DateTimeFormatOptions = {}
): string {
  const d = typeof date === 'string' ? new Date(date) : date;
  return new Intl.DateTimeFormat(locale, {
    year: 'numeric',
    month: 'long',
    day: 'numeric',
    ...options,
  }).format(d);
}

// Relative time (e.g., "2 days ago", "in 3 hours")
export function formatRelativeTime(
  date: Date | string,
  locale: string
): string {
  const d = typeof date === 'string' ? new Date(date) : date;
  const now = new Date();
  const diffInSeconds = Math.floor((d.getTime() - now.getTime()) / 1000);

  const rtf = new Intl.RelativeTimeFormat(locale, { numeric: 'auto' });

  // Find the appropriate unit
  const units: [Intl.RelativeTimeFormatUnit, number][] = [
    ['year', 60 * 60 * 24 * 365],
    ['month', 60 * 60 * 24 * 30],
    ['week', 60 * 60 * 24 * 7],
    ['day', 60 * 60 * 24],
    ['hour', 60 * 60],
    ['minute', 60],
    ['second', 1],
  ];

  for (const [unit, seconds] of units) {
    if (Math.abs(diffInSeconds) >= seconds) {
      const value = Math.round(diffInSeconds / seconds);
      return rtf.format(value, unit);
    }
  }

  return rtf.format(0, 'second');
}

// Number formatting
export function formatNumber(
  value: number,
  locale: string,
  options: Intl.NumberFormatOptions = {}
): string {
  return new Intl.NumberFormat(locale, options).format(value);
}

// Currency formatting
export function formatCurrency(
  amount: number,
  locale: string,
  currency: string
): string {
  return new Intl.NumberFormat(locale, {
    style: 'currency',
    currency,
  }).format(amount);
}

// Compact notation (1K, 1M, etc.)
export function formatCompact(value: number, locale: string): string {
  return new Intl.NumberFormat(locale, {
    notation: 'compact',
    compactDisplay: 'short',
  }).format(value);
}

// Percentage
export function formatPercent(value: number, locale: string): string {
  return new Intl.NumberFormat(locale, {
    style: 'percent',
    minimumFractionDigits: 0,
    maximumFractionDigits: 1,
  }).format(value);
}

// List formatting (e.g., "A, B, and C")
export function formatList(
  items: string[],
  locale: string,
  type: 'conjunction' | 'disjunction' = 'conjunction'
): string {
  return new Intl.ListFormat(locale, {
    style: 'long',
    type,
  }).format(items);
}
```

### Usage Examples

```typescript
// Date
formatDate(new Date(), 'en-US');                    // "January 15, 2024"
formatDate(new Date(), 'de-DE');                    // "15. Januar 2024"
formatDate(new Date(), 'ja-JP', { dateStyle: 'full' }); // "2024年1月15日月曜日"

// Relative time
formatRelativeTime(yesterday, 'en');                 // "yesterday"
formatRelativeTime(twoDaysAgo, 'en');               // "2 days ago"
formatRelativeTime(nextWeek, 'fr');                 // "dans 7 jours"

// Currency
formatCurrency(1234.56, 'en-US', 'USD');            // "$1,234.56"
formatCurrency(1234.56, 'de-DE', 'EUR');            // "1.234,56 €"
formatCurrency(1234.56, 'ja-JP', 'JPY');            // "￥1,235"

// Compact
formatCompact(1500, 'en');                          // "1.5K"
formatCompact(1500000, 'en');                       // "1.5M"

// List
formatList(['Apple', 'Banana', 'Cherry'], 'en');    // "Apple, Banana, and Cherry"
formatList(['Apple', 'Banana', 'Cherry'], 'es');    // "Apple, Banana y Cherry"
```

### React Hook

```typescript
// hooks/useFormatter.ts
import { useTranslation } from 'react-i18next';
import { useMemo } from 'react';

export function useFormatter() {
  const { i18n } = useTranslation();
  const locale = i18n.language;

  return useMemo(() => ({
    date: (date: Date, options?: Intl.DateTimeFormatOptions) =>
      formatDate(date, locale, options),
    relativeTime: (date: Date) =>
      formatRelativeTime(date, locale),
    number: (value: number, options?: Intl.NumberFormatOptions) =>
      formatNumber(value, locale, options),
    currency: (amount: number, currency: string) =>
      formatCurrency(amount, locale, currency),
    compact: (value: number) =>
      formatCompact(value, locale),
    percent: (value: number) =>
      formatPercent(value, locale),
    list: (items: string[], type?: 'conjunction' | 'disjunction') =>
      formatList(items, locale, type),
  }), [locale]);
}

// Usage in component
function Stats() {
  const format = useFormatter();

  return (
    <div>
      <p>Users: {format.compact(1500000)}</p>
      <p>Revenue: {format.currency(50000, 'USD')}</p>
      <p>Growth: {format.percent(0.15)}</p>
      <p>Last updated: {format.relativeTime(lastUpdate)}</p>
    </div>
  );
}
```

## RTL (Right-to-Left) Support

### RTL Languages

```typescript
const RTL_LANGUAGES = ['ar', 'he', 'fa', 'ur', 'ps', 'sd', 'yi'];

export function isRTL(language: string): boolean {
  return RTL_LANGUAGES.includes(language.split('-')[0]);
}
```

### Document Direction

```typescript
// Apply direction to document root
useEffect(() => {
  const dir = isRTL(i18n.language) ? 'rtl' : 'ltr';
  document.documentElement.dir = dir;
  document.documentElement.lang = i18n.language;

  // Also useful for CSS-in-JS libraries
  document.body.setAttribute('data-direction', dir);
}, [i18n.language]);
```

### CSS Logical Properties (Recommended)

Instead of `left`/`right`, use logical properties that automatically flip for RTL:

```css
/* Physical properties (don't flip) */
.old-way {
  margin-left: 1rem;
  padding-right: 2rem;
  text-align: left;
  border-left: 1px solid;
}

/* Logical properties (automatically flip for RTL) */
.modern-way {
  margin-inline-start: 1rem;    /* left in LTR, right in RTL */
  padding-inline-end: 2rem;     /* right in LTR, left in RTL */
  text-align: start;            /* left in LTR, right in RTL */
  border-inline-start: 1px solid;
}

/* Block direction (vertical) */
.block-logical {
  margin-block-start: 1rem;     /* top */
  margin-block-end: 2rem;       /* bottom */
  padding-block: 1rem;          /* top and bottom */
}

/* Combined shorthand */
.shorthand {
  margin-inline: 1rem 2rem;     /* start end */
  padding-inline: 1rem;         /* both */
  inset-inline: 0;              /* left and right: 0 */
}
```

### Logical Properties Reference

| Physical | Logical (Inline) | Description |
|----------|------------------|-------------|
| `left` | `inset-inline-start` | Start of reading direction |
| `right` | `inset-inline-end` | End of reading direction |
| `margin-left` | `margin-inline-start` | Margin at start |
| `margin-right` | `margin-inline-end` | Margin at end |
| `padding-left` | `padding-inline-start` | Padding at start |
| `padding-right` | `padding-inline-end` | Padding at end |
| `border-left` | `border-inline-start` | Border at start |
| `text-align: left` | `text-align: start` | Align to start |
| `float: left` | `float: inline-start` | Float to start |

### RTL-Aware Icons

```tsx
// Icons that should flip in RTL
const FlippableIcon = ({ icon: Icon, ...props }) => {
  const { i18n } = useTranslation();
  const flip = isRTL(i18n.language);

  return (
    <Icon
      {...props}
      style={{
        transform: flip ? 'scaleX(-1)' : undefined,
        ...props.style,
      }}
    />
  );
};

// Icons that should NOT flip (e.g., checkmarks, arrows indicating action)
// Use without transformation

// Usage
<FlippableIcon icon={ChevronRightIcon} />  // Points left in RTL
<CheckIcon />  // Always points same way
```

## Server-Side i18n (Next.js App Router)

```typescript
// lib/i18n-settings.ts
export const languages = ['en', 'es', 'fr', 'ar'] as const;
export type Language = typeof languages[number];
export const defaultLanguage: Language = 'en';

// app/[locale]/layout.tsx
import { dir } from 'i18next';
import { languages, Language } from '@/lib/i18n-settings';

export async function generateStaticParams() {
  return languages.map((locale) => ({ locale }));
}

export default function RootLayout({
  children,
  params: { locale },
}: {
  children: React.ReactNode;
  params: { locale: Language };
}) {
  return (
    <html lang={locale} dir={dir(locale)}>
      <body>{children}</body>
    </html>
  );
}

// Server component translation
import { createInstance } from 'i18next';
import resourcesToBackend from 'i18next-resources-to-backend';
import { initReactI18next } from 'react-i18next/initReactI18next';

export async function useTranslation(
  locale: string,
  namespace: string = 'common'
) {
  const i18n = createInstance();

  await i18n
    .use(initReactI18next)
    .use(resourcesToBackend((lng: string, ns: string) =>
      import(`@/public/locales/${lng}/${ns}.json`)
    ))
    .init({
      lng: locale,
      fallbackLng: 'en',
      ns: namespace,
    });

  return {
    t: i18n.getFixedT(locale, namespace),
    i18n,
  };
}

// Usage in server component
export default async function Page({
  params: { locale },
}: {
  params: { locale: string };
}) {
  const { t } = await useTranslation(locale, 'common');

  return <h1>{t('title')}</h1>;
}
```

## Validation Scripts

### Complete Validation Script

```javascript
#!/usr/bin/env node
// scripts/validate-translations.js

const fs = require('fs');
const path = require('path');

const LOCALES_DIR = process.env.LOCALES_DIR || 'public/locales';
const BASE_LOCALE = process.env.BASE_LOCALE || 'en';

class TranslationValidator {
  constructor() {
    this.errors = [];
    this.warnings = [];
  }

  validate() {
    const baseDir = path.join(LOCALES_DIR, BASE_LOCALE);

    if (!fs.existsSync(baseDir)) {
      this.errors.push(`Base locale directory not found: ${baseDir}`);
      return this.getResults();
    }

    const baseFiles = fs.readdirSync(baseDir).filter(f => f.endsWith('.json'));
    const locales = fs.readdirSync(LOCALES_DIR)
      .filter(f => f !== BASE_LOCALE && fs.statSync(path.join(LOCALES_DIR, f)).isDirectory());

    // Validate base locale files
    for (const file of baseFiles) {
      this.validateJsonFile(path.join(baseDir, file));
    }

    // Compare with other locales
    for (const locale of locales) {
      this.validateLocale(locale, baseFiles);
    }

    return this.getResults();
  }

  validateJsonFile(filePath) {
    try {
      const content = fs.readFileSync(filePath, 'utf8');
      JSON.parse(content);
    } catch (e) {
      this.errors.push(`Invalid JSON in ${filePath}: ${e.message}`);
    }
  }

  validateLocale(locale, baseFiles) {
    const localeDir = path.join(LOCALES_DIR, locale);

    for (const file of baseFiles) {
      const basePath = path.join(LOCALES_DIR, BASE_LOCALE, file);
      const localePath = path.join(localeDir, file);

      // Check file exists
      if (!fs.existsSync(localePath)) {
        this.errors.push(`Missing file: ${locale}/${file}`);
        continue;
      }

      this.validateJsonFile(localePath);

      // Compare keys
      try {
        const baseContent = JSON.parse(fs.readFileSync(basePath, 'utf8'));
        const localeContent = JSON.parse(fs.readFileSync(localePath, 'utf8'));

        const baseKeys = this.getAllKeys(baseContent);
        const localeKeys = this.getAllKeys(localeContent);

        // Missing keys
        for (const key of baseKeys) {
          if (!localeKeys.includes(key)) {
            this.errors.push(`Missing key in ${locale}/${file}: ${key}`);
          }
        }

        // Extra keys (warnings only)
        for (const key of localeKeys) {
          if (!baseKeys.includes(key)) {
            this.warnings.push(`Extra key in ${locale}/${file}: ${key}`);
          }
        }

        // Check interpolation variables
        this.checkInterpolation(baseContent, localeContent, locale, file);

      } catch (e) {
        // Already reported in validateJsonFile
      }
    }
  }

  getAllKeys(obj, prefix = '') {
    return Object.entries(obj).flatMap(([key, value]) => {
      const fullKey = prefix ? `${prefix}.${key}` : key;
      if (typeof value === 'object' && value !== null) {
        return this.getAllKeys(value, fullKey);
      }
      return [fullKey];
    });
  }

  checkInterpolation(baseObj, localeObj, locale, file, prefix = '') {
    for (const [key, value] of Object.entries(baseObj)) {
      const fullKey = prefix ? `${prefix}.${key}` : key;

      if (typeof value === 'object' && value !== null) {
        if (localeObj[key]) {
          this.checkInterpolation(value, localeObj[key], locale, file, fullKey);
        }
      } else if (typeof value === 'string') {
        const baseVars = this.extractInterpolationVars(value);
        const localeValue = this.getNestedValue(localeObj, key);

        if (localeValue && typeof localeValue === 'string') {
          const localeVars = this.extractInterpolationVars(localeValue);

          for (const v of baseVars) {
            if (!localeVars.includes(v)) {
              this.errors.push(
                `Missing interpolation variable "{{${v}}}" in ${locale}/${file}: ${fullKey}`
              );
            }
          }
        }
      }
    }
  }

  extractInterpolationVars(str) {
    const matches = str.match(/\{\{(\w+)\}\}/g) || [];
    return matches.map(m => m.replace(/[{}]/g, ''));
  }

  getNestedValue(obj, key) {
    return key.split('.').reduce((o, k) => o?.[k], obj);
  }

  getResults() {
    return {
      valid: this.errors.length === 0,
      errors: this.errors,
      warnings: this.warnings,
    };
  }
}

// Run validation
const validator = new TranslationValidator();
const results = validator.validate();

if (results.warnings.length > 0) {
  console.log('\nWarnings:');
  results.warnings.forEach(w => console.log(`  - ${w}`));
}

if (results.errors.length > 0) {
  console.log('\nErrors:');
  results.errors.forEach(e => console.log(`  - ${e}`));
  process.exit(1);
} else {
  console.log('\nAll translations valid!');
  process.exit(0);
}
```

### Find Unused Keys Script

```javascript
#!/usr/bin/env node
// scripts/find-unused-translations.js

const fs = require('fs');
const path = require('path');
const { execSync } = require('child_process');

const LOCALES_DIR = 'public/locales';
const SOURCE_DIRS = ['src', 'app', 'components'];
const BASE_LOCALE = 'en';

function findAllTranslationKeys() {
  const baseDir = path.join(LOCALES_DIR, BASE_LOCALE);
  const files = fs.readdirSync(baseDir).filter(f => f.endsWith('.json'));
  const keys = new Map(); // key -> namespace

  for (const file of files) {
    const namespace = file.replace('.json', '');
    const content = JSON.parse(fs.readFileSync(path.join(baseDir, file), 'utf8'));

    getAllKeys(content).forEach(key => {
      keys.set(`${namespace}:${key}`, namespace);
      // Also add without namespace for default namespace
      if (namespace === 'common') {
        keys.set(key, namespace);
      }
    });
  }

  return keys;
}

function getAllKeys(obj, prefix = '') {
  return Object.entries(obj).flatMap(([key, value]) => {
    const fullKey = prefix ? `${prefix}.${key}` : key;
    if (typeof value === 'object' && value !== null) {
      return getAllKeys(value, fullKey);
    }
    return [fullKey];
  });
}

function findUsedKeys() {
  const usedKeys = new Set();

  // Patterns to search for
  const patterns = [
    "t\\(['\"]([^'\"]+)['\"]",           // t('key')
    "t\\(['\"]([^'\"]+)['\"]\\s*,",      // t('key', { ... })
    'i18nKey=["\']([^"\']+)["\']',       // i18nKey="key"
  ];

  for (const srcDir of SOURCE_DIRS) {
    if (!fs.existsSync(srcDir)) continue;

    for (const pattern of patterns) {
      try {
        const result = execSync(
          `grep -rhoE '${pattern}' ${srcDir} 2>/dev/null || true`,
          { encoding: 'utf8' }
        );

        const matches = result.match(new RegExp(pattern, 'g')) || [];
        matches.forEach(match => {
          const keyMatch = match.match(new RegExp(pattern));
          if (keyMatch && keyMatch[1]) {
            usedKeys.add(keyMatch[1]);
          }
        });
      } catch (e) {
        // grep returns exit 1 if no matches
      }
    }
  }

  return usedKeys;
}

// Main
const allKeys = findAllTranslationKeys();
const usedKeys = findUsedKeys();

const unusedKeys = [];
for (const [key] of allKeys) {
  // Check various forms of the key
  const keyVariants = [
    key,
    key.split(':').pop(),  // Without namespace
  ];

  if (!keyVariants.some(k => usedKeys.has(k))) {
    unusedKeys.push(key);
  }
}

if (unusedKeys.length > 0) {
  console.log('Potentially unused translation keys:');
  unusedKeys.forEach(k => console.log(`  - ${k}`));
  console.log(`\nTotal: ${unusedKeys.length} keys`);
  console.log('\nNote: Some keys may be used dynamically and not detected.');
} else {
  console.log('No unused translation keys found!');
}
```

## Language Switcher

```typescript
'use client';

import { useTranslation } from 'react-i18next';

const LANGUAGES = [
  { code: 'en', name: 'English', nativeName: 'English', flag: '🇺🇸' },
  { code: 'es', name: 'Spanish', nativeName: 'Español', flag: '🇪🇸' },
  { code: 'fr', name: 'French', nativeName: 'Français', flag: '🇫🇷' },
  { code: 'ar', name: 'Arabic', nativeName: 'العربية', flag: '🇸🇦', rtl: true },
] as const;

function LanguageSwitcher() {
  const { i18n } = useTranslation();

  const handleChange = (newLocale: string) => {
    i18n.changeLanguage(newLocale);
    // Optional: persist to cookie/localStorage
    document.cookie = `locale=${newLocale};path=/;max-age=31536000`;
  };

  return (
    <select
      value={i18n.language}
      onChange={(e) => handleChange(e.target.value)}
      aria-label="Select language"
    >
      {LANGUAGES.map(({ code, nativeName, flag }) => (
        <option key={code} value={code}>
          {flag} {nativeName}
        </option>
      ))}
    </select>
  );
}
```

## Troubleshooting

| Issue | Cause | Solution |
|-------|-------|----------|
| Keys showing instead of translation | Missing namespace, key not found | Check namespace in `useTranslation()`, verify key exists |
| Interpolation not working | Wrong variable syntax | Use `{{variable}}` not `{variable}` |
| Pluralization not working | Missing plural suffixes | Add `_one`, `_other` suffixes (and language-specific) |
| RTL layout broken | Using physical CSS properties | Use logical properties (`margin-inline-start`) |
| Dates formatting incorrectly | Wrong locale code | Use proper BCP 47 codes (`en-US` not `en`) |
| Missing translations in production | Build not including locale files | Check build configuration, ensure locales are copied |
| Language detection not working | Cookie/localStorage conflicts | Clear storage, check detection order |
| Server/client mismatch | Hydration error | Ensure server and client use same locale |

## Checklist

### Setup
- [ ] i18n library configured
- [ ] Language detection enabled
- [ ] Fallback language set
- [ ] Namespaces organized by feature
- [ ] TypeScript types for translation keys (optional)

### Translation Files
- [ ] Consistent key naming (camelCase, hierarchical)
- [ ] No duplicate keys
- [ ] All languages have all keys
- [ ] Pluralization rules correct for each language
- [ ] Interpolation variables match across languages

### Code Quality
- [ ] No hardcoded strings in components
- [ ] Trans component for rich text
- [ ] Interpolation for dynamic values
- [ ] Dates/numbers use Intl formatters
- [ ] Currency formatting with proper locale

### UX
- [ ] Language switcher accessible
- [ ] RTL languages fully supported
- [ ] CSS uses logical properties
- [ ] Icons flip appropriately in RTL
- [ ] SEO: lang attribute on html
- [ ] URL structure for locales (optional)

### Workflow
- [ ] Key extraction automated
- [ ] Missing translation detection
- [ ] Unused key detection
- [ ] Translation validation in CI
- [ ] Easy format for translators

## Related Templates

- See `ui-patterns` for accessible language switcher components
- See `api-patterns` for locale-aware API responses
- See `test-patterns` for i18n testing strategies
- See `cicd-patterns` for translation validation in CI
