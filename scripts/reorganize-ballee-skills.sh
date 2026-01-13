#!/usr/bin/env bash
#
# Reorganize cortex-skills: Move general-purpose skills from skills/ballee/ to templates/skills/
#
# Usage:
#   ./reorganize-ballee-skills.sh [--dry-run]
#
# This script:
# 1. Identifies general-purpose skills in skills/ballee/
# 2. Moves them to templates/skills/
# 3. Creates git commits for the reorganization
# 4. Handles duplicate resolution

set -e

# Configuration
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
CORTEX_PATH="$(dirname "$SCRIPT_DIR")"
DRY_RUN=false

# Parse arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --dry-run)
      DRY_RUN=true
      shift
      ;;
    --help)
      echo "Usage: $0 [--dry-run]"
      echo ""
      echo "Options:"
      echo "  --dry-run         Preview changes without executing"
      exit 0
      ;;
    *)
      echo "Unknown option: $1"
      exit 1
      ;;
  esac
done

cd "$CORTEX_PATH"

echo "🔍 Reorganizing cortex-skills"
echo "   Cortex path: $CORTEX_PATH"
echo "   Dry run: $DRY_RUN"
echo ""

# General-purpose skills to move from skills/ballee/ to templates/skills/
declare -a GENERAL_PURPOSE_SKILLS=(
  "ai-skill-manager"
  "cicd-pipeline"
  "code-quality-tools"
  "codemagic-flutter-cicd"
  "database-migration-manager"
  "db-performance-patterns"
  "flutter-accessibility"
  "flutter-animations"
  "flutter-api-patterns"
  "flutter-code-quality"
  "flutter-development"
  "flutter-forms"
  "flutter-offline"
  "flutter-performance"
  "flutter-query-testing"
  "flutter-theming"
  "flutter-ui-components"
  "nextjs-seo-metadata"
  "og-image-generation"
  "open-graph-twitter"
  "rls-policy-generator"
  "sentry-error-manager"
  "seo-testing"
  "sitemap-canonical-seo"
  "structured-data-jsonld"
  "supabase-email-templates"
  "supabase-realtime-specialist"
  "user-stories-manager"
  "visual-testing"
  "web-performance-metrics"
  "wip-lifecycle-manager"
  "xcode-cloud-cicd"
)

# Duplicates to resolve (keep template version, remove ballee version)
declare -a DUPLICATE_SKILLS=(
  "api-patterns"
  "data-management"
  "db-anti-patterns"
  "flutter-testing"
  "production-readiness"
  "service-patterns"
  "test-patterns"
  "ui-patterns"
)

echo "📊 Summary:"
echo "   General-purpose skills to move: ${#GENERAL_PURPOSE_SKILLS[@]}"
echo "   Duplicates to resolve: ${#DUPLICATE_SKILLS[@]}"
echo ""

# Move general-purpose skills
echo "================================================================================"
echo "MOVING GENERAL-PURPOSE SKILLS"
echo "================================================================================"
echo ""

MOVED_COUNT=0
SKIPPED_COUNT=0

for skill in "${GENERAL_PURPOSE_SKILLS[@]}"; do
  SOURCE="skills/ballee/$skill"
  TARGET="templates/skills/$skill"

  if [[ ! -d "$SOURCE" ]]; then
    echo "⚠️  Skipped: $skill (not found in skills/ballee/)"
    ((SKIPPED_COUNT++))
    continue
  fi

  if [[ -d "$TARGET" ]]; then
    echo "⚠️  Skipped: $skill (already exists in templates/skills/)"
    ((SKIPPED_COUNT++))
    continue
  fi

  if [[ "$DRY_RUN" == true ]]; then
    echo "🔍 Would move: $SOURCE → $TARGET"
  else
    echo "✓ Moving: $skill"
    git mv "$SOURCE" "$TARGET"
    ((MOVED_COUNT++))
  fi
done

echo ""
echo "Moved: $MOVED_COUNT skills"
echo "Skipped: $SKIPPED_COUNT skills"
echo ""

# Resolve duplicates
echo "================================================================================"
echo "RESOLVING DUPLICATES"
echo "================================================================================"
echo ""

RESOLVED_COUNT=0

for skill in "${DUPLICATE_SKILLS[@]}"; do
  BALLEE_VERSION="skills/ballee/$skill"
  TEMPLATE_VERSION="templates/skills/$skill"

  if [[ ! -d "$BALLEE_VERSION" ]]; then
    echo "⚠️  Skipped: $skill (ballee version not found)"
    continue
  fi

  if [[ ! -d "$TEMPLATE_VERSION" ]]; then
    echo "⚠️  Warning: $skill (template version not found, keeping ballee version)"
    continue
  fi

  if [[ "$DRY_RUN" == true ]]; then
    echo "🔍 Would remove duplicate: $BALLEE_VERSION (keeping template version)"
  else
    echo "✓ Removing duplicate: $skill (keeping template version)"
    git rm -r "$BALLEE_VERSION"
    ((RESOLVED_COUNT++))
  fi
done

echo ""
echo "Resolved: $RESOLVED_COUNT duplicates"
echo ""

# Create commit if changes were made
if [[ "$DRY_RUN" == false ]]; then
  if git diff --cached --quiet; then
    echo "✓ No changes to commit"
  else
    echo "📝 Creating commit..."
    git commit -m "refactor(skills): reorganize general-purpose skills to templates/

Moved ${MOVED_COUNT} general-purpose skills from skills/ballee/ to templates/skills/:
- Supabase patterns (database-migration-manager, rls-policy-generator, etc.)
- Flutter patterns (flutter-*, 10 skills)
- CI/CD patterns (xcode-cloud-cicd, codemagic-flutter-cicd, cicd-pipeline)
- SEO patterns (nextjs-seo-metadata, og-image-generation, etc.)
- Code quality (code-quality-tools, web-performance-metrics)
- Error monitoring (sentry-error-manager)
- Testing (visual-testing)
- Project management (user-stories-manager, wip-lifecycle-manager)

Resolved ${RESOLVED_COUNT} duplicates by keeping template versions.

These skills are general-purpose and can be used across any project,
not just Ballee-specific."

    echo "✅ Commit created successfully"

    # Show status
    echo ""
    echo "📊 Git status:"
    git status --short
  fi
else
  echo "🔍 Dry run complete - no changes made"
fi

echo ""
echo "================================================================================"
echo "REORGANIZATION COMPLETE"
echo "================================================================================"
echo ""
echo "Next steps:"
echo "1. Review the changes: git log -1 --stat"
echo "2. Push to remote: git push origin main"
echo "3. Update sync configuration to classify skills correctly"
