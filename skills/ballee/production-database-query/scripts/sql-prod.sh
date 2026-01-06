#!/bin/bash
#
# SQL Production Helper - Loads .env.production.local and executes sql-exec.sh
#
# This script tries to load connection details from .env.production.local
# If the file doesn't exist, it falls back to existing environment variables
# (useful when running in CI/CD or with manually set env vars)
#

set -a  # Auto-export all variables

# Try to load .env.production.local
if [ -f "$(dirname "$0")/../.env.production.local" ]; then
  source "$(dirname "$0")/../.env.production.local"
else
  # Check if environment variables are already set
  if [ -z "$SUPABASE_DB_URL" ] && [ -z "$SUPABASE_DB_HOST" ]; then
    echo "❌ Error: No production database connection configured"
    echo ""
    echo "Option 1: Create .env.production.local file"
    echo "  1. Copy the template:"
    echo "     cp apps/web/.env.production.example apps/web/.env.production.local"
    echo ""
    echo "  2. Edit .env.production.local and add your production connection string"
    echo ""
    echo "Option 2: Set environment variables directly"
    echo "  export SUPABASE_DB_URL=\"postgresql://user:pass@host:5432/postgres\""
    echo "  Or individual components (SUPABASE_DB_HOST, SUPABASE_DB_PASSWORD, etc.)"
    echo ""
    echo "Get credentials from 1Password (Ballee vault):"
    echo "  - Database Password: 'POSTGRES_PASSWORD' (ID: kuyspxxlyi2mxg7nfeb6dm3pje)"
    echo ""
    exit 1
  fi

  echo "ℹ️  Using environment variables (no .env.production.local file found)"
fi

set +a

# Execute sql-exec.sh with all arguments
exec "$(dirname "$0")/sql-exec.sh" "$@"
