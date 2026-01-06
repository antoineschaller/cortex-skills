# Database Lint Manager Scripts

Helper scripts for running database function linting across environments.

## Scripts

### run-lint.sh
Run `supabase db lint` on specified environment with consistent output.

```bash
./run-lint.sh local       # Lint local database
./run-lint.sh staging     # Lint staging database
./run-lint.sh production  # Lint production database
```

### analyze-usage.sh
Find which database functions are actually called in the codebase.

```bash
./analyze-usage.sh get_events_with_cast    # Check single function
./analyze-usage.sh --all                   # Check all functions from lint output
```

### generate-report.sh
Parse lint output and generate comprehensive categorized report.

```bash
./generate-report.sh lint-output.json      # Generate markdown report
./generate-report.sh --env production      # Run lint and generate report
```

## Prerequisites

- Supabase CLI installed
- For local: Docker running with Supabase (`pnpm supabase:web:start`)
- For staging: 1Password CLI or `SUPABASE_DB_PASSWORD_STAGING` env var
- For production: Project linked (`supabase link`)

## Environment Variables

| Variable | Description |
|----------|-------------|
| `SUPABASE_DB_PASSWORD_STAGING` | Staging database password (if not using 1Password) |
| `PROJECT_ROOT` | Override project root detection |

## Output

All scripts output to stdout by default. Use redirection to save:

```bash
./run-lint.sh production > lint-output.json
./generate-report.sh lint-output.json > report.md
```
