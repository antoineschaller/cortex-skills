#!/usr/bin/env python3
"""
Bootstrap new project with engineering standards.

This script sets up a new project with all engineering standards:
- Directory structure
- Template files with variable substitution
- Git initialization
- Lefthook installation
- Initial documentation

Usage:
    python bootstrap-project.py --project-name "My Project" --project-type nextjs --output-path ./new-project
    python bootstrap-project.py --help

Exit codes:
    0 - Success
    1 - Error during bootstrap
"""

import argparse
import json
import os
import re
import shutil
import subprocess
import sys
from pathlib import Path
from typing import Dict, Optional


class ProjectBootstrapper:
    """Bootstrap new projects with engineering standards."""

    def __init__(
        self,
        project_name: str,
        project_type: str,
        output_path: Path,
        standards_path: Path,
        framework: Optional[str] = None,
        package_manager: str = 'pnpm'
    ):
        self.project_name = project_name
        self.project_type = project_type
        self.output_path = output_path
        self.standards_path = standards_path
        self.framework = framework
        self.package_manager = package_manager

        # Load configurations
        self.variables = self._load_variables()
        self.framework_extensions = self._load_framework_extensions()

    def _load_variables(self) -> dict:
        """Load project variables configuration."""
        with open(self.standards_path / 'config' / 'project-variables.json') as f:
            return json.load(f)

    def _load_framework_extensions(self) -> dict:
        """Load framework extensions configuration."""
        with open(self.standards_path / 'config' / 'framework-extensions.json') as f:
            return json.load(f)

    def _slugify(self, text: str) -> str:
        """Convert text to URL-safe slug."""
        text = text.lower()
        text = re.sub(r'[^\w\s-]', '', text)
        text = re.sub(r'[-\s]+', '-', text)
        return text.strip('-')

    def _substitute_variables(self, content: str) -> str:
        """Substitute template variables in content."""
        # Build substitution map
        subs = {
            'project_name': self.project_name,
            'project_slug': self._slugify(self.project_name),
            'project_type': self.project_type,
            'framework': self.framework or 'none',
            'package_manager': self.package_manager,
            'tech_stack': self._get_tech_stack(),
            'wip_directory': 'docs/wip/active',
            'docs_directory': 'docs',
            'apps_directory': 'apps' if self.project_type == 'monorepo' else 'src',
            'packages_directory': 'packages',
            'migrations_directory': 'supabase/migrations',
            'database_types_file': 'lib/database.types.ts',
            'source_directories': 'src apps packages',
            'default_branch': 'main',
            'typegen_command': 'supabase gen types typescript --local',
            'coverage_threshold': '80',
            'use_supabase': str(self.framework in ['makerkit', 'supabase']).lower(),
            'github_org': 'your-org',
            'github_repo': self._slugify(self.project_name),
            'env_file': '.env.local',
        }

        # Add command substitutions
        subs.update({
            'commands.install': f'{self.package_manager} install',
            'commands.dev': f'{self.package_manager} dev',
            'commands.build': f'{self.package_manager} build',
            'commands.test': f'{self.package_manager} test',
            'commands.quality': f'{self.package_manager} quality',
            'commands.db_reset': f'{self.package_manager} supabase:reset',
            'commands.typegen': f'{self.package_manager} supabase:typegen',
        })

        # Simple template substitution
        result = content
        for key, value in subs.items():
            result = result.replace('{{' + key + '}}', str(value))

        return result

    def _get_tech_stack(self) -> str:
        """Get tech stack description based on project type."""
        stacks = {
            'nextjs': 'Next.js | React | TypeScript | Tailwind CSS',
            'flutter': 'Flutter | Dart | Riverpod',
            'monorepo': 'Monorepo | Turborepo | pnpm workspaces',
            'backend': 'Node.js | TypeScript | Express',
        }
        return stacks.get(self.project_type, 'TypeScript')

    def create_directory_structure(self):
        """Create project directory structure."""
        print("📁 Creating directory structure...")

        # Create base directories
        dirs = [
            'docs/wip/active',
            'docs/guides',
            'docs/architecture',
            'docs/investigations',
            '.claude/skills',
            '.claude/agents',
            '.claude/context',
        ]

        # Add type-specific directories
        if self.project_type == 'monorepo':
            dirs.extend(['apps', 'packages', 'tools'])
        elif self.project_type == 'nextjs':
            dirs.extend(['app', 'lib', 'components', 'public'])
        elif self.project_type == 'flutter':
            dirs.extend(['lib/core', 'lib/modules', 'test'])
        else:
            dirs.extend(['src', 'tests'])

        # Add Supabase directories if applicable
        if self.framework in ['makerkit', 'supabase'] or self.project_type == 'nextjs':
            dirs.append('supabase/migrations')

        for dir_path in dirs:
            (self.output_path / dir_path).mkdir(parents=True, exist_ok=True)
            print(f"  ✓ {dir_path}/")

        print()

    def copy_templates(self):
        """Copy and process template files."""
        print("📄 Copying template files...")

        templates_dir = self.standards_path / 'templates'
        templates = [
            ('lefthook.yml.template', 'lefthook.yml'),
            ('CLAUDE.md.template', 'CLAUDE.md'),
            ('.gitignore', '.gitignore'),
            ('.env.local.example', '.env.local.example'),
        ]

        # Add type-specific templates
        if self.project_type in ['nextjs', 'monorepo']:
            templates.extend([
                ('vitest.config.ts.template', 'vitest.config.ts'),
                ('eslint.config.mjs.template', 'eslint.config.mjs'),
            ])

        templates.append(('settings.json.template', '.claude/settings.json'))

        for template_name, output_name in templates:
            template_path = templates_dir / template_name
            if not template_path.exists():
                print(f"  ⚠ Template not found: {template_name}")
                continue

            # Read template
            content = template_path.read_text()

            # Substitute variables
            processed = self._substitute_variables(content)

            # Write to output
            output_file = self.output_path / output_name
            output_file.parent.mkdir(parents=True, exist_ok=True)
            output_file.write_text(processed)

            print(f"  ✓ {output_name}")

        print()

    def create_package_json(self):
        """Create package.json with quality scripts."""
        print("📦 Creating package.json...")

        package_json = {
            "name": self._slugify(self.project_name),
            "version": "1.0.0",
            "description": f"{self.project_name} - A modern application",
            "private": True,
            "scripts": {
                "dev": "next dev" if self.project_type == 'nextjs' else "echo 'Add dev command'",
                "build": "next build" if self.project_type == 'nextjs' else "echo 'Add build command'",
                "start": "next start" if self.project_type == 'nextjs' else "echo 'Add start command'",
                "format": "prettier --write \"**/*.{js,jsx,ts,tsx,json,md}\"",
                "format:check": "prettier --check \"**/*.{js,jsx,ts,tsx,json,md}\"",
                "lint": "eslint .",
                "lint:fix": "eslint --fix .",
                "typecheck": "tsc --noEmit",
                "test": "vitest" if self.project_type in ['nextjs', 'monorepo'] else "echo 'Add test command'",
                "test:coverage": "vitest --coverage" if self.project_type in ['nextjs', 'monorepo'] else "echo 'Add test coverage'",
                "quality": "pnpm format:check && pnpm lint && pnpm typecheck && pnpm test && pnpm build",
                "prepare": "lefthook install"
            },
            "devDependencies": {
                "typescript": "^5.7.2",
                "prettier": "^3.4.2",
                "@types/node": "^20.0.0"
            }
        }

        # Add type-specific dependencies
        if self.project_type == 'nextjs':
            package_json["dependencies"] = {
                "next": "^16.1.0",
                "react": "^19.0.0",
                "react-dom": "^19.0.0"
            }
            package_json["devDependencies"].update({
                "eslint": "^9.0.0",
                "@typescript-eslint/eslint-plugin": "^8.0.0",
                "@typescript-eslint/parser": "^8.0.0",
                "vitest": "^2.0.0",
                "@vitest/coverage-v8": "^2.0.0",
                "lefthook": "^1.9.8"
            })
        elif self.project_type == 'monorepo':
            package_json["devDependencies"].update({
                "turbo": "^2.3.0",
                "lefthook": "^1.9.8"
            })
            package_json["packageManager"] = f"{self.package_manager}@9.15.1"

        # Write package.json
        output_file = self.output_path / 'package.json'
        output_file.write_text(json.dumps(package_json, indent=2) + '\n')

        print(f"  ✓ package.json")
        print()

    def create_tsconfig(self):
        """Create tsconfig.json with strict mode."""
        print("⚙️  Creating TypeScript configuration...")

        tsconfig = {
            "compilerOptions": {
                "target": "ES2022",
                "lib": ["ES2022", "DOM", "DOM.Iterable"],
                "module": "ESNext",
                "moduleResolution": "bundler",
                "resolveJsonModule": True,
                "allowJs": True,
                "checkJs": False,
                "strict": True,
                "noUncheckedIndexedAccess": True,
                "noImplicitReturns": True,
                "noFallthroughCasesInSwitch": True,
                "forceConsistentCasingInFileNames": True,
                "esModuleInterop": True,
                "skipLibCheck": True,
                "allowSyntheticDefaultImports": True,
                "jsx": "preserve" if self.project_type == 'nextjs' else "react",
                "incremental": True,
                "isolatedModules": True,
                "paths": {
                    "@/*": ["./*"]
                }
            },
            "include": ["**/*.ts", "**/*.tsx", "**/*.js", "**/*.jsx"],
            "exclude": ["node_modules", "dist", ".next", "build"]
        }

        # Add Next.js specific options
        if self.project_type == 'nextjs':
            tsconfig["compilerOptions"].update({
                "plugins": [{"name": "next"}]
            })

        output_file = self.output_path / 'tsconfig.json'
        output_file.write_text(json.dumps(tsconfig, indent=2) + '\n')

        print(f"  ✓ tsconfig.json")
        print()

    def create_readme(self):
        """Create README.md."""
        print("📖 Creating README.md...")

        readme = f"""# {self.project_name}

{self.project_name} - A modern application built with engineering standards.

## Tech Stack

{self._get_tech_stack()}

## Getting Started

### Prerequisites

- Node.js 20+
- {self.package_manager} (install with `npm install -g {self.package_manager}`)

### Installation

```bash
# Install dependencies
{self.package_manager} install

# Start development server
{self.package_manager} dev
```

### Development

```bash
# Run quality checks
{self.package_manager} quality

# Format code
{self.package_manager} format

# Run tests
{self.package_manager} test

# Build for production
{self.package_manager} build
```

## Project Structure

See [CLAUDE.md](CLAUDE.md) for detailed project documentation.

## Engineering Standards

This project follows comprehensive engineering standards:

- ✓ Git hooks (pre-commit, pre-push)
- ✓ Quality gates (lint, typecheck, format, test, build)
- ✓ Documentation standards (CLAUDE.md, WIP files)
- ✓ Testing standards (80% coverage target)
- ✓ Security standards (RLS-first, env vars)

## License

MIT
"""

        output_file = self.output_path / 'README.md'
        output_file.write_text(readme)

        print(f"  ✓ README.md")
        print()

    def initialize_git(self):
        """Initialize Git repository."""
        print("🔧 Initializing Git repository...")

        try:
            # Initialize git
            subprocess.run(
                ['git', 'init'],
                cwd=self.output_path,
                check=True,
                capture_output=True
            )
            print("  ✓ Git initialized")

            # Create initial commit
            subprocess.run(
                ['git', 'add', '.'],
                cwd=self.output_path,
                check=True,
                capture_output=True
            )
            subprocess.run(
                ['git', 'commit', '-m', 'chore: bootstrap project with engineering standards\n\nCo-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>'],
                cwd=self.output_path,
                check=True,
                capture_output=True
            )
            print("  ✓ Initial commit created")

        except subprocess.CalledProcessError as e:
            print(f"  ⚠ Git initialization failed: {e}")

        print()

    def install_dependencies(self, install_deps: bool = False):
        """Install dependencies (optional)."""
        if not install_deps:
            print("⏭️  Skipping dependency installation (use --install to enable)")
            print()
            return

        print("📥 Installing dependencies...")

        try:
            subprocess.run(
                [self.package_manager, 'install'],
                cwd=self.output_path,
                check=True
            )
            print("  ✓ Dependencies installed")

            # Install lefthook
            subprocess.run(
                [self.package_manager, 'lefthook', 'install'],
                cwd=self.output_path,
                check=True,
                capture_output=True
            )
            print("  ✓ Lefthook hooks installed")

        except subprocess.CalledProcessError as e:
            print(f"  ⚠ Installation failed: {e}")

        print()

    def print_next_steps(self):
        """Print next steps for user."""
        print("="*70)
        print("  ✅ PROJECT BOOTSTRAPPED SUCCESSFULLY!")
        print("="*70)
        print()
        print("📂 Project created at:", self.output_path)
        print()
        print("📝 Next steps:")
        print()
        print(f"  1. cd {self.output_path}")
        print(f"  2. {self.package_manager} install")
        print(f"  3. Review and customize CLAUDE.md")
        print(f"  4. {self.package_manager} dev")
        print()
        print("🔍 Validate compliance:")
        print(f"  python {self.standards_path}/scripts/validate-compliance.py --project-path {self.output_path}")
        print()
        print("📚 Documentation:")
        print("  - CLAUDE.md - Project instructions for Claude Code")
        print("  - README.md - Getting started guide")
        print("  - docs/ - Architecture and guides")
        print()


def main():
    parser = argparse.ArgumentParser(
        description='Bootstrap new project with engineering standards',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  # Bootstrap Next.js project
  python bootstrap-project.py --project-name "My SaaS" --project-type nextjs --output-path ./my-saas

  # Bootstrap with framework
  python bootstrap-project.py --project-name "My App" --project-type nextjs --framework makerkit --output-path ./my-app

  # Bootstrap monorepo
  python bootstrap-project.py --project-name "My Monorepo" --project-type monorepo --output-path ./my-monorepo

  # Bootstrap and install dependencies
  python bootstrap-project.py --project-name "My Project" --project-type nextjs --output-path ./my-project --install
        """
    )

    parser.add_argument(
        '--project-name',
        required=True,
        help='Project name (e.g., "My Project")'
    )
    parser.add_argument(
        '--project-type',
        required=True,
        choices=['nextjs', 'flutter', 'monorepo', 'backend'],
        help='Project type'
    )
    parser.add_argument(
        '--output-path',
        type=Path,
        required=True,
        help='Output directory path'
    )
    parser.add_argument(
        '--framework',
        choices=['makerkit', 'apparencekit', 'supabase'],
        help='Framework/boilerplate (optional)'
    )
    parser.add_argument(
        '--package-manager',
        choices=['pnpm', 'npm', 'yarn'],
        default='pnpm',
        help='Package manager (default: pnpm)'
    )
    parser.add_argument(
        '--install',
        action='store_true',
        help='Install dependencies after bootstrap'
    )

    args = parser.parse_args()

    # Validate output path doesn't exist
    if args.output_path.exists():
        print(f"❌ Error: Output path already exists: {args.output_path}")
        print("   Please choose a different location or remove the existing directory.")
        sys.exit(1)

    # Find engineering-standards skill path
    script_dir = Path(__file__).parent.parent

    # Bootstrap project
    bootstrapper = ProjectBootstrapper(
        project_name=args.project_name,
        project_type=args.project_type,
        output_path=args.output_path,
        standards_path=script_dir,
        framework=args.framework,
        package_manager=args.package_manager
    )

    try:
        bootstrapper.create_directory_structure()
        bootstrapper.copy_templates()
        bootstrapper.create_package_json()
        bootstrapper.create_tsconfig()
        bootstrapper.create_readme()
        bootstrapper.initialize_git()
        bootstrapper.install_dependencies(args.install)
        bootstrapper.print_next_steps()

        sys.exit(0)

    except Exception as e:
        print(f"❌ Error during bootstrap: {e}")
        import traceback
        traceback.print_exc()
        sys.exit(1)


if __name__ == '__main__':
    main()
