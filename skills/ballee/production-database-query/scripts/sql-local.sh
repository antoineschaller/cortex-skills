#!/bin/bash
#
# SQL Local Helper - Loads .env.local and executes sql-exec.sh
#
set -a  # Auto-export all variables
source "$(dirname "$0")/../.env.local" 2>/dev/null || true
set +a

# Execute sql-exec.sh with all arguments
exec "$(dirname "$0")/sql-exec.sh" "$@"
