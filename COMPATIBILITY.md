# Cortex Compatibility Matrix

**Last Updated:** 2026-01-13

This matrix shows the compatibility between Cortex NPM packages and Cortex Skills.

## Overview

- **Packages**: 28 published packages
- **Skills**: 6 skills with package dependencies
- **Total Mappings**: 14 package→skill dependencies

## Compatibility Table

| Package | Version | Skill | Skill Version | Required Version |
|---------|---------|-------|---------------|------------------|
| `@akson/cortex-analytics` | 0.9.1 | [gsc-optimization](skills/skills/analytics-framework/gsc-optimization/) | 1.0.0 | latest |
| `@akson/cortex-analytics` | 0.9.1 | [gtm-integration](skills/skills/analytics-framework/gtm-integration/) | 1.0.0 | latest |
| `@akson/cortex-analytics` | 0.9.1 | [advertising-performance](skills/skills/marketing-intelligence-framework/advertising-performance/) | 1.0.0 | latest |
| `@akson/cortex-analytics` | 0.9.1 | [gtm-myarmy](skills/skills/myarmy-skills/gtm-myarmy/) | 1.0.0 | latest |
| `@akson/cortex-google-ads` | 2.1.0 | [advertising-performance](skills/skills/marketing-intelligence-framework/advertising-performance/) | 1.0.0 | latest |
| `@akson/cortex-gsc` | 0.5.0 | [gsc-optimization](skills/skills/analytics-framework/gsc-optimization/) | 1.0.0 | latest |
| `@akson/cortex-gtm` | 3.1.0 | [gtm-integration](skills/skills/analytics-framework/gtm-integration/) | 1.0.0 | latest |
| `@akson/cortex-gtm` | 3.1.0 | [gtm-myarmy](skills/skills/myarmy-skills/gtm-myarmy/) | 1.0.0 | latest |
| `@akson/cortex-utilities` | 0.3.1 | [gtm-integration](skills/skills/analytics-framework/gtm-integration/) | 1.0.0 | latest |
| `@akson/cortex-utilities` | 0.3.1 | [gtm-myarmy](skills/skills/myarmy-skills/gtm-myarmy/) | 1.0.0 | latest |
| `@supabase/supabase-js` | N/A | [health-monitoring](skills/skills/marketing-intelligence-framework/health-monitoring/) | 1.0.0 | latest |
| `@supabase/supabase-js` | N/A | [lead-scoring-myarmy](skills/skills/myarmy-skills/lead-scoring-myarmy/) | 1.0.0 | latest |
| `airtable` | N/A | [health-monitoring](skills/skills/marketing-intelligence-framework/health-monitoring/) | 1.0.0 | latest |
| `facebook-nodejs-business-sdk` | N/A | [advertising-performance](skills/skills/marketing-intelligence-framework/advertising-performance/) | 1.0.0 | latest |

## Packages Without Skills

The following packages don't have associated skills yet:

- `@akson/cortex-agents` (0.3.0) - Comprehensive Claude agent management for @cortex ecosystem
- `@akson/cortex-analytics-react` (2.1.0) - Reusable React analytics components and hooks for @cortex ecosystem
- `@akson/cortex-dev-tools` (1.0.0) - Shared development tools, configs, and validators for Cortex ecosystem
- `@akson/cortex-doc-standards` (5.0.3) - Unified documentation standards and tooling for Cortex repositories with LLM optimization
- `@akson/cortex-forms` (0.2.0) - Reusable form state management library for React applications
- `@akson/cortex-landing-analytics` (0.3.3) - Enhanced analytics for landing pages with lead scoring, multi-channel conversion tracking, and A/B testing support
- `@akson/cortex-landing-config` (0.3.0) - Smart configuration system for landing pages - auto-detection, environment validation, feature flags, and regional configurations
- `@akson/cortex-landing-core` (0.3.2) - Core UI components for @akson/cortex-landing - mobile-first, accessible, analytics-integrated
- `@akson/cortex-landing-forms` (0.3.1) - Reusable form components and utilities for landing pages
- `@akson/cortex-landing-hooks` (0.4.1) - React hooks for landing pages - device detection, API calls, form submission, analytics, and performance
- `@akson/cortex-landing-intl` (0.4.1) - International utilities for @akson/cortex-landing - phone validation, formatting, and localization
- `@akson/cortex-landing-performance` (0.3.0) - Performance optimization utilities for landing pages - image optimization, Web Vitals monitoring, lazy loading, and bundle optimization
- `@akson/cortex-landing-templates` (0.4.1) - Ready-to-use landing page React components - hero sections, forms, trust indicators, and social proof
- `@akson/cortex-landing-themes` (0.3.0) - Design system and theming utilities for landing pages - CSS custom properties, theme presets, and design tokens
- `@akson/cortex-leads-core` (0.3.0) - Core types and interfaces for @cortex lead management ecosystem
- `@akson/cortex-mcp-orchestrator` (2.0.0) - MCP orchestrator for all Cortex analytics platforms (GTM, Google Ads, PostHog, GSC)
- `@akson/cortex-meta-ads` (2.0.0) - Meta/Facebook Ads API client for Cortex analytics
- `@akson/cortex-posthog` (0.5.0) - PostHog API client and MCP server for analytics and event tracking
- `@akson/cortex-seo` (2.0.0) - SEO analysis tools including Core Web Vitals, Schema validation, and GEO optimization
- `@akson/cortex-shopify-translations` (2.3.0) - Unified Shopify translations management client with product extraction, translation sync, and CLI tools
- `@akson/cortex-slack` (2.1.1) - Unified Slack integration for Cortex ecosystem - webhooks, bot API, and notifications
- `@akson/cortex-supabase` (3.2.8) - Comprehensive Supabase package with Auth, Storage, Database, and Realtime functionality
- `@akson/cortex-ui-library` (1.5.2) - UI components library with built-in validation using industry-standard libraries

## Skills By Category


### analytics-framework (2 skills)

- **gsc-optimization**: `@akson/cortex-analytics`, `@akson/cortex-gsc`
- **gtm-integration**: `@akson/cortex-analytics`, `@akson/cortex-gtm`, `@akson/cortex-utilities`

### marketing-intelligence-framework (2 skills)

- **advertising-performance**: `@akson/cortex-analytics`, `@akson/cortex-google-ads`, `facebook-nodejs-business-sdk`
- **health-monitoring**: `@supabase/supabase-js`, `airtable`

### myarmy-skills (2 skills)

- **gtm-myarmy**: `@akson/cortex-analytics`, `@akson/cortex-gtm`, `@akson/cortex-utilities`
- **lead-scoring-myarmy**: `@supabase/supabase-js`

## Using This Matrix

### For Package Developers

When making changes to a package:

1. Check which skills reference your package
2. Update skill documentation if API changes
3. Coordinate with skill maintainers for breaking changes
4. Run `npm version <major|minor|patch>` to trigger skill sync

### For Skill Developers

When creating or updating skills:

1. Declare package dependencies in `skill.config.json`
2. Use semantic versioning for package requirements
3. Test skills with specified package versions
4. Update this matrix via `npm run generate:compatibility`

### Version Notation

- `^2.0.0` - Compatible with 2.x.x (semver caret)
- `~2.0.0` - Compatible with 2.0.x (semver tilde)
- `2.0.0` - Exact version required
- `latest` - Any version (use with caution)

## Automation

This matrix is automatically updated:

- **Weekly**: Via GitHub Actions
- **On Package Publish**: When packages are released
- **Manually**: Run `npm run generate:compatibility`

## Related Resources

- [Cortex Packages Repository](https://github.com/antoineschaller/cortex-packages)
- [Cortex Skills Repository](https://github.com/antoineschaller/cortex-skills)
- [NPM Packages](https://www.npmjs.com/search?q=%40akson%2Fcortex)

---

*Generated by cortex-skills/scripts/generate-compatibility-matrix.js*
