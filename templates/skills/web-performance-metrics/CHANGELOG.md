# Changelog

All notable changes to the Web Performance Metrics skill will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2026-01-10

### Added

#### Core Features
- **Bundle Size Analysis** (`analyze-bundle.sh`)
  - Leverage existing `@next/bundle-analyzer` integration
  - Parse Next.js build output for route-level bundle sizes
  - Compare against configurable performance budgets
  - Report total, initial, and largest chunk sizes
  - Export JSON reports for CI/CD integration

- **Core Web Vitals Measurement** (`measure-core-vitals.sh`)
  - Lighthouse CI integration for automated testing
  - Measure LCP, FID/INP, CLS, and performance score
  - Support for desktop and mobile presets
  - Configurable thresholds and assertions
  - Generate detailed performance reports

- **Runtime Performance Analysis** (`analyze-runtime.sh`)
  - Detect React performance anti-patterns via codebase scanning
  - Identify inline arrow functions in JSX
  - Flag missing `useMemo`, `useCallback`, `React.memo`
  - Detect unnecessary Client Components
  - Find non-tree-shakeable imports
  - Generate actionable recommendations

- **Network Performance Check** (`check-network-perf.sh`)
  - Extract TTFB, resource counts, and transfer sizes from Lighthouse
  - Analyze resource breakdown (JS, CSS, images, fonts)
  - Identify render-blocking resources
  - Check for modern image format opportunities
  - Validate font loading strategies

- **Consolidated Performance Report** (`performance-report.sh`)
  - Orchestrate all performance checks in single command
  - Combine results into unified JSON report
  - Generate formatted summary output
  - Support selective execution (skip individual checks)
  - GitHub Actions integration with PR comments

#### Infrastructure
- **Shared Utilities** (`lib/common.sh`)
  - Color-coded logging functions
  - JSON parsing and manipulation helpers
  - Size conversion utilities (bytes ↔ human-readable)
  - Threshold comparison functions
  - GitHub Actions output helpers
  - Environment detection and validation

#### Configuration
- **Bundle Budgets** (`resources/bundle-budgets.json`)
  - Default budgets: 500kb total, 200kb initial, 100kb per chunk
  - Route-specific budgets for key pages
  - Configurable strict mode
  - Warning and error thresholds

- **Lighthouse Configuration** (`resources/lighthouse-config.json`)
  - Desktop and mobile presets
  - Performance-focused audits (skip a11y, SEO, etc.)
  - Configurable assertion levels (error, warn, off)
  - Core Web Vitals thresholds matching Google recommendations

#### Documentation
- **Comprehensive SKILL.md** (~1500 lines)
  - When to use the skill
  - Quick reference guide
  - Core Web Vitals optimization patterns
  - Bundle size analysis and code splitting strategies
  - React rendering optimization techniques
  - Network and loading performance best practices
  - Performance budgets and CI/CD integration
  - Common workflows and troubleshooting

### Technical Details

- **Language**: Bash (scripts), JSON (configuration)
- **Dependencies**:
  - `@lhci/cli` (Lighthouse CI)
  - `jq` (JSON processing)
  - Next.js bundle analyzer (already installed)
- **Integration**: GitHub Actions PR quality check workflow
- **Compatibility**: macOS and Linux (ubuntu-latest)

### Performance Impact

- **CI Duration**: ~2-3 minutes added to PR checks
  - Bundle analysis: ~30s
  - Lighthouse (3 runs): ~90s
  - Runtime analysis: ~10s
  - Network analysis: ~5s

### Future Enhancements

Not implemented in v1.0.0 (potential future additions):
- Historical performance tracking dashboard
- Performance regression trend analysis
- Integration with Vercel Analytics
- Real User Monitoring (RUM) via Sentry Web Vitals
- Performance budget auto-tuning based on p95 metrics
- Mobile performance testing (separate workflow)
- Integration with `visual-testing` skill

---

## Version History

### [1.0.0] - 2026-01-10
- Initial release with full feature set
- 5 executable scripts + shared utilities
- Comprehensive documentation
- CI/CD integration ready
- Performance budgets and thresholds configured
