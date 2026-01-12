#!/usr/bin/env python3
"""
Skill Audit Script

Analyzes a Claude Code skill for quality, compliance, and best practices.

Usage:
    python skill-audit.py path/to/skill/

Exit codes:
    0 - All checks passed
    1 - Some checks failed (warnings)
    2 - Critical failures (must fix)
"""

import sys
import os
import re
import json
from pathlib import Path
from typing import List, Dict, Tuple

class SkillAuditor:
    def __init__(self, skill_path: str):
        self.skill_path = Path(skill_path)
        self.skill_md = self.skill_path / "SKILL.md"
        self.issues = {
            "critical": [],
            "warning": [],
            "info": []
        }

    def audit(self) -> Dict:
        """Run all audit checks"""
        print(f"\n🔍 Auditing skill: {self.skill_path.name}\n")

        # Check if SKILL.md exists
        if not self.skill_md.exists():
            self.issues["critical"].append("SKILL.md not found")
            return self.report()

        # Run all checks
        self.check_yaml_frontmatter()
        self.check_line_count()
        self.check_token_usage()
        self.check_description()
        self.check_required_sections()
        self.check_examples()
        self.check_versioning()
        self.check_scripts()

        return self.report()

    def check_yaml_frontmatter(self):
        """Validate YAML frontmatter"""
        content = self.skill_md.read_text()

        # Check if frontmatter exists
        if not content.startswith("---\n"):
            self.issues["critical"].append("Missing YAML frontmatter")
            return

        # Extract frontmatter
        try:
            frontmatter_end = content.index("\n---\n", 4)
            frontmatter = content[4:frontmatter_end]
        except ValueError:
            self.issues["critical"].append("Invalid YAML frontmatter (missing closing ---)")
            return

        # Check for tabs (YAML doesn't allow tabs)
        if "\t" in frontmatter:
            self.issues["critical"].append("YAML frontmatter contains tabs (use spaces)")

        # Check required fields
        if "name:" not in frontmatter:
            self.issues["critical"].append("Missing 'name' in frontmatter")

        if "description:" not in frontmatter:
            self.issues["critical"].append("Missing 'description' in frontmatter")
        else:
            # Extract description
            desc_match = re.search(r'description:\s*["\']?(.+?)["\']?\n', frontmatter, re.DOTALL)
            if desc_match:
                description = desc_match.group(1).strip()
                if len(description) > 1024:
                    self.issues["warning"].append(f"Description too long ({len(description)} chars, max 1024)")

        # Check recommended fields
        if "version:" not in frontmatter:
            self.issues["warning"].append("Missing 'version' in frontmatter (recommended)")

        if "last_updated:" not in frontmatter:
            self.issues["warning"].append("Missing 'last_updated' in frontmatter (recommended)")

        print("✓ YAML frontmatter check complete")

    def check_line_count(self):
        """Check if SKILL.md exceeds 500 lines"""
        line_count = sum(1 for _ in self.skill_md.open())

        if line_count > 500:
            self.issues["warning"].append(
                f"SKILL.md has {line_count} lines (> 500). "
                "Consider using progressive disclosure (REFERENCE.md, EXAMPLES.md)"
            )
        else:
            self.issues["info"].append(f"Line count: {line_count}/500 ✓")

        print(f"✓ Line count: {line_count} lines")

    def check_token_usage(self):
        """Estimate token usage"""
        content = self.skill_md.read_text()
        char_count = len(content)
        # Rough estimate: 1 token ≈ 4 characters
        estimated_tokens = char_count // 4

        if estimated_tokens > 5000:
            self.issues["warning"].append(
                f"Estimated {estimated_tokens} tokens (> 5000). "
                "Consider splitting with progressive disclosure"
            )
        else:
            self.issues["info"].append(f"Token estimate: ~{estimated_tokens}/5000 ✓")

        print(f"✓ Token estimate: ~{estimated_tokens} tokens")

    def check_description(self):
        """Check description quality"""
        content = self.skill_md.read_text()

        # Extract description from frontmatter
        desc_match = re.search(r'description:\s*["\']?(.+?)["\']?\n---', content, re.DOTALL)
        if not desc_match:
            self.issues["critical"].append("Could not extract description")
            return

        description = desc_match.group(1).strip().strip('"\'')

        # Check for trigger keywords (action verbs)
        action_verbs = ["create", "analyze", "optimize", "validate", "generate", "test",
                       "deploy", "configure", "monitor", "manage", "integrate", "implement"]
        has_action_verb = any(verb in description.lower() for verb in action_verbs)

        if not has_action_verb:
            self.issues["warning"].append(
                "Description missing action verbs (create, analyze, optimize, etc.)"
            )

        # Check for "Use when" clause
        if "use when" not in description.lower():
            self.issues["warning"].append(
                "Description missing 'Use when' clause for better discovery"
            )

        # Count potential trigger keywords
        words = description.lower().split()
        if len(words) < 20:
            self.issues["warning"].append(
                f"Description may be too short ({len(words)} words). "
                "Add more trigger keywords for better discovery."
            )

        print("✓ Description check complete")

    def check_required_sections(self):
        """Check for required sections"""
        content = self.skill_md.read_text()

        required_sections = [
            ("## When to Use", "When to Use section"),
            ("## Quick Reference", "Quick Reference section"),
            ("## Troubleshooting", "Troubleshooting section"),
        ]

        for pattern, name in required_sections:
            if pattern not in content:
                self.issues["warning"].append(f"Missing {name}")

        # Check for related resources
        if "## Related Resources" not in content and "## Related" not in content:
            self.issues["info"].append("Consider adding 'Related Resources' section")

        print("✓ Required sections check complete")

    def check_examples(self):
        """Check if code examples exist"""
        content = self.skill_md.read_text()

        # Count code blocks
        code_blocks = content.count("```")
        if code_blocks < 2:  # At least one code block (opening and closing)
            self.issues["warning"].append("No code examples found. Add at least one working example.")
        else:
            self.issues["info"].append(f"Found {code_blocks // 2} code examples ✓")

        # Check Quick Reference has example
        quick_ref_match = re.search(r'## Quick Reference\s+```', content)
        if not quick_ref_match:
            self.issues["warning"].append("Quick Reference section missing code example")

        print("✓ Examples check complete")

    def check_versioning(self):
        """Check for versioning and changelog"""
        content = self.skill_md.read_text()

        # Check for version in frontmatter
        has_version = re.search(r'version:\s*["\']?\d+\.\d+\.\d+', content)
        if not has_version:
            self.issues["warning"].append("No semantic version found (use X.Y.Z format)")

        # Check for CHANGELOG.md
        changelog_path = self.skill_path / "CHANGELOG.md"
        if not changelog_path.exists():
            self.issues["info"].append("No CHANGELOG.md found (recommended for tracking changes)")
        else:
            self.issues["info"].append("CHANGELOG.md exists ✓")

        print("✓ Versioning check complete")

    def check_scripts(self):
        """Check scripts directory and permissions"""
        scripts_dir = self.skill_path / "scripts"

        if not scripts_dir.exists():
            self.issues["info"].append("No scripts directory (OK if not needed)")
            print("✓ No scripts directory")
            return

        scripts = list(scripts_dir.glob("*.py")) + list(scripts_dir.glob("*.sh"))

        if not scripts:
            self.issues["warning"].append("scripts/ directory exists but is empty")
            return

        # Check execute permissions
        for script in scripts:
            if script.suffix == ".sh" and not os.access(script, os.X_OK):
                self.issues["warning"].append(
                    f"Script {script.name} missing execute permission (run: chmod +x {script})"
                )

        self.issues["info"].append(f"Found {len(scripts)} script(s) ✓")
        print(f"✓ Scripts check: {len(scripts)} script(s) found")

    def report(self) -> Dict:
        """Generate and print audit report"""
        print("\n" + "="*60)
        print("AUDIT REPORT")
        print("="*60 + "\n")

        # Print issues by severity
        if self.issues["critical"]:
            print("🚨 CRITICAL ISSUES (Must Fix):")
            for issue in self.issues["critical"]:
                print(f"   ❌ {issue}")
            print()

        if self.issues["warning"]:
            print("⚠️  WARNINGS:")
            for issue in self.issues["warning"]:
                print(f"   ⚠️  {issue}")
            print()

        if self.issues["info"]:
            print("ℹ️  INFO:")
            for issue in self.issues["info"]:
                print(f"   ℹ️  {issue}")
            print()

        # Summary
        total_issues = len(self.issues["critical"]) + len(self.issues["warning"])

        if self.issues["critical"]:
            print("❌ AUDIT FAILED - Critical issues must be fixed")
            return {"status": "failed", "issues": self.issues, "exit_code": 2}
        elif self.issues["warning"]:
            print("⚠️  AUDIT PASSED WITH WARNINGS - Consider addressing warnings")
            return {"status": "warning", "issues": self.issues, "exit_code": 1}
        else:
            print("✅ AUDIT PASSED - All checks successful")
            return {"status": "passed", "issues": self.issues, "exit_code": 0}


def main():
    if len(sys.argv) < 2:
        print("Usage: python skill-audit.py path/to/skill/")
        print("\nExample:")
        print("  python skill-audit.py .claude/skills/database-migration-manager/")
        sys.exit(1)

    skill_path = sys.argv[1]

    if not os.path.exists(skill_path):
        print(f"❌ Error: Path not found: {skill_path}")
        sys.exit(2)

    auditor = SkillAuditor(skill_path)
    result = auditor.audit()

    # Output JSON if --json flag
    if "--json" in sys.argv:
        print("\n" + json.dumps(result, indent=2))

    sys.exit(result["exit_code"])


if __name__ == "__main__":
    main()
