/**
 * ESLint configuration for cortex-skills
 * Uses shared config from @akson/cortex-dev-tools
 */

module.exports = {
  extends: '@akson/cortex-dev-tools/eslint',
  rules: {
    // Project-specific overrides
    'no-console': 'off', // Skills often include console examples
  },
  ignorePatterns: [
    'node_modules/',
    'dist/',
    'templates/',
    '*.config.js',
  ],
};
