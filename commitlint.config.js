export default {
  extends: ['@commitlint/config-conventional'],
  rules: {
    'type-enum': [
      2,
      'always',
      [
        'feat',     // New skill or feature
        'fix',      // Bug fix in skill documentation or config
        'docs',     // Documentation-only changes
        'refactor', // Restructuring without changing behavior
        'test',     // Adding or updating tests
        'chore',    // Maintenance tasks
        'ci',       // CI/CD changes
      ],
    ],
    'scope-enum': [
      2,
      'always',
      [
        'skills',       // Project-specific skills
        'templates',    // Generic templates
        'agents',       // Agent configurations
        'scripts',      // Validation/assessment scripts
        'docs',         // Documentation
        'marketplace',  // Plugin configuration
        'ballee',       // Ballee-specific
        'shopify',      // Shopify-specific
        'analytics',    // Analytics-specific
        'lead-gen',     // Lead generation-specific
        'content',      // Content creation-specific
        'myarmy',       // MyArmy-specific
      ],
    ],
    'subject-case': [2, 'never', ['upper-case', 'pascal-case']],
    'header-max-length': [2, 'always', 100],
  },
};
