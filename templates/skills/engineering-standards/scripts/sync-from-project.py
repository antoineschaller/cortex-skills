#!/usr/bin/env python3
"""
Extract patterns from existing project and sync to standards.

This script analyzes an existing project, extracts engineering patterns,
and optionally updates the engineering standards with new discoveries.

Usage:
    python sync-from-project.py --source-project /path/to/project --extract hooks,testing
    python sync-from-project.py --source-project /path/to/project --extract all --update-standards
    python sync-from-project.py --help

Exit codes:
    0 - Success
    1 - Error during extraction
"""

import argparse
import json
import re
import sys
from collections import defaultdict
from dataclasses import dataclass, field
from pathlib import Path
from typing import Dict, List, Optional, Set


@dataclass
class ExtractedPattern:
    """A discovered pattern from the source project."""
    category: str
    name: str
    description: str
    code_example: Optional[str] = None
    file_location: Optional[str] = None
    is_new: bool = False  # Not in current standards


@dataclass
class ExtractionReport:
    """Report of extracted patterns."""
    project_path: Path
    patterns: List[ExtractedPattern] = field(default_factory=list)
    stats: Dict[str, int] = field(default_factory=lambda: defaultdict(int))
    new_patterns: List[ExtractedPattern] = field(default_factory=list)


class PatternExtractor:
    """Extract engineering patterns from existing projects."""

    def __init__(self, source_project: Path, standards_path: Path):
        self.source_project = source_project
        self.standards_path = standards_path
        self.report = ExtractionReport(project_path=source_project)

    def _read_file(self, path: Path) -> Optional[str]:
        """Read file content safely."""
        try:
            return path.read_text()
        except Exception:
            return None

    def _file_exists(self, relative_path: str) -> bool:
        """Check if file exists in source project."""
        return (self.source_project / relative_path).exists()

    def extract_hooks(self):
        """Extract Git hook patterns."""
        print("🔍 Extracting hook patterns...")

        # Check for lefthook.yml
        lefthook_path = None
        for name in ['.lefthook.yml', 'lefthook.yml']:
            if self._file_exists(name):
                lefthook_path = self.source_project / name
                break

        if not lefthook_path:
            print("  ⚠ No lefthook.yml found")
            return

        content = self._read_file(lefthook_path)
        if not content:
            return

        # Extract pre-commit commands
        pre_commit_match = re.search(r'pre-commit:(.*?)(?=\npre-push:|$)', content, re.DOTALL)
        if pre_commit_match:
            commands_section = pre_commit_match.group(1)
            commands = re.findall(r'^\s{4}(\w+[-\w]*):', commands_section, re.MULTILINE)

            for cmd in commands:
                self.report.patterns.append(ExtractedPattern(
                    category='hooks',
                    name=f'pre-commit-{cmd}',
                    description=f'Pre-commit hook: {cmd}',
                    file_location=str(lefthook_path.relative_to(self.source_project))
                ))
                self.report.stats['hooks_pre_commit'] += 1

        # Extract pre-push commands
        pre_push_match = re.search(r'pre-push:(.*?)(?=\npost-|$)', content, re.DOTALL)
        if pre_push_match:
            commands_section = pre_push_match.group(1)
            commands = re.findall(r'^\s{4}(\w+[-\w]*):', commands_section, re.MULTILINE)

            for cmd in commands:
                self.report.patterns.append(ExtractedPattern(
                    category='hooks',
                    name=f'pre-push-{cmd}',
                    description=f'Pre-push hook: {cmd}',
                    file_location=str(lefthook_path.relative_to(self.source_project))
                ))
                self.report.stats['hooks_pre_push'] += 1

        # Check Claude Code hooks
        if self._file_exists('.claude/settings.json'):
            settings_path = self.source_project / '.claude/settings.json'
            settings = self._read_file(settings_path)
            if settings:
                try:
                    settings_json = json.loads(settings)
                    if 'hooks' in settings_json:
                        for hook_type in ['PreToolUse', 'PostToolUse']:
                            if hook_type in settings_json['hooks']:
                                count = len(settings_json['hooks'][hook_type])
                                self.report.stats[f'claude_hooks_{hook_type}'] = count
                                self.report.patterns.append(ExtractedPattern(
                                    category='hooks',
                                    name=f'claude-{hook_type}',
                                    description=f'Claude Code {hook_type} hooks ({count} total)',
                                    file_location='.claude/settings.json'
                                ))
                except json.JSONDecodeError:
                    pass

        print(f"  ✓ Found {len([p for p in self.report.patterns if p.category == 'hooks'])} hook patterns")

    def extract_testing(self):
        """Extract testing patterns."""
        print("🔍 Extracting testing patterns...")

        # Check for Vitest config
        vitest_paths = ['vitest.config.ts', 'vitest.config.js', 'apps/web/vitest.config.ts']
        for path in vitest_paths:
            if self._file_exists(path):
                config_path = self.source_project / path
                content = self._read_file(config_path)
                if content:
                    # Check for coverage thresholds
                    if 'thresholds' in content:
                        # Extract threshold values
                        lines_match = re.search(r'lines:\s*(\d+)', content)
                        if lines_match:
                            threshold = lines_match.group(1)
                            self.report.patterns.append(ExtractedPattern(
                                category='testing',
                                name='vitest-coverage-threshold',
                                description=f'Vitest coverage threshold: {threshold}%',
                                code_example=f'thresholds: {{ lines: {threshold} }}',
                                file_location=path
                            ))
                            self.report.stats['testing_coverage_threshold'] = int(threshold)

                    # Check for dual-client pattern
                    if 'userClient' in content and 'adminClient' in content:
                        self.report.patterns.append(ExtractedPattern(
                            category='testing',
                            name='dual-client-architecture',
                            description='Dual-client test architecture (user + admin)',
                            file_location=path
                        ))
                        self.report.stats['testing_dual_client'] = 1

                    # Check for test environment
                    env_match = re.search(r"environment:\s*['\"](\w+)['\"]", content)
                    if env_match:
                        env = env_match.group(1)
                        self.report.patterns.append(ExtractedPattern(
                            category='testing',
                            name=f'test-environment-{env}',
                            description=f'Test environment: {env}',
                            file_location=path
                        ))

                    self.report.stats['testing_vitest'] = 1
                    break

        # Check for Playwright
        if self._file_exists('playwright.config.ts'):
            self.report.patterns.append(ExtractedPattern(
                category='testing',
                name='playwright-e2e',
                description='Playwright E2E testing configured',
                file_location='playwright.config.ts'
            ))
            self.report.stats['testing_playwright'] = 1

        print(f"  ✓ Found {len([p for p in self.report.patterns if p.category == 'testing'])} testing patterns")

    def extract_quality_gates(self):
        """Extract quality gate patterns."""
        print("🔍 Extracting quality gate patterns...")

        # Check ESLint config
        eslint_paths = ['eslint.config.mjs', '.eslintrc.json', 'apps/web/eslint.config.mjs']
        for path in eslint_paths:
            if self._file_exists(path):
                content = self._read_file(self.source_project / path)
                if content:
                    # Extract custom plugins
                    plugin_matches = re.findall(r"['\"](\w+[-\w]*)['\"]:\s*\w+", content)
                    custom_plugins = [p for p in plugin_matches if p not in ['typescript', 'react', 'next']]

                    for plugin in custom_plugins:
                        self.report.patterns.append(ExtractedPattern(
                            category='quality_gates',
                            name=f'eslint-plugin-{plugin}',
                            description=f'Custom ESLint plugin: {plugin}',
                            file_location=path
                        ))

                    self.report.stats['quality_eslint_plugins'] = len(custom_plugins)
                    break

        # Check TypeScript strict mode
        if self._file_exists('tsconfig.json'):
            content = self._read_file(self.source_project / 'tsconfig.json')
            if content and '"strict": true' in content:
                self.report.patterns.append(ExtractedPattern(
                    category='quality_gates',
                    name='typescript-strict-mode',
                    description='TypeScript strict mode enabled',
                    file_location='tsconfig.json'
                ))
                self.report.stats['quality_typescript_strict'] = 1

        # Check quality script in package.json
        if self._file_exists('package.json'):
            content = self._read_file(self.source_project / 'package.json')
            if content:
                try:
                    pkg = json.loads(content)
                    if 'scripts' in pkg and 'quality' in pkg['scripts']:
                        quality_cmd = pkg['scripts']['quality']
                        self.report.patterns.append(ExtractedPattern(
                            category='quality_gates',
                            name='quality-command',
                            description='Quality command configured',
                            code_example=quality_cmd,
                            file_location='package.json'
                        ))
                        self.report.stats['quality_command'] = 1
                except json.JSONDecodeError:
                    pass

        print(f"  ✓ Found {len([p for p in self.report.patterns if p.category == 'quality_gates'])} quality patterns")

    def extract_architectural_patterns(self):
        """Extract architectural patterns from code."""
        print("🔍 Extracting architectural patterns...")

        # Look for service files
        service_files = list(self.source_project.rglob('*service.ts'))
        if service_files:
            # Sample first service file
            sample_file = service_files[0]
            content = self._read_file(sample_file)
            if content:
                # Check for Result pattern
                if 'Result<' in content or 'success: true' in content:
                    self.report.patterns.append(ExtractedPattern(
                        category='patterns',
                        name='result-pattern',
                        description='Result pattern (no exceptions)',
                        code_example='type Result<T, E> = { success: true; data: T } | { success: false; error: E }',
                        file_location=str(sample_file.relative_to(self.source_project))
                    ))
                    self.report.stats['patterns_result'] = 1

                # Check for BaseService pattern
                if 'BaseService' in content or 'extends Service' in content:
                    self.report.patterns.append(ExtractedPattern(
                        category='patterns',
                        name='base-service',
                        description='BaseService pattern for services',
                        file_location=str(sample_file.relative_to(self.source_project))
                    ))
                    self.report.stats['patterns_base_service'] = 1

            self.report.stats['patterns_services_count'] = len(service_files)

        # Look for server actions
        action_files = list(self.source_project.rglob('*actions.ts'))
        if action_files:
            sample_file = action_files[0]
            content = self._read_file(sample_file)
            if content:
                # Check for withAuthParams
                if 'withAuthParams' in content:
                    self.report.patterns.append(ExtractedPattern(
                        category='patterns',
                        name='withAuthParams-wrapper',
                        description='withAuthParams wrapper for server actions',
                        file_location=str(sample_file.relative_to(self.source_project))
                    ))
                    self.report.stats['patterns_auth_wrappers'] = 1

                # Check for Zod validation
                if 'z.object' in content or 'ZodSchema' in content:
                    self.report.patterns.append(ExtractedPattern(
                        category='patterns',
                        name='zod-validation',
                        description='Zod schema validation in server actions',
                        file_location=str(sample_file.relative_to(self.source_project))
                    ))
                    self.report.stats['patterns_zod'] = 1

        print(f"  ✓ Found {len([p for p in self.report.patterns if p.category == 'patterns'])} architectural patterns")

    def extract_documentation(self):
        """Extract documentation patterns."""
        print("🔍 Extracting documentation patterns...")

        # Check CLAUDE.md structure
        if self._file_exists('CLAUDE.md'):
            content = self._read_file(self.source_project / 'CLAUDE.md')
            if content:
                # Extract sections
                sections = re.findall(r'^## (.+)$', content, re.MULTILINE)
                for section in sections:
                    self.report.patterns.append(ExtractedPattern(
                        category='documentation',
                        name=f'claude-md-section-{section.lower().replace(" ", "-")}',
                        description=f'CLAUDE.md section: {section}',
                        file_location='CLAUDE.md'
                    ))

                self.report.stats['docs_claude_sections'] = len(sections)

        # Check WIP directory
        wip_dirs = ['docs/wip/active', 'docs/wip']
        for wip_dir in wip_dirs:
            if self._file_exists(wip_dir):
                wip_path = self.source_project / wip_dir
                if wip_path.is_dir():
                    wip_files = list(wip_path.glob('*.md'))
                    self.report.stats['docs_wip_files'] = len(wip_files)

                    # Check naming pattern
                    wip_pattern_files = [f for f in wip_files if f.name.startswith('WIP_')]
                    if wip_pattern_files:
                        self.report.patterns.append(ExtractedPattern(
                            category='documentation',
                            name='wip-naming-pattern',
                            description=f'WIP file naming pattern (WIP_*)',
                            code_example='WIP_{gerund}_{YYYY_MM_DD}.md',
                            file_location=wip_dir
                        ))
                break

        print(f"  ✓ Found {len([p for p in self.report.patterns if p.category == 'documentation'])} documentation patterns")

    def extract_migrations(self):
        """Extract migration patterns."""
        print("🔍 Extracting migration patterns...")

        migration_dirs = ['supabase/migrations', 'apps/web/supabase/migrations']
        for migration_dir in migration_dirs:
            if self._file_exists(migration_dir):
                migration_path = self.source_project / migration_dir
                if migration_path.is_dir():
                    migration_files = list(migration_path.glob('*.sql'))
                    self.report.stats['migrations_count'] = len(migration_files)

                    # Sample first migration
                    if migration_files:
                        sample_file = migration_files[0]
                        content = self._read_file(sample_file)
                        if content:
                            # Check for idempotency patterns
                            if 'IF NOT EXISTS' in content:
                                self.report.patterns.append(ExtractedPattern(
                                    category='migrations',
                                    name='if-not-exists-pattern',
                                    description='IF NOT EXISTS for idempotency',
                                    code_example='CREATE TABLE IF NOT EXISTS',
                                    file_location=str(sample_file.relative_to(self.source_project))
                                ))

                            if 'DO $$' in content:
                                self.report.patterns.append(ExtractedPattern(
                                    category='migrations',
                                    name='do-block-pattern',
                                    description='DO $$ block for complex idempotency',
                                    file_location=str(sample_file.relative_to(self.source_project))
                                ))

                            # Check for RLS patterns
                            if 'CREATE POLICY' in content:
                                if 'is_super_admin()' in content:
                                    self.report.patterns.append(ExtractedPattern(
                                        category='migrations',
                                        name='super-admin-bypass',
                                        description='Super admin bypass in RLS policies',
                                        code_example='OR is_super_admin()',
                                        file_location=str(sample_file.relative_to(self.source_project))
                                    ))

                break

        print(f"  ✓ Found {len([p for p in self.report.patterns if p.category == 'migrations'])} migration patterns")

    def extract_all(self):
        """Extract all patterns."""
        self.extract_hooks()
        self.extract_testing()
        self.extract_quality_gates()
        self.extract_architectural_patterns()
        self.extract_documentation()
        self.extract_migrations()

    def compare_with_standards(self):
        """Compare extracted patterns with current standards."""
        print("\n🔍 Comparing with current standards...")

        # Load existing guides
        guides = {
            'hooks': self.standards_path / 'HOOKS_GUIDE.md',
            'testing': self.standards_path / 'TESTING_GUIDE.md',
            'quality_gates': self.standards_path / 'QUALITY_GATES_GUIDE.md',
            'patterns': self.standards_path / 'PATTERNS_LIBRARY.md',
            'documentation': self.standards_path / 'DOCUMENTATION_GUIDE.md',
            'migrations': self.standards_path / 'SECURITY_GUIDE.md',
        }

        new_patterns_count = 0

        for pattern in self.report.patterns:
            if pattern.category in guides:
                guide_path = guides[pattern.category]
                if guide_path.exists():
                    guide_content = guide_path.read_text()

                    # Simple check: is pattern name mentioned in guide?
                    if pattern.name not in guide_content and pattern.description not in guide_content:
                        pattern.is_new = True
                        self.report.new_patterns.append(pattern)
                        new_patterns_count += 1

        print(f"  ✓ Found {new_patterns_count} new patterns not in current standards")

    def generate_report(self):
        """Generate extraction report."""
        print("\n" + "="*70)
        print("  PATTERN EXTRACTION REPORT")
        print("="*70)
        print()
        print(f"📂 Source Project: {self.source_project.name}")
        print(f"📊 Total Patterns Extracted: {len(self.report.patterns)}")
        print()

        # Group patterns by category
        by_category = defaultdict(list)
        for pattern in self.report.patterns:
            by_category[pattern.category].append(pattern)

        for category, patterns in sorted(by_category.items()):
            print(f"✓ {category.upper()}: {len(patterns)} patterns")
            for pattern in patterns[:3]:  # Show first 3
                print(f"  - {pattern.description}")
            if len(patterns) > 3:
                print(f"  ... and {len(patterns) - 3} more")
            print()

        # Show stats
        if self.report.stats:
            print("📈 Statistics:")
            for key, value in sorted(self.report.stats.items()):
                print(f"  - {key}: {value}")
            print()

        # Show new patterns
        if self.report.new_patterns:
            print(f"✨ NEW PATTERNS FOUND ({len(self.report.new_patterns)}):")
            print()
            for pattern in self.report.new_patterns[:10]:
                print(f"+ {pattern.category.upper()}: {pattern.description}")
                if pattern.code_example:
                    print(f"  Example: {pattern.code_example}")
                print(f"  Location: {pattern.file_location}")
                print()

            if len(self.report.new_patterns) > 10:
                print(f"... and {len(self.report.new_patterns) - 10} more new patterns")
                print()

        print("="*70)
        print()


def main():
    parser = argparse.ArgumentParser(
        description='Extract patterns from existing project',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  # Extract all patterns
  python sync-from-project.py --source-project /path/to/ballee --extract all

  # Extract specific categories
  python sync-from-project.py --source-project /path/to/ballee --extract hooks,testing

  # Dry run (preview only)
  python sync-from-project.py --source-project /path/to/ballee --extract all --dry-run
        """
    )

    parser.add_argument(
        '--source-project',
        type=Path,
        required=True,
        help='Path to source project to extract from'
    )
    parser.add_argument(
        '--extract',
        default='all',
        help='What to extract: all, hooks, testing, quality, patterns, docs, migrations (comma-separated)'
    )
    parser.add_argument(
        '--dry-run',
        action='store_true',
        help='Preview extraction without updating standards'
    )
    parser.add_argument(
        '--update-standards',
        action='store_true',
        help='Update standards with new patterns (requires approval)'
    )

    args = parser.parse_args()

    # Validate source project exists
    if not args.source_project.exists():
        print(f"❌ Error: Source project not found: {args.source_project}")
        sys.exit(1)

    # Find engineering-standards skill path
    script_dir = Path(__file__).parent.parent

    # Extract patterns
    extractor = PatternExtractor(args.source_project, script_dir)

    # Determine what to extract
    extract_categories = args.extract.split(',') if args.extract != 'all' else ['all']

    if 'all' in extract_categories:
        extractor.extract_all()
    else:
        if 'hooks' in extract_categories:
            extractor.extract_hooks()
        if 'testing' in extract_categories:
            extractor.extract_testing()
        if 'quality' in extract_categories:
            extractor.extract_quality_gates()
        if 'patterns' in extract_categories:
            extractor.extract_architectural_patterns()
        if 'docs' in extract_categories:
            extractor.extract_documentation()
        if 'migrations' in extract_categories:
            extractor.extract_migrations()

    # Compare with standards
    extractor.compare_with_standards()

    # Generate report
    extractor.generate_report()

    # Update standards (if requested and not dry-run)
    if args.update_standards and not args.dry_run:
        if extractor.report.new_patterns:
            print("⚠️  Updating standards is not yet implemented.")
            print("   New patterns have been identified and can be manually added to guides.")
        else:
            print("✓ No new patterns to update")

    sys.exit(0)


if __name__ == '__main__':
    main()
