#!/usr/bin/env node

/**
 * Validates that all skill package dependencies reference valid npm packages
 *
 * Usage:
 *   node scripts/validate-package-deps.js
 *
 * Exit codes:
 *   0 - All dependencies valid
 *   1 - Invalid dependencies found
 */

import { readFileSync, readdirSync, statSync } from 'fs';
import { join, dirname } from 'path';
import { fileURLToPath } from 'url';
import https from 'https';

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);
const ROOT = join(__dirname, '..');

// Colors for terminal output
const colors = {
  reset: '\x1b[0m',
  bright: '\x1b[1m',
  red: '\x1b[31m',
  green: '\x1b[32m',
  yellow: '\x1b[33m',
  blue: '\x1b[34m',
};

// Track validation results
const results = {
  totalSkills: 0,
  skillsWithDeps: 0,
  totalPackages: 0,
  validPackages: 0,
  invalidPackages: [],
  errors: [],
};

/**
 * Fetch package info from npm registry
 */
async function fetchPackageInfo(packageName) {
  return new Promise((resolve, reject) => {
    const url = `https://registry.npmjs.org/${packageName}`;

    https.get(url, {
      headers: { 'User-Agent': 'cortex-skills-validator' }
    }, (res) => {
      let data = '';

      res.on('data', (chunk) => {
        data += chunk;
      });

      res.on('end', () => {
        if (res.statusCode === 200) {
          try {
            resolve(JSON.parse(data));
          } catch (e) {
            reject(new Error(`Failed to parse npm response for ${packageName}`));
          }
        } else if (res.statusCode === 404) {
          resolve(null); // Package not found
        } else {
          reject(new Error(`HTTP ${res.statusCode} for ${packageName}`));
        }
      });
    }).on('error', reject);
  });
}

/**
 * Validate a package dependency
 */
async function validatePackage(packageName, version, skillPath) {
  results.totalPackages++;

  console.log(`  Checking ${colors.blue}${packageName}${colors.reset} @ ${version}...`);

  try {
    const pkgInfo = await fetchPackageInfo(packageName);

    if (!pkgInfo) {
      results.invalidPackages.push({
        package: packageName,
        version,
        skill: skillPath,
        reason: 'Package not found on npm'
      });
      console.log(`    ${colors.red}✗ Package not found on npm${colors.reset}`);
      return false;
    }

    // Check if version exists
    const versions = Object.keys(pkgInfo.versions || {});
    if (versions.length === 0) {
      results.invalidPackages.push({
        package: packageName,
        version,
        skill: skillPath,
        reason: 'No versions published'
      });
      console.log(`    ${colors.red}✗ No versions published${colors.reset}`);
      return false;
    }

    // For specific versions (not ranges), check if version exists
    if (version && !version.includes('^') && !version.includes('~') && !version.includes('*') && version !== 'latest') {
      if (!versions.includes(version)) {
        results.invalidPackages.push({
          package: packageName,
          version,
          skill: skillPath,
          reason: `Version ${version} not found. Available: ${versions.slice(-3).join(', ')}`
        });
        console.log(`    ${colors.red}✗ Version ${version} not found${colors.reset}`);
        return false;
      }
    }

    results.validPackages++;
    console.log(`    ${colors.green}✓ Valid${colors.reset} (latest: ${pkgInfo['dist-tags'].latest})`);
    return true;
  } catch (error) {
    results.errors.push({
      package: packageName,
      skill: skillPath,
      error: error.message
    });
    console.log(`    ${colors.yellow}⚠ Error checking package: ${error.message}${colors.reset}`);
    return false;
  }
}

/**
 * Process a skill configuration file
 */
async function processSkillConfig(configPath) {
  const relPath = configPath.replace(ROOT + '/', '');

  try {
    const content = readFileSync(configPath, 'utf8');
    const config = JSON.parse(content);

    results.totalSkills++;

    // Check if skill has package dependencies
    const packages = config.dependencies?.packages || [];

    if (packages.length === 0) {
      console.log(`${colors.blue}${relPath}${colors.reset}: No package dependencies`);
      return;
    }

    results.skillsWithDeps++;
    console.log(`\n${colors.bright}${relPath}${colors.reset}:`);

    // Validate each package
    for (const pkg of packages) {
      await validatePackage(pkg.name, pkg.version || 'latest', relPath);
    }
  } catch (error) {
    results.errors.push({
      skill: relPath,
      error: error.message
    });
    console.log(`${colors.red}✗ Error processing ${relPath}: ${error.message}${colors.reset}`);
  }
}

/**
 * Find all skill.config.json files recursively
 */
function findSkillConfigs(dir) {
  const configs = [];

  try {
    const entries = readdirSync(dir);

    for (const entry of entries) {
      const fullPath = join(dir, entry);
      const stat = statSync(fullPath);

      if (stat.isDirectory()) {
        // Skip node_modules and hidden directories
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
 * Print summary
 */
function printSummary() {
  console.log(`\n${'='.repeat(60)}`);
  console.log(`${colors.bright}Validation Summary${colors.reset}`);
  console.log(`${'='.repeat(60)}`);
  console.log(`Total skills: ${results.totalSkills}`);
  console.log(`Skills with package dependencies: ${results.skillsWithDeps}`);
  console.log(`Total packages checked: ${results.totalPackages}`);
  console.log(`Valid packages: ${colors.green}${results.validPackages}${colors.reset}`);
  console.log(`Invalid packages: ${results.invalidPackages.length > 0 ? colors.red : colors.green}${results.invalidPackages.length}${colors.reset}`);
  console.log(`Errors: ${results.errors.length > 0 ? colors.yellow : colors.green}${results.errors.length}${colors.reset}`);

  // Print invalid packages
  if (results.invalidPackages.length > 0) {
    console.log(`\n${colors.red}${colors.bright}Invalid Packages:${colors.reset}`);
    for (const invalid of results.invalidPackages) {
      console.log(`\n  ${colors.red}✗${colors.reset} ${invalid.package} @ ${invalid.version}`);
      console.log(`    Skill: ${invalid.skill}`);
      console.log(`    Reason: ${invalid.reason}`);
    }
  }

  // Print errors
  if (results.errors.length > 0) {
    console.log(`\n${colors.yellow}${colors.bright}Errors:${colors.reset}`);
    for (const error of results.errors) {
      console.log(`\n  ${colors.yellow}⚠${colors.reset} ${error.skill || error.package}`);
      console.log(`    Error: ${error.error}`);
    }
  }

  console.log(`\n${'='.repeat(60)}\n`);
}

/**
 * Main
 */
async function main() {
  console.log(`${colors.bright}Cortex Skills - Package Dependency Validator${colors.reset}\n`);
  console.log(`Scanning for skill.config.json files in: ${ROOT}/skills/\n`);

  // Find all skill configs
  const configs = findSkillConfigs(join(ROOT, 'skills'));

  if (configs.length === 0) {
    console.log(`${colors.yellow}No skill.config.json files found${colors.reset}`);
    return;
  }

  console.log(`Found ${configs.length} skill configuration files\n`);

  // Process each config
  for (const config of configs) {
    await processSkillConfig(config);
  }

  // Print summary
  printSummary();

  // Exit with error if there are invalid packages
  if (results.invalidPackages.length > 0) {
    process.exit(1);
  }
}

main().catch((error) => {
  console.error(`${colors.red}Fatal error: ${error.message}${colors.reset}`);
  process.exit(1);
});
