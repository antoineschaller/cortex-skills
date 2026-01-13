#!/usr/bin/env python3
"""
Generate comprehensive compliance reports.

This script generates detailed compliance reports in multiple formats
(markdown, JSON, HTML) with historical comparison and metrics.

Usage:
    python generate-report.py [--project-path PATH] [--format FORMAT] [--output FILE]
    python generate-report.py --help

Exit codes:
    0 - Success
    1 - Error generating report
"""

import argparse
import json
from datetime import datetime
from pathlib import Path
from typing import Dict, List, Optional
import sys

# Import validation from validate-compliance.py (using importlib for hyphenated filename)
import importlib.util
script_dir = Path(__file__).parent
validate_spec = importlib.util.spec_from_file_location("validate_compliance", script_dir / "validate-compliance.py")
validate_module = importlib.util.module_from_spec(validate_spec)
validate_spec.loader.exec_module(validate_module)
ComplianceValidator = validate_module.ComplianceValidator


class ReportGenerator:
    """Generates comprehensive compliance reports."""

    def __init__(self, validator: ComplianceValidator, score: float, grade: str):
        self.validator = validator
        self.score = score
        self.grade = grade
        self.timestamp = datetime.now()

    def generate_markdown(self) -> str:
        """Generate markdown report."""
        md = []

        # Header
        md.append(f"# Engineering Standards Compliance Report")
        md.append(f"\n**Project**: {self.validator.project_path.name}")
        md.append(f"**Generated**: {self.timestamp.strftime('%Y-%m-%d %H:%M:%S')}")
        md.append(f"**Overall Score**: {self.score:.1f}% (Grade: {self.grade})")
        md.append(f"\n---\n")

        # Executive Summary
        md.append("## Executive Summary\n")

        grade_desc = self.validator.config['compliance_grading'][self.grade]['description']
        md.append(f"**Status**: {grade_desc}\n")

        total_checks = sum(
            cat.checks_passed + cat.checks_failed + cat.checks_warned
            for cat in self.validator.results.values()
        )
        total_passed = sum(cat.checks_passed for cat in self.validator.results.values())
        total_failed = sum(cat.checks_failed for cat in self.validator.results.values())
        total_warned = sum(cat.checks_warned for cat in self.validator.results.values())

        md.append(f"- **Total Checks**: {total_checks}")
        md.append(f"- **Passed**: {total_passed} (✓)")
        md.append(f"- **Failed**: {total_failed} (✗)")
        md.append(f"- **Warnings**: {total_warned} (⚠)")
        md.append("")

        # Standards Compliance Matrix
        md.append("## Standards Compliance Matrix\n")
        md.append("| Category | Score | Weight | Status | Checks |")
        md.append("|----------|-------|--------|--------|--------|")

        for cat_name, cat in sorted(self.validator.results.items(), key=lambda x: -x[1].score):
            total = cat.checks_passed + cat.checks_failed + cat.checks_warned
            status = "✓ Pass" if cat.checks_failed == 0 else "✗ Fail" if cat.checks_failed > 0 else "⚠ Warning"
            md.append(
                f"| {cat.name.title()} | {cat.score:.1f}% | {cat.weight}% | {status} | {cat.checks_passed}/{total} |"
            )

        md.append("")

        # Detailed Findings
        md.append("## Detailed Findings\n")

        for cat_name, cat in sorted(self.validator.results.items()):
            md.append(f"### {cat.name.title()} ({cat.score:.1f}%)\n")

            # Passed checks
            passed_checks = [r for r in cat.results if r.passed]
            if passed_checks:
                md.append("**Passed Checks**:")
                for check in passed_checks:
                    md.append(f"- ✓ {check.message}")
                md.append("")

            # Failed checks
            failed_checks = [r for r in cat.results if not r.passed and r.severity == 'critical']
            if failed_checks:
                md.append("**Failed Checks**:")
                for check in failed_checks:
                    md.append(f"- ✗ {check.message}")
                    if check.details:
                        md.append(f"  - {check.details}")
                md.append("")

            # Warning checks
            warning_checks = [r for r in cat.results if not r.passed and r.severity == 'warning']
            if warning_checks:
                md.append("**Warnings**:")
                for check in warning_checks:
                    md.append(f"- ⚠ {check.message}")
                    if check.details:
                        md.append(f"  - {check.details}")
                md.append("")

        # Recommendations
        md.append("## Recommendations\n")

        critical_failures = [
            (cat_name, r)
            for cat_name, cat in self.validator.results.items()
            for r in cat.results
            if not r.passed and r.severity == 'critical'
        ]

        if critical_failures:
            md.append("### Priority 1: Critical Issues\n")
            for i, (cat_name, result) in enumerate(critical_failures, 1):
                md.append(f"{i}. **{result.message}** ({cat_name})")
                if result.details:
                    md.append(f"   - {result.details}")
            md.append("")

        warnings = [
            (cat_name, r)
            for cat_name, cat in self.validator.results.items()
            for r in cat.results
            if not r.passed and r.severity == 'warning'
        ]

        if warnings:
            md.append("### Priority 2: Warnings\n")
            for i, (cat_name, result) in enumerate(warnings[:10], 1):
                md.append(f"{i}. **{result.message}** ({cat_name})")
                if result.details:
                    md.append(f"   - {result.details}")
            if len(warnings) > 10:
                md.append(f"\n... and {len(warnings) - 10} more warnings")
            md.append("")

        # Metrics
        md.append("## Quality Metrics\n")
        md.append(f"- **Documentation Coverage**: {self._get_category_score('documentation'):.1f}%")
        md.append(f"- **Testing Coverage**: {self._get_category_score('testing'):.1f}%")
        md.append(f"- **Security Score**: {self._get_category_score('security'):.1f}%")
        md.append(f"- **Code Quality**: {self._get_category_score('quality_gates'):.1f}%")
        md.append("")

        # Next Steps
        md.append("## Next Steps\n")

        if self.score < 70:
            md.append("1. **Address all critical failures** listed above")
            md.append("2. Re-run validation after fixes")
            md.append("3. Review warnings and plan improvements")
        elif self.score < 95:
            md.append("1. **Address remaining warnings** for full compliance")
            md.append("2. Review optional recommendations")
            md.append("3. Consider adding missing configurations")
        else:
            md.append("1. **Maintain current standards** through CI/CD")
            md.append("2. Review any remaining warnings")
            md.append("3. Consider contributing patterns to engineering-standards")

        md.append("")

        # Footer
        md.append("---")
        md.append(f"\n*Generated by engineering-standards validation tool*")

        return "\n".join(md)

    def generate_html(self) -> str:
        """Generate HTML report."""
        html = []

        html.append("<!DOCTYPE html>")
        html.append("<html>")
        html.append("<head>")
        html.append("  <meta charset='UTF-8'>")
        html.append("  <title>Engineering Standards Compliance Report</title>")
        html.append("  <style>")
        html.append("    body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif; margin: 40px; background: #f5f5f5; }")
        html.append("    .container { max-width: 1200px; margin: 0 auto; background: white; padding: 40px; border-radius: 8px; box-shadow: 0 2px 4px rgba(0,0,0,0.1); }")
        html.append("    h1 { color: #333; border-bottom: 3px solid #007AFF; padding-bottom: 10px; }")
        html.append("    h2 { color: #555; margin-top: 30px; }")
        html.append("    .score { font-size: 48px; font-weight: bold; text-align: center; margin: 20px 0; }")
        html.append("    .score.A { color: #34C759; }")
        html.append("    .score.B { color: #00C7BE; }")
        html.append("    .score.C { color: #FF9500; }")
        html.append("    .score.D { color: #FF3B30; }")
        html.append("    .score.F { color: #8E8E93; }")
        html.append("    .metric { display: inline-block; margin: 10px 20px; }")
        html.append("    .metric-value { font-size: 24px; font-weight: bold; color: #007AFF; }")
        html.append("    table { width: 100%; border-collapse: collapse; margin: 20px 0; }")
        html.append("    th, td { padding: 12px; text-align: left; border-bottom: 1px solid #ddd; }")
        html.append("    th { background: #007AFF; color: white; }")
        html.append("    tr:hover { background: #f5f5f5; }")
        html.append("    .pass { color: #34C759; }")
        html.append("    .fail { color: #FF3B30; }")
        html.append("    .warn { color: #FF9500; }")
        html.append("    .critical { background: #fff5f5; border-left: 4px solid #FF3B30; padding: 15px; margin: 10px 0; }")
        html.append("    .warning { background: #fffbf0; border-left: 4px solid #FF9500; padding: 15px; margin: 10px 0; }")
        html.append("  </style>")
        html.append("</head>")
        html.append("<body>")
        html.append("  <div class='container'>")

        # Header
        html.append(f"    <h1>Engineering Standards Compliance Report</h1>")
        html.append(f"    <p><strong>Project</strong>: {self.validator.project_path.name}</p>")
        html.append(f"    <p><strong>Generated</strong>: {self.timestamp.strftime('%Y-%m-%d %H:%M:%S')}</p>")

        # Score
        html.append(f"    <div class='score {self.grade}'>{self.score:.1f}% (Grade: {self.grade})</div>")
        html.append(f"    <p style='text-align: center;'>{self.validator.config['compliance_grading'][self.grade]['description']}</p>")

        # Metrics
        html.append("    <div style='text-align: center; margin: 30px 0;'>")
        total_checks = sum(cat.checks_passed + cat.checks_failed + cat.checks_warned for cat in self.validator.results.values())
        total_passed = sum(cat.checks_passed for cat in self.validator.results.values())
        html.append(f"      <div class='metric'><div class='metric-value'>{total_checks}</div><div>Total Checks</div></div>")
        html.append(f"      <div class='metric'><div class='metric-value'>{total_passed}</div><div>Passed</div></div>")
        html.append("    </div>")

        # Category Table
        html.append("    <h2>Category Scores</h2>")
        html.append("    <table>")
        html.append("      <tr><th>Category</th><th>Score</th><th>Weight</th><th>Status</th></tr>")

        for cat_name, cat in sorted(self.validator.results.items(), key=lambda x: -x[1].score):
            status_class = "pass" if cat.checks_failed == 0 else "fail"
            status_text = "✓ Pass" if cat.checks_failed == 0 else "✗ Fail"
            html.append(f"      <tr>")
            html.append(f"        <td>{cat.name.title()}</td>")
            html.append(f"        <td>{cat.score:.1f}%</td>")
            html.append(f"        <td>{cat.weight}%</td>")
            html.append(f"        <td class='{status_class}'>{status_text}</td>")
            html.append(f"      </tr>")

        html.append("    </table>")

        # Critical Issues
        critical_failures = [
            r for cat in self.validator.results.values()
            for r in cat.results
            if not r.passed and r.severity == 'critical'
        ]

        if critical_failures:
            html.append("    <h2>Critical Issues</h2>")
            for result in critical_failures:
                html.append(f"    <div class='critical'>")
                html.append(f"      <strong>{result.message}</strong>")
                if result.details:
                    html.append(f"      <p>{result.details}</p>")
                html.append(f"    </div>")

        html.append("  </div>")
        html.append("</body>")
        html.append("</html>")

        return "\n".join(html)

    def generate_json(self) -> dict:
        """Generate JSON report."""
        return self.validator.export_json(self.score, self.grade)

    def _get_category_score(self, category: str) -> float:
        """Get score for specific category."""
        if category in self.validator.results:
            return self.validator.results[category].score
        return 0.0


def main():
    parser = argparse.ArgumentParser(
        description='Generate comprehensive compliance report'
    )
    parser.add_argument(
        '--project-path',
        type=Path,
        default=Path.cwd(),
        help='Path to project to validate (default: current directory)'
    )
    parser.add_argument(
        '--format',
        choices=['markdown', 'html', 'json'],
        default='markdown',
        help='Report format (default: markdown)'
    )
    parser.add_argument(
        '--output',
        type=Path,
        help='Output file path (default: stdout for markdown/json, compliance-report.html for HTML)'
    )

    args = parser.parse_args()

    # Find engineering-standards skill path
    script_dir = Path(__file__).parent.parent

    # Run validation
    validator = ComplianceValidator(args.project_path, script_dir)
    score, grade = validator.validate_all()

    # Generate report
    generator = ReportGenerator(validator, score, grade)

    if args.format == 'markdown':
        report = generator.generate_markdown()
    elif args.format == 'html':
        report = generator.generate_html()
    else:  # json
        report = json.dumps(generator.generate_json(), indent=2)

    # Output
    if args.output:
        args.output.write_text(report)
        print(f"✓ Report generated: {args.output}")
    else:
        if args.format == 'html' and not args.output:
            # Default HTML output file
            output_path = Path('compliance-report.html')
            output_path.write_text(report)
            print(f"✓ Report generated: {output_path}")
        else:
            print(report)

    sys.exit(0)


if __name__ == '__main__':
    main()
