#!/usr/bin/env python3
"""
Token Counter Script

Estimates token usage for Claude Code skill files.

Usage:
    python token-counter.py path/to/SKILL.md
    python token-counter.py path/to/skill/  # Counts all .md files

Estimation method:
    - 1 token ≈ 4 characters (English text)
    - 1 token ≈ 3-4 characters (code)
    - Provides conservative estimate
"""

import sys
import os
from pathlib import Path
from typing import List, Dict

class TokenCounter:
    def __init__(self):
        # Conservative estimate: 1 token ≈ 4 characters
        self.CHARS_PER_TOKEN = 4

    def count_file(self, file_path: Path) -> Dict:
        """Count tokens for a single file"""
        try:
            content = file_path.read_text(encoding='utf-8')
        except Exception as e:
            return {
                "file": str(file_path),
                "error": str(e),
                "tokens": 0
            }

        char_count = len(content)
        line_count = content.count('\n') + 1
        word_count = len(content.split())
        estimated_tokens = char_count // self.CHARS_PER_TOKEN

        return {
            "file": file_path.name,
            "lines": line_count,
            "characters": char_count,
            "words": word_count,
            "estimated_tokens": estimated_tokens,
            "status": self.get_status(estimated_tokens)
        }

    def get_status(self, tokens: int) -> str:
        """Get status based on token count"""
        if tokens < 5000:
            return "✅ Under 5k token target"
        elif tokens < 7000:
            return "⚠️  Close to 5k token target (consider optimization)"
        else:
            return "❌ Exceeds 5k token target (use progressive disclosure)"

    def count_directory(self, dir_path: Path) -> List[Dict]:
        """Count tokens for all .md files in directory"""
        md_files = list(dir_path.glob("*.md"))

        if not md_files:
            return []

        results = []
        for md_file in sorted(md_files):
            result = self.count_file(md_file)
            results.append(result)

        return results

    def print_report(self, results: List[Dict] | Dict):
        """Print formatted report"""
        if isinstance(results, dict):
            results = [results]

        print("\n" + "="*70)
        print("TOKEN USAGE REPORT")
        print("="*70 + "\n")

        total_tokens = 0
        for result in results:
            if "error" in result:
                print(f"❌ Error reading {result['file']}: {result['error']}\n")
                continue

            print(f"File: {result['file']}")
            print(f"  Lines:      {result['lines']:,}")
            print(f"  Characters: {result['characters']:,}")
            print(f"  Words:      {result['words']:,}")
            print(f"  Tokens:     ~{result['estimated_tokens']:,}")
            print(f"  Status:     {result['status']}")
            print()

            total_tokens += result['estimated_tokens']

        if len(results) > 1:
            print("-"*70)
            print(f"Total estimated tokens: ~{total_tokens:,}")
            print()

            # Progressive disclosure recommendation
            if total_tokens > 5000:
                print("💡 RECOMMENDATION:")
                print("   Total tokens exceed 5k. Consider progressive disclosure:")
                print("   - Keep SKILL.md under 5k tokens (core content only)")
                print("   - Move detailed content to REFERENCE.md, EXAMPLES.md, etc.")
                print("   - Load supporting files only when needed")
                print()

    def get_recommendations(self, tokens: int) -> List[str]:
        """Get optimization recommendations based on token count"""
        recommendations = []

        if tokens > 7000:
            recommendations.append("Split into multiple files with progressive disclosure")
            recommendations.append("Move detailed API docs to REFERENCE.md")
            recommendations.append("Move comprehensive examples to EXAMPLES.md")
            recommendations.append("Keep only quick reference and core patterns in SKILL.md")
        elif tokens > 5000:
            recommendations.append("Consider using tables instead of prose for comparisons")
            recommendations.append("Extract complex examples to EXAMPLES.md")
            recommendations.append("Reference external templates instead of inline code")

        return recommendations


def main():
    if len(sys.argv) < 2:
        print("Usage: python token-counter.py path/to/SKILL.md")
        print("       python token-counter.py path/to/skill/")
        print("\nExamples:")
        print("  python token-counter.py .claude/skills/api-patterns/SKILL.md")
        print("  python token-counter.py .claude/skills/api-patterns/")
        sys.exit(1)

    path = Path(sys.argv[1])

    if not path.exists():
        print(f"❌ Error: Path not found: {path}")
        sys.exit(1)

    counter = TokenCounter()

    if path.is_file():
        # Count single file
        result = counter.count_file(path)
        counter.print_report(result)

        # Print recommendations if over target
        if result["estimated_tokens"] > 5000:
            recommendations = counter.get_recommendations(result["estimated_tokens"])
            if recommendations:
                print("💡 OPTIMIZATION RECOMMENDATIONS:")
                for rec in recommendations:
                    print(f"   • {rec}")
                print()

    elif path.is_dir():
        # Count all .md files in directory
        results = counter.count_directory(path)

        if not results:
            print(f"No .md files found in {path}")
            sys.exit(0)

        counter.print_report(results)
    else:
        print(f"❌ Error: Invalid path: {path}")
        sys.exit(1)


if __name__ == "__main__":
    main()
