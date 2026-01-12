#!/usr/bin/env bash
#
# Reusability Assessment Script
# Analyzes cortex-skills and generates reusability report
#
# Usage: ./assess-reusability.sh [--verbose] [--json]
#
# This script:
# - Scans all skills in the repository
# - Reads skill.config.json (if exists)
# - Analyzes for hardcoded values (URLs, IDs, project names)
# - Generates reusability report
# - Outputs summary statistics

set -euo pipefail

# Configuration
SKILLS_DIR="${SKILLS_DIR:-./skills}"
OUTPUT_FORMAT="${1:-text}"  # text, json, markdown
VERBOSE=false

# Colors
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Parse arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --verbose)
      VERBOSE=true
      shift
      ;;
    --json)
      OUTPUT_FORMAT="json"
      shift
      ;;
    --markdown)
      OUTPUT_FORMAT="markdown"
      shift
      ;;
    *)
      shift
      ;;
  esac
done

# Counters
TOTAL_SKILLS=0
GENERIC_SKILLS=0
FRAMEWORK_SKILLS=0
IMPLEMENTATION_SKILLS=0
PROJECT_SPECIFIC_SKILLS=0

# Arrays for categorization
declare -a GENERIC_LIST
declare -a FRAMEWORK_LIST
declare -a IMPLEMENTATION_LIST
declare -a PROJECT_SPECIFIC_LIST

# Patterns indicating project-specific code
PROJECT_PATTERNS=(
  "myarmy"
  "ballee"
  "GTM-[A-Z0-9]+"
  "[0-9]{10}"  # Google Ads customer IDs
  "myshopify\.com"
  "supabase\.co/[a-z]+"
  "@myarmy"
  "myarmy\.ch"
)

# Function: Detect reusability level
detect_reusability() {
  local skill_dir=$1
  local skill_name=$(basename "$skill_dir")
  local config_file="$skill_dir/skill.config.json"
  local skill_file="$skill_dir/SKILL.md"

  # Default values
  local reusability_score=50
  local reusability_level="unknown"
  local has_config=false
  local extends_framework=false
  local project_references=0

  # Check for skill.config.json
  if [[ -f "$config_file" ]]; then
    has_config=true

    # Extract reusability info from config
    if command -v jq &> /dev/null; then
      reusability_score=$(jq -r '.reusability.score // 50' "$config_file" 2>/dev/null)
      reusability_level=$(jq -r '.reusability.level // "unknown"' "$config_file" 2>/dev/null)
      extends_framework=$(jq -r '.extends // "none"' "$config_file" 2>/dev/null)

      if [[ "$extends_framework" != "none" && "$extends_framework" != "null" ]]; then
        extends_framework=true
      else
        extends_framework=false
      fi
    fi
  fi

  # Check for project-specific patterns in skill file
  if [[ -f "$skill_file" ]]; then
    for pattern in "${PROJECT_PATTERNS[@]}"; do
      count=$(grep -E -o "$pattern" "$skill_file" 2>/dev/null | wc -l | tr -d ' ')
      project_references=$((project_references + count))
    done
  fi

  # Determine level if not specified in config
  if [[ "$reusability_level" == "unknown" ]]; then
    if [[ "$skill_name" == *"-framework" ]] || [[ "$skill_dir" == *"/framework/"* ]]; then
      reusability_level="framework"
      reusability_score=90
    elif [[ $extends_framework == true ]]; then
      reusability_level="implementation"
      reusability_score=30
    elif [[ $project_references -gt 10 ]]; then
      reusability_level="project-specific"
      reusability_score=10
    elif [[ $project_references -gt 3 ]]; then
      reusability_level="implementation"
      reusability_score=40
    else
      reusability_level="generic"
      reusability_score=80
    fi
  fi

  # Output results
  echo "$skill_name|$reusability_level|$reusability_score|$has_config|$extends_framework|$project_references"
}

# Function: Generate text report
generate_text_report() {
  echo -e "${BLUE}=====================================================${NC}"
  echo -e "${BLUE}    Cortex Skills - Reusability Assessment${NC}"
  echo -e "${BLUE}=====================================================${NC}"
  echo ""
  echo "Total Skills: $TOTAL_SKILLS"
  echo ""

  echo -e "${GREEN}✓ GENERIC SKILLS (${#GENERIC_LIST[@]})${NC}"
  echo "  Fully reusable across any project"
  for skill in "${GENERIC_LIST[@]}"; do
    echo "    - $skill"
  done
  echo ""

  echo -e "${GREEN}✓ FRAMEWORK SKILLS (${#FRAMEWORK_LIST[@]})${NC}"
  echo "  Reusable patterns for implementations"
  for skill in "${FRAMEWORK_LIST[@]}"; do
    echo "    - $skill"
  done
  echo ""

  echo -e "${YELLOW}⚠ IMPLEMENTATION SKILLS (${#IMPLEMENTATION_LIST[@]})${NC}"
  echo "  Project-specific, but extend generic frameworks"
  for skill in "${IMPLEMENTATION_LIST[@]}"; do
    echo "    - $skill"
  done
  echo ""

  echo -e "${RED}✗ PROJECT-SPECIFIC SKILLS (${#PROJECT_SPECIFIC_LIST[@]})${NC}"
  echo "  Hardcoded to specific project (should be moved)"
  for skill in "${PROJECT_SPECIFIC_LIST[@]}"; do
    echo "    - $skill"
  done
  echo ""

  # Calculate percentages
  local generic_pct=$((($GENERIC_SKILLS + $FRAMEWORK_SKILLS) * 100 / $TOTAL_SKILLS))
  local implementation_pct=$(($IMPLEMENTATION_SKILLS * 100 / $TOTAL_SKILLS))
  local project_pct=$(($PROJECT_SPECIFIC_SKILLS * 100 / $TOTAL_SKILLS))

  echo -e "${BLUE}Summary:${NC}"
  echo "  Reusable (Generic + Framework): $generic_pct%"
  echo "  Implementations: $implementation_pct%"
  echo "  Project-Specific: $project_pct%"
  echo ""

  if [[ $PROJECT_SPECIFIC_SKILLS -gt 0 ]]; then
    echo -e "${YELLOW}Recommendation:${NC}"
    echo "  Move $PROJECT_SPECIFIC_SKILLS project-specific skills to their respective project repositories."
    echo "  This will improve reusability and maintainability."
  fi
}

# Function: Generate JSON report
generate_json_report() {
  cat <<EOF
{
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "total_skills": $TOTAL_SKILLS,
  "summary": {
    "generic": $GENERIC_SKILLS,
    "framework": $FRAMEWORK_SKILLS,
    "implementation": $IMPLEMENTATION_SKILLS,
    "project_specific": $PROJECT_SPECIFIC_SKILLS
  },
  "percentages": {
    "reusable": $(( ($GENERIC_SKILLS + $FRAMEWORK_SKILLS) * 100 / $TOTAL_SKILLS )),
    "implementation": $(( $IMPLEMENTATION_SKILLS * 100 / $TOTAL_SKILLS )),
    "project_specific": $(( $PROJECT_SPECIFIC_SKILLS * 100 / $TOTAL_SKILLS ))
  },
  "skills": {
    "generic": $(printf '%s\n' "${GENERIC_LIST[@]}" | jq -R . | jq -s .),
    "framework": $(printf '%s\n' "${FRAMEWORK_LIST[@]}" | jq -R . | jq -s .),
    "implementation": $(printf '%s\n' "${IMPLEMENTATION_LIST[@]}" | jq -R . | jq -s .),
    "project_specific": $(printf '%s\n' "${PROJECT_SPECIFIC_LIST[@]}" | jq -R . | jq -s .)
  }
}
EOF
}

# Main execution
main() {
  echo "Scanning skills in: $SKILLS_DIR" >&2
  echo "" >&2

  # Find all skill directories (containing SKILL.md or skill.json)
  while IFS= read -r -d '' skill_dir; do
    TOTAL_SKILLS=$((TOTAL_SKILLS + 1))

    # Analyze skill
    result=$(detect_reusability "$skill_dir")

    # Parse results
    IFS='|' read -r name level score has_config extends refs <<< "$result"

    # Categorize
    case $level in
      generic)
        GENERIC_SKILLS=$((GENERIC_SKILLS + 1))
        GENERIC_LIST+=("$name (score: $score)")
        ;;
      framework)
        FRAMEWORK_SKILLS=$((FRAMEWORK_SKILLS + 1))
        FRAMEWORK_LIST+=("$name (score: $score)")
        ;;
      implementation)
        IMPLEMENTATION_SKILLS=$((IMPLEMENTATION_SKILLS + 1))
        IMPLEMENTATION_LIST+=("$name → extends: $extends (score: $score)")
        ;;
      project-specific)
        PROJECT_SPECIFIC_SKILLS=$((PROJECT_SPECIFIC_SKILLS + 1))
        PROJECT_SPECIFIC_LIST+=("$name (refs: $refs, score: $score)")
        ;;
    esac

    if [[ "$VERBOSE" == true ]]; then
      echo "  Analyzed: $name ($level, score: $score)" >&2
    fi

  done < <(find "$SKILLS_DIR" -type f \( -name "SKILL.md" -o -name "skill.json" \) -exec dirname {} \; | sort -u | tr '\n' '\0')

  echo "" >&2

  # Generate report based on format
  case $OUTPUT_FORMAT in
    json)
      generate_json_report
      ;;
    *)
      generate_text_report
      ;;
  esac
}

# Run main
main
