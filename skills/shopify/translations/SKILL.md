---
name: shopify-translations
description: Manage Shopify store translations with French as source language. Use when working with translation files, updating translations, or managing multi-language Shopify content. Triggers on "translate", "translations", "localization", "i18n", "French to German/Italian/English".
---

# Shopify Translations Management

Manage Shopify translations with French (fr_original) as the source language, translating to German (de_fixed), Italian (it_fixed), and English (en_fixed).

## When to Use

- User mentions "translations", "translate", "localization", "i18n"
- User wants to extract translations from Shopify
- User needs to update or fix translations
- User asks about multi-language content
- User mentions French/German/Italian/English language work

## Translation Architecture

### Source Language: French (fr_original)
### Target Languages:
- German (de_fixed)
- Italian (it_fixed)
- English (en_fixed)

### Status Values:
- `pending` - Not yet translated
- `completed` - Ready to publish
- `verified` - Reviewed and approved

## Translation Structure

Each entry in translation files follows this format:

```json
{
  "key": "section.page.json.heading:id",
  "fr_original": "Design Gratuit",
  "de_fixed": "Kostenlose Gestaltung",
  "de_status": "completed",
  "it_fixed": "Design Gratuito",
  "it_status": "completed",
  "en_fixed": "Free Design",
  "en_status": "completed"
}
```

## Common Commands

```bash
# Extract current translations from Shopify
npm run translations:myarmy:extract

# Generate review report (identify missing/corrupted translations)
npm run translations:myarmy:review

# Auto-translate pending items using OpenAI
OPENAI_API_KEY="sk-..." npm run translations:myarmy:translate

# Publish translations to Shopify
npm run translations:myarmy:publish

# Create backup of current translations
npm run translations:myarmy:backup

# Full workflow: extract → filter → review
npm run translations:myarmy:workflow
```

## Workflow: Extract → Fix → Publish

1. **Extract** all translations from Shopify
2. **Review** what needs fixing (check review-report.md)
3. **Fix** corrupted de_fixed, it_fixed, en_fixed fields
4. **Publish** corrected translations

## Key Rules

### DO:
- Keep French as source (fr_original field)
- Maintain semantic key structure
- Review before publishing
- Create backups before major changes

### DON'T:
- Edit fr_original field directly
- Mix manual edits with auto-translation
- Skip review step
- Use corrupted translations

## Swiss Military Terminology

Use correct Swiss military terms:
- **badge** (NOT "écusson")
- **section** (NOT "peloton")

## Environment Variables Required

```bash
SHOPIFY_ACCESS_TOKEN=shpat_...
SHOPIFY_STORE_DOMAIN=087ffd-4a.myshopify.com
OPENAI_API_KEY=sk-...  # Optional, for auto-translation
```
