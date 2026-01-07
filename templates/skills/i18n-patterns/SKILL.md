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
// ✅ GOOD: Hierarchical, descriptive keys
{
  "user": {
    "profile": {
      "title": "Profile Settings",
      "name": "Full name",
      "email": "Email address"
    }
  }
}

// ❌ BAD: Flat, unclear keys
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

## Pluralization

```json
// English
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

// Languages with complex plurals (e.g., Russian)
{
  "items": {
    "count_one": "{{count}} товар",
    "count_few": "{{count}} товара",
    "count_many": "{{count}} товаров",
    "count_other": "{{count}} товаров"
  }
}
```

```typescript
// Usage
t('items.count', { count: 1 });  // "1 item"
t('items.count', { count: 5 });  // "5 items"
```

## Date and Number Formatting

```typescript
// Using Intl API
const formatDate = (date: Date, locale: string) => {
  return new Intl.DateTimeFormat(locale, {
    year: 'numeric',
    month: 'long',
    day: 'numeric',
  }).format(date);
};

const formatCurrency = (amount: number, locale: string, currency: string) => {
  return new Intl.NumberFormat(locale, {
    style: 'currency',
    currency,
  }).format(amount);
};

// Usage
formatDate(new Date(), 'en-US');  // "January 15, 2024"
formatDate(new Date(), 'de-DE');  // "15. Januar 2024"

formatCurrency(1234.56, 'en-US', 'USD');  // "$1,234.56"
formatCurrency(1234.56, 'de-DE', 'EUR');  // "1.234,56 €"

// With react-i18next
import { useTranslation } from 'react-i18next';

function Price({ amount }: { amount: number }) {
  const { i18n } = useTranslation();

  return (
    <span>
      {formatCurrency(amount, i18n.language, 'USD')}
    </span>
  );
}
```

## RTL Support

```typescript
// Detect RTL languages
const RTL_LANGUAGES = ['ar', 'he', 'fa', 'ur'];

function isRTL(language: string): boolean {
  return RTL_LANGUAGES.includes(language);
}

// Apply direction to document
useEffect(() => {
  document.documentElement.dir = isRTL(i18n.language) ? 'rtl' : 'ltr';
  document.documentElement.lang = i18n.language;
}, [i18n.language]);

// CSS for RTL
.container {
  margin-left: 1rem;
  margin-right: 0;
}

[dir="rtl"] .container {
  margin-left: 0;
  margin-right: 1rem;
}

// Or use logical properties (modern CSS)
.container {
  margin-inline-start: 1rem;  /* Works for both LTR and RTL */
}
```

## Server-Side i18n (Next.js)

```typescript
// app/[locale]/layout.tsx
import { dir } from 'i18next';
import { languages } from '@/lib/i18n-settings';

export async function generateStaticParams() {
  return languages.map((locale) => ({ locale }));
}

export default function RootLayout({
  children,
  params: { locale },
}: {
  children: React.ReactNode;
  params: { locale: string };
}) {
  return (
    <html lang={locale} dir={dir(locale)}>
      <body>{children}</body>
    </html>
  );
}

// Server component translation
import { useTranslation } from '@/lib/i18n';

export default async function Page({
  params: { locale },
}: {
  params: { locale: string };
}) {
  const { t } = await useTranslation(locale, 'common');

  return <h1>{t('title')}</h1>;
}
```

## Translation Workflow

```bash
# Extract keys from code
npx i18next-parser

# Validate translations
node scripts/validate-translations.js

# Find missing translations
node scripts/find-missing.js

# Find unused translations
node scripts/find-unused.js
```

```javascript
// scripts/validate-translations.js
const fs = require('fs');
const path = require('path');

const LOCALES_DIR = 'public/locales';
const BASE_LOCALE = 'en';

function validateTranslations() {
  const baseDir = path.join(LOCALES_DIR, BASE_LOCALE);
  const baseFiles = fs.readdirSync(baseDir);

  const locales = fs.readdirSync(LOCALES_DIR)
    .filter(f => f !== BASE_LOCALE);

  const issues = [];

  for (const locale of locales) {
    for (const file of baseFiles) {
      const basePath = path.join(baseDir, file);
      const localePath = path.join(LOCALES_DIR, locale, file);

      if (!fs.existsSync(localePath)) {
        issues.push(`Missing file: ${locale}/${file}`);
        continue;
      }

      const baseKeys = getAllKeys(JSON.parse(fs.readFileSync(basePath)));
      const localeKeys = getAllKeys(JSON.parse(fs.readFileSync(localePath)));

      for (const key of baseKeys) {
        if (!localeKeys.includes(key)) {
          issues.push(`Missing key: ${locale}/${file} - ${key}`);
        }
      }
    }
  }

  return issues;
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
```

## Language Switcher

```typescript
'use client';

import { useTranslation } from 'react-i18next';

const LANGUAGES = [
  { code: 'en', name: 'English', flag: '🇺🇸' },
  { code: 'es', name: 'Español', flag: '🇪🇸' },
  { code: 'fr', name: 'Français', flag: '🇫🇷' },
];

function LanguageSwitcher() {
  const { i18n } = useTranslation();

  return (
    <select
      value={i18n.language}
      onChange={(e) => i18n.changeLanguage(e.target.value)}
      aria-label="Select language"
    >
      {LANGUAGES.map(({ code, name, flag }) => (
        <option key={code} value={code}>
          {flag} {name}
        </option>
      ))}
    </select>
  );
}
```

## Checklist

### Setup
- [ ] i18n library configured
- [ ] Language detection enabled
- [ ] Fallback language set
- [ ] Namespaces organized by feature

### Translation Files
- [ ] Consistent key naming
- [ ] No duplicate keys
- [ ] All languages have all keys
- [ ] Pluralization handled

### Code Quality
- [ ] No hardcoded strings in components
- [ ] Trans component for rich text
- [ ] Interpolation for dynamic values
- [ ] Dates/numbers use Intl

### UX
- [ ] Language switcher accessible
- [ ] RTL languages supported
- [ ] SEO: lang attribute set
- [ ] URL structure for locales

### Workflow
- [ ] Key extraction automated
- [ ] Missing translation detection
- [ ] Translation validation in CI
- [ ] Easy for translators to work with
