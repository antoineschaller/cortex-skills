#!/usr/bin/env python3
"""
Validate project compliance with engineering standards.

This script checks if a project follows engineering standards across
8 categories with 30+ validation checks.

Usage:
    python validate-compliance.py [--project-path PATH] [--report-format FORMAT]
    python validate-compliance.py --help

Exit codes:
    0 - Full compliance (95%+)
    1 - Warnings present (70-94%)
    2 - Critical failures (<70%)
"""

import argparse
import json
import os
import sys
from dataclasses import dataclass, field
from pathlib import Path
from typing import Dict, List, Optional, Tuple


@dataclass
class ValidationResult:
    """Result of a single validation check."""
    category: str
    check_name: str
    passed: bool
    severity: str  # 'critical', 'warning', 'info'
    message: str
    details: Optional[str] = None


@dataclass
class CategoryResult:
    """Aggregated results for a validation category."""
    name: str
    weight: int
    checks_passed: int = 0
    checks_failed: int = 0
    checks_warned: int = 0
    score: float = 0.0
    results: List[ValidationResult] = field(default_factory=list)


class ComplianceValidator:
    """Validates project compliance with engineering standards."""

    def __init__(self, project_path: Path, config_path: Path):
        self.project_path = project_path
        self.config_path = config_path
        self.config = self._load_config()
        self.results: Dict[str, CategoryResult] = {}

    def _load_config(self) -> dict:
        """Load rules-config.json."""
        with open(self.config_path / 'config' / 'rules-config.json') as f:
            return json.load(f)

    def _add_result(self, result: ValidationResult):
        """Add validation result to category."""
        category = result.category
        if category not in self.results:
            weight = self.config['validation_categories'].get(category, {}).get('weight', 10)
            self.results[category] = CategoryResult(name=category, weight=weight)

        cat = self.results[category]
        cat.results.append(result)

        if result.passed:
            cat.checks_passed += 1
        elif result.severity == 'critical':
            cat.checks_failed += 1
        else:
            cat.checks_warned += 1

    def _file_exists(self, path: str) -> bool:
        """Check if file exists in project."""
        return (self.project_path / path).exists()

    def _read_file(self, path: str) -> Optional[str]:
        """Read file content if exists."""
        file_path = self.project_path / path
        if file_path.exists():
            try:
                return file_path.read_text()
            except Exception:
                return None
        return None

    def _check_file_contains(self, path: str, pattern: str) -> bool:
        """Check if file contains pattern."""
        content = self._read_file(path)
        return content is not None and pattern in content

    # ========== Hooks Validation ==========

    def validate_hooks(self):
        """Validate Git hooks and Claude hooks configuration."""
        if not self.config['hooks']['enabled']:
            return

        # Check lefthook.yml exists (try both .lefthook.yml and lefthook.yml)
        lefthook_path = None
        if self._file_exists('.lefthook.yml'):
            lefthook_path = '.lefthook.yml'
        elif self._file_exists('lefthook.yml'):
            lefthook_path = 'lefthook.yml'

        lefthook_exists = lefthook_path is not None
        self._add_result(ValidationResult(
            category='hooks',
            check_name='lefthook_config_exists',
            passed=lefthook_exists,
            severity='critical',
            message='lefthook.yml configuration file',
            details='Not found' if not lefthook_exists else f'Found: {lefthook_path}'
        ))

        if lefthook_exists:
            # Check pre-commit commands
            for cmd in self.config['hooks']['pre_commit_commands']:
                has_cmd = self._check_file_contains(lefthook_path, f'{cmd}:')
                self._add_result(ValidationResult(
                    category='hooks',
                    check_name=f'pre_commit_{cmd}',
                    passed=has_cmd,
                    severity='warning',
                    message=f'Pre-commit hook: {cmd}',
                    details='Missing' if not has_cmd else 'Configured'
                ))

            # Check pre-push commands
            for cmd in self.config['hooks']['pre_push_commands']:
                has_cmd = self._check_file_contains(lefthook_path, f'{cmd}:')
                self._add_result(ValidationResult(
                    category='hooks',
                    check_name=f'pre_push_{cmd}',
                    passed=has_cmd,
                    severity='warning',
                    message=f'Pre-push hook: {cmd}',
                    details='Missing' if not has_cmd else 'Configured'
                ))

        # Check Claude Code settings.json
        claude_settings = self._file_exists('.claude/settings.json')
        self._add_result(ValidationResult(
            category='hooks',
            check_name='claude_settings_exists',
            passed=claude_settings,
            severity='warning',
            message='Claude Code settings.json',
            details='Not found' if not claude_settings else 'Found'
        ))

    # ========== Documentation Validation ==========

    def validate_documentation(self):
        """Validate documentation structure and CLAUDE.md."""
        if not self.config['documentation']['enabled']:
            return

        # Check CLAUDE.md exists
        claude_md_exists = self._file_exists('CLAUDE.md')
        self._add_result(ValidationResult(
            category='documentation',
            check_name='claude_md_exists',
            passed=claude_md_exists,
            severity='critical',
            message='CLAUDE.md file exists',
            details='Not found' if not claude_md_exists else 'Found'
        ))

        # Check CLAUDE.md required sections
        if claude_md_exists:
            claude_content = self._read_file('CLAUDE.md')
            for section in self.config['documentation']['required_claude_sections']:
                has_section = f'## {section}' in claude_content
                self._add_result(ValidationResult(
                    category='documentation',
                    check_name=f'claude_section_{section.lower().replace(" ", "_")}',
                    passed=has_section,
                    severity='warning',
                    message=f'CLAUDE.md section: {section}',
                    details='Missing' if not has_section else 'Present'
                ))

        # Check directory structure
        wip_dir = self.config['documentation']['wip_directory']
        guides_dir = self.config['documentation']['guides_directory']
        arch_dir = self.config['documentation']['architecture_directory']

        self._add_result(ValidationResult(
            category='documentation',
            check_name='wip_directory_exists',
            passed=self._file_exists(wip_dir),
            severity='info',
            message=f'WIP directory: {wip_dir}',
            details='Recommended but not required'
        ))

        # Check for forbidden root .md files
        root_md_files = [
            f for f in os.listdir(self.project_path)
            if f.endswith('.md') and f not in self.config['documentation']['allowed_root_files']
        ]
        has_forbidden = len(root_md_files) > 0
        self._add_result(ValidationResult(
            category='documentation',
            check_name='no_forbidden_root_md',
            passed=not has_forbidden,
            severity='critical',
            message='No forbidden root .md files',
            details=f'Found: {", ".join(root_md_files)}' if has_forbidden else 'Clean'
        ))

    # ========== Testing Validation ==========

    def validate_testing(self):
        """Validate testing configuration and coverage."""
        if not self.config['testing']['enabled']:
            return

        # Check Vitest configuration (check root and common monorepo locations)
        vitest_config = self.config['testing']['vitest']
        if vitest_config['required']:
            vitest_path = None
            # Check multiple locations
            for path in [vitest_config['config_file'], 'apps/web/vitest.config.ts', 'apps/web/vitest.config.js']:
                if self._file_exists(path):
                    vitest_path = path
                    break

            vitest_exists = vitest_path is not None
            self._add_result(ValidationResult(
                category='testing',
                check_name='vitest_config_exists',
                passed=vitest_exists,
                severity='critical',
                message='Vitest configuration file',
                details='Not found' if not vitest_exists else f'Found: {vitest_path}'
            ))

            # Check coverage threshold
            if vitest_exists:
                has_coverage = self._check_file_contains(
                    vitest_path,
                    f"thresholds"
                )
                self._add_result(ValidationResult(
                    category='testing',
                    check_name='vitest_coverage_configured',
                    passed=has_coverage,
                    severity='warning',
                    message='Vitest coverage thresholds configured',
                    details='Missing' if not has_coverage else 'Configured'
                ))

            # Check test scripts in package.json
            package_json = self._read_file('package.json')
            if package_json:
                for script in vitest_config['required_scripts']:
                    has_script = script in package_json
                    self._add_result(ValidationResult(
                        category='testing',
                        check_name=f'test_script_{script.replace(":", "_")}',
                        passed=has_script,
                        severity='warning',
                        message=f'Test script: {script}',
                        details='Missing' if not has_script else 'Present'
                    ))

        # Check Playwright (for web projects)
        playwright_config = self.config['testing']['playwright']
        if playwright_config.get('required_for_web'):
            # Only check if this seems to be a web project
            if self._file_exists('next.config.js') or self._file_exists('next.config.mjs'):
                playwright_exists = self._file_exists(playwright_config['config_file'])
                self._add_result(ValidationResult(
                    category='testing',
                    check_name='playwright_config_exists',
                    passed=playwright_exists,
                    severity='info',
                    message='Playwright E2E testing configured',
                    details='Recommended for web projects'
                ))

    # ========== Quality Gates Validation ==========

    def validate_quality_gates(self):
        """Validate linting, type checking, and formatting configuration."""
        if not self.config['quality_gates']['enabled']:
            return

        # Check ESLint (try multiple common locations and formats)
        eslint_config = self.config['quality_gates']['eslint']
        if eslint_config['required']:
            eslint_path = None
            # Check multiple locations and formats
            for path in [
                eslint_config['config_file'],
                '.eslintrc.json',
                '.eslintrc.js',
                'eslint.config.js',
                'apps/web/eslint.config.mjs',
                'apps/web/.eslintrc.json'
            ]:
                if self._file_exists(path):
                    eslint_path = path
                    break

            eslint_exists = eslint_path is not None
            self._add_result(ValidationResult(
                category='quality_gates',
                check_name='eslint_config_exists',
                passed=eslint_exists,
                severity='critical',
                message='ESLint configuration file',
                details='Not found' if not eslint_exists else f'Found: {eslint_path}'
            ))

        # Check TypeScript
        ts_config = self.config['quality_gates']['typescript']
        if ts_config['required']:
            ts_exists = self._file_exists(ts_config['config_file'])
            self._add_result(ValidationResult(
                category='quality_gates',
                check_name='typescript_config_exists',
                passed=ts_exists,
                severity='critical',
                message='TypeScript configuration file',
                details='Not found' if not ts_exists else 'Found'
            ))

            # Check strict mode
            if ts_exists:
                has_strict = self._check_file_contains(
                    ts_config['config_file'],
                    '"strict": true'
                )
                self._add_result(ValidationResult(
                    category='quality_gates',
                    check_name='typescript_strict_mode',
                    passed=has_strict,
                    severity='warning',
                    message='TypeScript strict mode enabled',
                    details='Not enabled' if not has_strict else 'Enabled'
                ))

        # Check Prettier
        prettier_config = self.config['quality_gates']['prettier']
        if prettier_config['required']:
            prettier_exists = self._file_exists(prettier_config['config_file'])
            self._add_result(ValidationResult(
                category='quality_gates',
                check_name='prettier_config_exists',
                passed=prettier_exists,
                severity='warning',
                message='Prettier configuration file',
                details='Not found' if not prettier_exists else 'Found'
            ))

        # Check quality script
        quality_script = self.config['quality_gates']['quality_script']
        if quality_script['required']:
            package_json = self._read_file('package.json')
            if package_json:
                has_quality = quality_script['name'] in package_json
                self._add_result(ValidationResult(
                    category='quality_gates',
                    check_name='quality_script_exists',
                    passed=has_quality,
                    severity='warning',
                    message='Quality script in package.json',
                    details='Missing' if not has_quality else 'Present'
                ))

    # ========== Git Validation ==========

    def validate_git(self):
        """Validate Git configuration and .gitignore."""
        if not self.config['git']['enabled']:
            return

        # Check .gitignore exists
        gitignore_exists = self._file_exists('.gitignore')
        self._add_result(ValidationResult(
            category='git',
            check_name='gitignore_exists',
            passed=gitignore_exists,
            severity='critical',
            message='.gitignore file exists',
            details='Not found' if not gitignore_exists else 'Found'
        ))

        # Check required .gitignore entries (check pattern without trailing slash too)
        if gitignore_exists:
            gitignore_content = self._read_file('.gitignore')
            for entry in self.config['git']['gitignore']['must_include']:
                # Check for entry with or without trailing slash
                entry_base = entry.rstrip('/')
                has_entry = entry in gitignore_content or entry_base in gitignore_content
                self._add_result(ValidationResult(
                    category='git',
                    check_name=f'gitignore_has_{entry.replace("/", "_").replace(".", "_")}',
                    passed=has_entry,
                    severity='info',  # Reduce to info since it's often present but with variations
                    message=f'.gitignore includes {entry}',
                    details='Missing' if not has_entry else 'Present'
                ))

    # ========== Security Validation ==========

    def validate_security(self):
        """Validate security configuration (env vars, RLS, etc.)."""
        if not self.config['security']['enabled']:
            return

        # Check .env.local.example exists
        env_example = self.config['security']['env_files']['example_file_name']
        env_example_exists = self._file_exists(env_example)
        self._add_result(ValidationResult(
            category='security',
            check_name='env_example_exists',
            passed=env_example_exists,
            severity='warning',
            message=f'{env_example} file exists',
            details='Not found (recommended)' if not env_example_exists else 'Found'
        ))

        # Basic secret scanning (check for common patterns)
        dangerous_patterns = [
            ('sk_live_', 'Stripe live key'),
            ('pk_live_', 'Stripe live publishable key'),
            ('AKIA', 'AWS access key'),
        ]

        # Scan common source files
        source_dirs = ['app', 'src', 'lib', 'pages', 'components']
        for dir_name in source_dirs:
            dir_path = self.project_path / dir_name
            if dir_path.exists() and dir_path.is_dir():
                for file_path in dir_path.rglob('*.{ts,tsx,js,jsx}'):
                    content = file_path.read_text(errors='ignore')
                    for pattern, name in dangerous_patterns:
                        if pattern in content:
                            self._add_result(ValidationResult(
                                category='security',
                                check_name='no_hardcoded_secrets',
                                passed=False,
                                severity='critical',
                                message=f'Potential {name} hardcoded',
                                details=f'Found in {file_path.relative_to(self.project_path)}'
                            ))
                            break

    # ========== Naming Conventions Validation ==========

    def validate_naming_conventions(self):
        """Validate file and function naming conventions."""
        if not self.config['naming_conventions']['enabled']:
            return

        # Check for forbidden suffixes in files
        forbidden_suffixes = self.config['naming_conventions']['files']['forbidden_suffixes']
        files_with_suffixes = []

        # Scan common source directories
        source_dirs = ['app', 'src', 'lib', 'pages', 'components', 'packages']
        for dir_name in source_dirs:
            dir_path = self.project_path / dir_name
            if dir_path.exists() and dir_path.is_dir():
                for file_path in dir_path.rglob('*'):
                    if file_path.is_file():
                        file_name = file_path.stem  # filename without extension
                        for suffix in forbidden_suffixes:
                            if file_name.endswith(suffix):
                                files_with_suffixes.append(
                                    str(file_path.relative_to(self.project_path))
                                )
                                break

        has_forbidden_suffixes = len(files_with_suffixes) > 0
        self._add_result(ValidationResult(
            category='naming_conventions',
            check_name='no_version_suffixes',
            passed=not has_forbidden_suffixes,
            severity='critical',
            message='No version/enhancement suffixes in filenames',
            details=f'Found {len(files_with_suffixes)} files: {", ".join(files_with_suffixes[:3])}{"..." if len(files_with_suffixes) > 3 else ""}' if has_forbidden_suffixes else 'Clean'
        ))

    # ========== Migrations Validation ==========

    def validate_migrations(self):
        """Validate database migration idempotency (Supabase projects)."""
        if not self.config['migrations'].get('enabled_for_supabase'):
            return

        # Check if migrations directory exists
        migrations_dir = 'supabase/migrations'  # Default
        if not self._file_exists(migrations_dir):
            migrations_dir = 'apps/web/supabase/migrations'  # Monorepo

        if not self._file_exists(migrations_dir):
            return  # No migrations directory, skip validation

        # Scan migration files for idempotency issues
        migrations_path = self.project_path / migrations_dir
        non_idempotent_files = []

        for migration_file in migrations_path.glob('*.sql'):
            content = migration_file.read_text()

            # Check for non-idempotent patterns
            issues = []

            # CREATE POLICY without DO $$ block
            if 'CREATE POLICY' in content and 'DO $$' not in content:
                issues.append('CREATE POLICY without DO $$ block')

            # CREATE TRIGGER without DROP IF EXISTS
            if 'CREATE TRIGGER' in content and 'DROP TRIGGER IF EXISTS' not in content:
                issues.append('CREATE TRIGGER without DROP IF EXISTS')

            # ADD CONSTRAINT without DO $$ block
            if 'ADD CONSTRAINT' in content and 'DO $$' not in content:
                issues.append('ADD CONSTRAINT without idempotency check')

            if issues:
                non_idempotent_files.append(
                    f"{migration_file.name}: {', '.join(issues)}"
                )

        has_issues = len(non_idempotent_files) > 0
        self._add_result(ValidationResult(
            category='migrations',
            check_name='migrations_idempotent',
            passed=not has_issues,
            severity='critical',
            message='All migrations are idempotent',
            details=f'Issues in {len(non_idempotent_files)} files: {"; ".join(non_idempotent_files[:2])}{"..." if len(non_idempotent_files) > 2 else ""}' if has_issues else 'All idempotent'
        ))

    # ========== Main Validation ==========

    def validate_all(self) -> Tuple[float, str]:
        """Run all validation checks and return (score, grade)."""
        print(f"🔍 Validating: {self.project_path}\n")

        self.validate_hooks()
        self.validate_documentation()
        self.validate_testing()
        self.validate_quality_gates()
        self.validate_git()
        self.validate_security()
        self.validate_naming_conventions()
        self.validate_migrations()

        # Calculate scores
        total_score = 0.0
        total_weight = 0

        for category, result in self.results.items():
            total_checks = result.checks_passed + result.checks_failed + result.checks_warned
            if total_checks > 0:
                # Calculate category score
                passed_score = result.checks_passed
                warned_score = result.checks_warned * 0.5  # Warnings count as 50%
                result.score = ((passed_score + warned_score) / total_checks) * 100

                weighted_score = result.score * result.weight
                total_score += weighted_score
                total_weight += result.weight

        overall_score = total_score / total_weight if total_weight > 0 else 0

        # Determine grade
        grade = 'F'
        for grade_name, grade_config in self.config['compliance_grading'].items():
            if overall_score >= grade_config['min_percent']:
                grade = grade_name
                break

        return overall_score, grade

    def print_results(self, score: float, grade: str):
        """Print validation results to console."""
        print("\n" + "="*70)
        print(f"  COMPLIANCE REPORT")
        print("="*70 + "\n")

        # Print category results
        for category, result in sorted(self.results.items()):
            total = result.checks_passed + result.checks_failed + result.checks_warned

            # Category header
            status_icon = "✓" if result.checks_failed == 0 else "✗" if result.checks_failed > 0 else "⚠"
            print(f"{status_icon} {result.name.upper()}: {result.score:.1f}% ({result.checks_passed}/{total} passed)")

            # Show failed checks
            for check in result.results:
                if not check.passed and check.severity in ['critical', 'warning']:
                    icon = "  ✗" if check.severity == 'critical' else "  ⚠"
                    print(f"{icon} {check.message}")
                    if check.details:
                        print(f"     {check.details}")

            print()

        # Overall score
        print("="*70)
        print(f"Overall Compliance: {score:.1f}% (Grade: {grade})")
        print(f"Description: {self.config['compliance_grading'][grade]['description']}")
        print("="*70 + "\n")

        # Recommendations
        critical_failures = [
            r for cat in self.results.values()
            for r in cat.results
            if not r.passed and r.severity == 'critical'
        ]

        if critical_failures:
            print("⚠️  CRITICAL ISSUES TO FIX:\n")
            for i, result in enumerate(critical_failures[:5], 1):
                print(f"{i}. {result.message}")
                if result.details:
                    print(f"   {result.details}")
            if len(critical_failures) > 5:
                print(f"\n... and {len(critical_failures) - 5} more critical issues")
            print()

    def export_json(self, score: float, grade: str) -> dict:
        """Export results as JSON."""
        return {
            'overall_score': score,
            'grade': grade,
            'categories': {
                cat_name: {
                    'score': cat.score,
                    'weight': cat.weight,
                    'checks_passed': cat.checks_passed,
                    'checks_failed': cat.checks_failed,
                    'checks_warned': cat.checks_warned,
                    'results': [
                        {
                            'check': r.check_name,
                            'passed': r.passed,
                            'severity': r.severity,
                            'message': r.message,
                            'details': r.details
                        }
                        for r in cat.results
                    ]
                }
                for cat_name, cat in self.results.items()
            }
        }


def main():
    parser = argparse.ArgumentParser(
        description='Validate project compliance with engineering standards'
    )
    parser.add_argument(
        '--project-path',
        type=Path,
        default=Path.cwd(),
        help='Path to project to validate (default: current directory)'
    )
    parser.add_argument(
        '--report-format',
        choices=['text', 'json'],
        default='text',
        help='Output format (default: text)'
    )
    parser.add_argument(
        '--output',
        type=Path,
        help='Output file path (default: stdout)'
    )

    args = parser.parse_args()

    # Find engineering-standards skill path
    script_dir = Path(__file__).parent.parent

    # Validate project
    validator = ComplianceValidator(args.project_path, script_dir)
    score, grade = validator.validate_all()

    # Output results
    if args.report_format == 'json':
        result = validator.export_json(score, grade)
        output = json.dumps(result, indent=2)

        if args.output:
            args.output.write_text(output)
        else:
            print(output)
    else:
        validator.print_results(score, grade)

    # Exit code based on grade
    if score >= 95:
        sys.exit(0)  # Full compliance
    elif score >= 70:
        sys.exit(1)  # Warnings
    else:
        sys.exit(2)  # Critical failures


if __name__ == '__main__':
    main()
