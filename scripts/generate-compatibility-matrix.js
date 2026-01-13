#!/usr/bin/env node

/**
 * Generates a compatibility matrix between Cortex Packages and Cortex Skills
 *
 * Usage:
 *   node scripts/generate-compatibility-matrix.js [--packages-path=<path>]
 *
 * Options:
 *   --packages-path  Path to cortex-packages repo (default: ../cortex-packages)
 *
 * Outputs:
 *   - COMPATIBILITY.md in current directory
 *   - Can also output to cortex-packages if path provided
 */

import { readFileSync, writeFileSync, readdirSync, statSync, existsSync } from 'fs';
import { join, dirname } from 'path';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);
const SKILLS_ROOT = join(__dirname, '..');

// Parse command line arguments
const args = process.argv.slice(2);
const packagesPath = args.find(arg => arg.startsWith('--packages-path='))?.split('=')[1] || '../cortex-packages';

const PACKAGES_ROOT = join(SKILLS_ROOT, packagesPath);

// Colors
const colors = {
  reset: '\x1b[0m',
  bright: '\x1b[1m',
  green: '\x1b[32m',
  yellow: '\x1b[33m',
  blue: '\x1b[34m',
};

/**
 * Get all package versions from cortex-packages
 */
function getPackageVersions() {
  const packagesDir = join(PACKAGES_ROOT, 'packages');

  if (!existsSync(packagesDir)) {
    console.log(`${colors.yellow}Warning: Packages directory not found at ${packagesDir}${colors.reset}`);
    return {};
  }

  const packages = {};
  const dirs = readdirSync(packagesDir);

  for (const dir of dirs) {
    const pkgJsonPath = join(packagesDir, dir, 'package.json');

    if (existsSync(pkgJsonPath)) {
      try {
        const pkgJson = JSON.parse(readFileSync(pkgJsonPath, 'utf8'));
        if (pkgJson.name && pkgJson.name.startsWith('@akson/cortex-')) {
          packages[pkgJson.name] = {
            version: pkgJson.version,
            description: pkgJson.description || '',
            path: `packages/${dir}`
          };
        }
      } catch (error) {
        console.log(`${colors.yellow}Warning: Failed to parse ${pkgJsonPath}${colors.reset}`);
      }
    }
  }

  return packages;
}

/**
 * Find all skill configs
 */
function findSkillConfigs(dir) {
  const configs = [];

  try {
    const entries = readdirSync(dir);

    for (const entry of entries) {
      const fullPath = join(dir, entry);
      const stat = statSync(fullPath);

      if (stat.isDirectory()) {
        if (!entry.startsWith('.') && entry !== 'node_modules') {
          configs.push(...findSkillConfigs(fullPath));
        }
      } else if (entry === 'skill.config.json') {
        configs.push(fullPath);
      }
    }
  } catch (error) {
    // Skip directories we can't read
  }

  return configs;
}

/**
 * Parse skill dependencies
 */
function getSkillDependencies() {
  const skillsDir = join(SKILLS_ROOT, 'skills');
  const configs = findSkillConfigs(skillsDir);

  const skillDeps = [];

  for (const configPath of configs) {
    try {
      const content = readFileSync(configPath, 'utf8');
      const config = JSON.parse(content);

      const packages = config.dependencies?.packages || [];
      const relPath = configPath
        .replace(SKILLS_ROOT + '/', '')
        .replace('/skill.config.json', '');

      for (const pkg of packages) {
        skillDeps.push({
          skill: relPath,
          skillName: config.skill || relPath.split('/').pop(),
          skillVersion: config.version || '1.0.0',
          package: pkg.name,
          packageVersion: pkg.version || 'latest',
          description: pkg.description || ''
        });
      }
    } catch (error) {
      console.log(`${colors.yellow}Warning: Failed to parse ${configPath}${colors.reset}`);
    }
  }

  return skillDeps;
}

/**
 * Generate compatibility matrix markdown
 */
function generateMatrix(packages, skillDeps) {
  const now = new Date().toISOString().split('T')[0];

  let markdown = `# Cortex Compatibility Matrix

**Last Updated:** ${now}

This matrix shows the compatibility between Cortex NPM packages and Cortex Skills.

## Overview

- **Packages**: ${Object.keys(packages).length} published packages
- **Skills**: ${new Set(skillDeps.map(d => d.skill)).size} skills with package dependencies
- **Total Mappings**: ${skillDeps.length} package→skill dependencies

## Compatibility Table

| Package | Version | Skill | Skill Version | Required Version |
|---------|---------|-------|---------------|------------------|
`;

  // Sort by package name, then skill name
  const sorted = skillDeps.sort((a, b) => {
    if (a.package !== b.package) return a.package.localeCompare(b.package);
    return a.skill.localeCompare(b.skill);
  });

  for (const dep of sorted) {
    const pkg = packages[dep.package];
    const pkgVersion = pkg ? pkg.version : 'N/A';
    const skillPath = dep.skill;

    markdown += `| \`${dep.package}\` | ${pkgVersion} | [${dep.skillName}](skills/${skillPath}/) | ${dep.skillVersion} | ${dep.packageVersion} |\n`;
  }

  markdown += `\n## Packages Without Skills

The following packages don't have associated skills yet:

`;

  const packagesWithSkills = new Set(skillDeps.map(d => d.package));
  const packagesWithoutSkills = Object.keys(packages).filter(p => !packagesWithSkills.has(p));

  if (packagesWithoutSkills.length === 0) {
    markdown += `✅ All packages have associated skills!\n`;
  } else {
    for (const pkgName of packagesWithoutSkills.sort()) {
      const pkg = packages[pkgName];
      markdown += `- \`${pkgName}\` (${pkg.version}) - ${pkg.description}\n`;
    }
  }

  markdown += `\n## Skills By Category

`;

  // Group skills by collection/category
  const skillsByCategory = {};
  for (const dep of skillDeps) {
    const category = dep.skill.split('/')[1]; // e.g., "ballee" from "skills/ballee/..."
    if (!skillsByCategory[category]) {
      skillsByCategory[category] = new Set();
    }
    skillsByCategory[category].add(dep.skill);
  }

  for (const [category, skills] of Object.entries(skillsByCategory).sort()) {
    markdown += `\n### ${category} (${skills.size} skills)\n\n`;
    for (const skill of Array.from(skills).sort()) {
      const skillDepsForThis = skillDeps.filter(d => d.skill === skill);
      const packages = skillDepsForThis.map(d => `\`${d.package}\``).join(', ');
      markdown += `- **${skill.split('/').pop()}**: ${packages}\n`;
    }
  }

  markdown += `\n## Using This Matrix

### For Package Developers

When making changes to a package:

1. Check which skills reference your package
2. Update skill documentation if API changes
3. Coordinate with skill maintainers for breaking changes
4. Run \`npm version <major|minor|patch>\` to trigger skill sync

### For Skill Developers

When creating or updating skills:

1. Declare package dependencies in \`skill.config.json\`
2. Use semantic versioning for package requirements
3. Test skills with specified package versions
4. Update this matrix via \`npm run generate:compatibility\`

### Version Notation

- \`^2.0.0\` - Compatible with 2.x.x (semver caret)
- \`~2.0.0\` - Compatible with 2.0.x (semver tilde)
- \`2.0.0\` - Exact version required
- \`latest\` - Any version (use with caution)

## Automation

This matrix is automatically updated:

- **Weekly**: Via GitHub Actions
- **On Package Publish**: When packages are released
- **Manually**: Run \`npm run generate:compatibility\`

## Related Resources

- [Cortex Packages Repository](https://github.com/antoineschaller/cortex-packages)
- [Cortex Skills Repository](https://github.com/antoineschaller/cortex-skills)
- [NPM Packages](https://www.npmjs.com/search?q=%40akson%2Fcortex)

---

*Generated by cortex-skills/scripts/generate-compatibility-matrix.js*
`;

  return markdown;
}

/**
 * Main
 */
function main() {
  console.log(`${colors.bright}Cortex Compatibility Matrix Generator${colors.reset}\n`);

  console.log(`Skills root: ${SKILLS_ROOT}`);
  console.log(`Packages root: ${PACKAGES_ROOT}\n`);

  // Get package versions
  console.log(`${colors.blue}Scanning packages...${colors.reset}`);
  const packages = getPackageVersions();
  console.log(`Found ${Object.keys(packages).length} packages\n`);

  // Get skill dependencies
  console.log(`${colors.blue}Scanning skills...${colors.reset}`);
  const skillDeps = getSkillDependencies();
  console.log(`Found ${skillDeps.length} skill→package dependencies\n`);

  // Generate matrix
  console.log(`${colors.blue}Generating compatibility matrix...${colors.reset}`);
  const markdown = generateMatrix(packages, skillDeps);

  // Write to skills repo
  const skillsOutputPath = join(SKILLS_ROOT, 'COMPATIBILITY.md');
  writeFileSync(skillsOutputPath, markdown, 'utf8');
  console.log(`${colors.green}✓${colors.reset} Written to: ${skillsOutputPath}`);

  // Write to packages repo if it exists
  if (existsSync(PACKAGES_ROOT)) {
    const packagesOutputPath = join(PACKAGES_ROOT, 'COMPATIBILITY.md');
    writeFileSync(packagesOutputPath, markdown, 'utf8');
    console.log(`${colors.green}✓${colors.reset} Written to: ${packagesOutputPath}`);
  }

  console.log(`\n${colors.bright}${colors.green}Done!${colors.reset}\n`);
}

main();
