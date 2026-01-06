#!/bin/bash
#
# SQL Execution Tool for Production Supabase
#
# A simple wrapper around psql for executing SQL queries against production database.
# Supports both inline queries, file execution, and interactive mode.
#
# Usage:
#   ./scripts/sql-exec.sh "SELECT * FROM clients LIMIT 5"
#   ./scripts/sql-exec.sh --file query.sql
#   ./scripts/sql-exec.sh --interactive
#   ./scripts/sql-exec.sh --inspect clients
#
# Environment Variables:
#   SUPABASE_DB_URL - PostgreSQL connection string
#   Or individual components:
#     SUPABASE_DB_HOST
#     SUPABASE_DB_PORT
#     SUPABASE_DB_NAME
#     SUPABASE_DB_USER
#     SUPABASE_DB_PASSWORD
#

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default options
MODE="query"
WRITE_MODE=false
DRY_RUN=false
OUTPUT_FORMAT="table"
HISTORY_FILE=".sql-exec-history.log"

# Parse arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --file|-f)
      MODE="file"
      SQL_FILE="$2"
      shift 2
      ;;
    --interactive|-i)
      MODE="interactive"
      shift
      ;;
    --inspect)
      MODE="inspect"
      TABLE_NAME="$2"
      shift 2
      ;;
    --write)
      WRITE_MODE=true
      shift
      ;;
    --dry-run)
      DRY_RUN=true
      shift
      ;;
    --json)
      OUTPUT_FORMAT="json"
      shift
      ;;
    --help|-h)
      echo "SQL Execution Tool for Production Supabase"
      echo ""
      echo "Usage:"
      echo "  $0 [options] \"<query>\""
      echo "  $0 --file query.sql"
      echo "  $0 --interactive"
      echo ""
      echo "Options:"
      echo "  --file, -f <path>     Execute SQL from file"
      echo "  --interactive, -i     Interactive psql session"
      echo "  --inspect <table>     Inspect table schema"
      echo "  --write               Allow write operations"
      echo "  --dry-run             Show query without executing"
      echo "  --json                Output as JSON"
      echo "  --help, -h            Show this help"
      echo ""
      echo "Examples:"
      echo "  $0 \"SELECT * FROM clients LIMIT 5\""
      echo "  $0 --file test.sql"
      echo "  $0 --inspect clients"
      echo "  $0 --interactive"
      echo ""
      echo "Connection:"
      echo "  Set SUPABASE_DB_URL or individual components"
      echo "  (SUPABASE_DB_HOST, PORT, NAME, USER, PASSWORD)"
      exit 0
      ;;
    *)
      QUERY="$1"
      shift
      ;;
  esac
done

# Build connection string
if [ -n "$SUPABASE_DB_URL" ]; then
  CONN_STRING="$SUPABASE_DB_URL"
else
  # Build from individual components
  DB_HOST="${SUPABASE_DB_HOST:-}"
  DB_PORT="${SUPABASE_DB_PORT:-5432}"
  DB_NAME="${SUPABASE_DB_NAME:-postgres}"
  DB_USER="${SUPABASE_DB_USER:-postgres}"
  DB_PASSWORD="${SUPABASE_DB_PASSWORD:-}"

  if [ -z "$DB_HOST" ] || [ -z "$DB_PASSWORD" ]; then
    echo -e "${RED}❌ Error: Missing database connection details${NC}"
    echo ""
    echo "Set one of:"
    echo "  SUPABASE_DB_URL - Full PostgreSQL connection string"
    echo "Or:"
    echo "  SUPABASE_DB_HOST and SUPABASE_DB_PASSWORD (with optional PORT, NAME, USER)"
    echo ""
    echo "Get connection details from:"
    echo "  Supabase Dashboard → Project Settings → Database → Connection String"
    exit 1
  fi

  CONN_STRING="postgresql://${DB_USER}:${DB_PASSWORD}@${DB_HOST}:${DB_PORT}/${DB_NAME}"
fi

# Log query to history
log_query() {
  local query="$1"
  echo "[$(date -u +"%Y-%m-%dT%H:%M:%SZ")] [service_role] $query" >> "$HISTORY_FILE"
}

# Check if query is destructive
is_destructive() {
  local query="$1"
  echo "$query" | grep -Eiq "^[[:space:]]*(INSERT|UPDATE|DELETE|DROP|ALTER|TRUNCATE|CREATE)"
}

# Confirm destructive operation
confirm_destructive() {
  local query="$1"
  echo -e "${YELLOW}⚠️  DESTRUCTIVE OPERATION DETECTED:${NC}"
  echo "   ${query:0:100}${#query -gt 100:+...}"
  echo ""
  read -p "Are you sure you want to execute this? (yes/no): " -r
  echo ""
  if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
    echo -e "${RED}Operation cancelled${NC}"
    exit 1
  fi
}

# Execute query
execute_query() {
  local query="$1"

  # Safety check
  if [ "$WRITE_MODE" = false ] && is_destructive "$query"; then
    echo -e "${RED}❌ Error: Destructive query blocked${NC}"
    echo "   Use --write flag to execute INSERT/UPDATE/DELETE operations"
    exit 1
  fi

  # Confirm destructive operations
  if [ "$WRITE_MODE" = true ] && is_destructive "$query"; then
    confirm_destructive "$query"
  fi

  # Log query
  log_query "$query"

  # Dry run
  if [ "$DRY_RUN" = true ]; then
    echo -e "${BLUE}Dry run - query would be:${NC}"
    echo "$query"
    exit 0
  fi

  # Execute
  if [ "$OUTPUT_FORMAT" = "json" ]; then
    psql "$CONN_STRING" -c "\timing off" -c "$query" -t -A -F',' --quiet 2>&1
  else
    echo -e "${GREEN}Executing query...${NC}\n"
    psql "$CONN_STRING" -c "\timing on" -c "$query"
  fi
}

# Inspect table
inspect_table() {
  local table="$1"

  echo -e "${BLUE}📋 Inspecting table: $table${NC}\n"

  # Table structure
  echo "======================================================================"
  echo "COLUMNS:"
  echo "======================================================================"
  psql "$CONN_STRING" -c "
    SELECT
      column_name,
      data_type,
      is_nullable,
      column_default
    FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = '$table'
    ORDER BY ordinal_position;
  "

  # RLS policies
  echo ""
  echo "======================================================================"
  echo "RLS POLICIES:"
  echo "======================================================================"
  psql "$CONN_STRING" -c "
    SELECT
      policyname AS policy,
      cmd AS command,
      roles,
      qual AS using_expression,
      with_check AS with_check_expression
    FROM pg_policies
    WHERE tablename = '$table';
  "

  # Indexes
  echo ""
  echo "======================================================================"
  echo "INDEXES:"
  echo "======================================================================"
  psql "$CONN_STRING" -c "
    SELECT
      indexname AS index_name,
      indexdef AS definition
    FROM pg_indexes
    WHERE tablename = '$table';
  "
}

# Main execution
case $MODE in
  query)
    if [ -z "$QUERY" ]; then
      echo -e "${RED}❌ Error: No query provided${NC}"
      echo "Use --help for usage information"
      exit 1
    fi
    execute_query "$QUERY"
    ;;

  file)
    if [ ! -f "$SQL_FILE" ]; then
      echo -e "${RED}❌ Error: File not found: $SQL_FILE${NC}"
      exit 1
    fi
    echo -e "${GREEN}Executing SQL from file: $SQL_FILE${NC}\n"
    QUERY=$(cat "$SQL_FILE")
    execute_query "$QUERY"
    ;;

  interactive)
    echo -e "${BLUE}🔧 SQL Debug Tool - Interactive Mode${NC}"
    echo "======================================================================"
    echo "Connected to: $(echo $CONN_STRING | sed 's/:\/\/[^:]*:[^@]*@/:\/\/***:***@/')"
    echo "Type \\q to quit"
    echo ""
    psql "$CONN_STRING"
    ;;

  inspect)
    if [ -z "$TABLE_NAME" ]; then
      echo -e "${RED}❌ Error: No table name provided${NC}"
      exit 1
    fi
    inspect_table "$TABLE_NAME"
    ;;
esac
