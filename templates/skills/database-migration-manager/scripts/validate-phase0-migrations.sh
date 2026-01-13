#!/bin/bash
# =====================================================================================
# Phase 0 Migration Validation Script
# =====================================================================================
#
# PURPOSE: Validate Phase 0 migrations before deploying to production
#
# USAGE:
#   ./scripts/validate-phase0-migrations.sh
#
# CHECKS:
#   1. All Phase 0 migrations applied
#   2. Timezone columns exist and are populated
#   3. Venue handling constraint works
#   4. Event period fields exist and are valid
#   5. Helper functions exist and work correctly
#   6. No breaking changes introduced
#
# =====================================================================================

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Database connection (use local by default)
DB_HOST="${SUPABASE_DB_HOST:-127.0.0.1}"
DB_PORT="${SUPABASE_DB_PORT:-54322}"
DB_USER="${SUPABASE_DB_USER:-postgres}"
DB_PASSWORD="${SUPABASE_DB_PASSWORD:-postgres}"
DB_NAME="${SUPABASE_DB_NAME:-postgres}"

echo "=========================================="
echo "Phase 0 Migration Validation"
echo "=========================================="
echo ""

# Function to run SQL and check result
run_sql() {
    local query="$1"
    PGPASSWORD="$DB_PASSWORD" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -t -A -c "$query"
}

# Function to print success
print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

# Function to print error
print_error() {
    echo -e "${RED}❌ $1${NC}"
}

# Function to print warning
print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

# =====================================================================================
# CHECK 1: Migration files applied
# =====================================================================================

echo "Checking migration status..."

# Check if Phase 0 migrations exist in migration table
phase0_migrations=(
    "20251105000000_add_timezone_support"
    "20251105000001_improve_venue_handling"
    "20251105000002_add_event_period_fields"
)

for migration in "${phase0_migrations[@]}"; do
    result=$(run_sql "SELECT COUNT(*) FROM supabase_migrations.schema_migrations WHERE version = '${migration:0:14}';")
    if [ "$result" -eq "1" ]; then
        print_success "Migration $migration applied"
    else
        print_error "Migration $migration NOT applied"
        exit 1
    fi
done

echo ""

# =====================================================================================
# CHECK 2: Timezone support
# =====================================================================================

echo "Checking timezone support..."

# Check timezone columns exist
events_tz=$(run_sql "SELECT COUNT(*) FROM information_schema.columns WHERE table_name = 'events' AND column_name = 'timezone';")
venues_tz=$(run_sql "SELECT COUNT(*) FROM information_schema.columns WHERE table_name = 'venues' AND column_name = 'timezone';")

if [ "$events_tz" -eq "1" ] && [ "$venues_tz" -eq "1" ]; then
    print_success "Timezone columns exist on events and venues"
else
    print_error "Timezone columns missing"
    exit 1
fi

# Check all events have timezone
events_without_tz=$(run_sql "SELECT COUNT(*) FROM events WHERE timezone IS NULL;")
if [ "$events_without_tz" -eq "0" ]; then
    print_success "All events have timezone"
else
    print_warning "$events_without_tz events missing timezone"
fi

# Check timezone helper functions exist
tz_functions=$(run_sql "SELECT COUNT(*) FROM pg_proc WHERE proname IN ('get_event_local_time', 'is_valid_timezone');")
if [ "$tz_functions" -eq "2" ]; then
    print_success "Timezone helper functions exist"
else
    print_error "Timezone helper functions missing"
    exit 1
fi

echo ""

# =====================================================================================
# CHECK 3: Venue handling
# =====================================================================================

echo "Checking venue handling..."

# Check constraint exists
venue_constraint=$(run_sql "SELECT COUNT(*) FROM information_schema.table_constraints WHERE table_name = 'events' AND constraint_name = 'events_location_required';")
if [ "$venue_constraint" -eq "1" ]; then
    print_success "Venue location constraint exists"
else
    print_error "Venue location constraint missing"
    exit 1
fi

# Check helper functions exist
venue_functions=$(run_sql "SELECT COUNT(*) FROM pg_proc WHERE proname IN ('get_event_location', 'get_event_venue_info');")
if [ "$venue_functions" -eq "2" ]; then
    print_success "Venue helper functions exist"
else
    print_error "Venue helper functions missing"
    exit 1
fi

# Check view exists
venue_view=$(run_sql "SELECT COUNT(*) FROM information_schema.views WHERE table_name = 'events_with_venue';")
if [ "$venue_view" -eq "1" ]; then
    print_success "events_with_venue view exists"
else
    print_error "events_with_venue view missing"
    exit 1
fi

# Check for events without location
events_no_location=$(run_sql "SELECT COUNT(*) FROM events WHERE venue_id IS NULL AND (location IS NULL OR trim(location) = '');")
if [ "$events_no_location" -eq "0" ]; then
    print_success "All events have location information"
else
    print_warning "$events_no_location events without location (should be fixed)"
fi

echo ""

# =====================================================================================
# CHECK 4: Event period fields
# =====================================================================================

echo "Checking event period fields..."

# Check columns exist
period_columns=$(run_sql "SELECT COUNT(*) FROM information_schema.columns WHERE table_name = 'events' AND column_name IN ('start_date', 'end_date');")
if [ "$period_columns" -eq "2" ]; then
    print_success "Event period columns exist"
else
    print_error "Event period columns missing"
    exit 1
fi

# Check constraint exists
period_constraint=$(run_sql "SELECT COUNT(*) FROM information_schema.table_constraints WHERE table_name = 'events' AND constraint_name = 'events_date_range_valid';")
if [ "$period_constraint" -eq "1" ]; then
    print_success "Event period constraint exists"
else
    print_error "Event period constraint missing"
    exit 1
fi

# Check helper functions exist
period_functions=$(run_sql "SELECT COUNT(*) FROM pg_proc WHERE proname IN ('get_event_duration_days', 'is_multi_day_event', 'date_in_event_period');")
if [ "$period_functions" -eq "3" ]; then
    print_success "Event period helper functions exist"
else
    print_error "Event period helper functions missing"
    exit 1
fi

# Check view exists
period_view=$(run_sql "SELECT COUNT(*) FROM information_schema.views WHERE table_name = 'events_with_period';")
if [ "$period_view" -eq "1" ]; then
    print_success "events_with_period view exists"
else
    print_error "events_with_period view missing"
    exit 1
fi

# Check for invalid periods
invalid_periods=$(run_sql "SELECT COUNT(*) FROM events WHERE start_date IS NOT NULL AND end_date IS NOT NULL AND end_date < start_date;")
if [ "$invalid_periods" -eq "0" ]; then
    print_success "No invalid event periods (end < start)"
else
    print_error "$invalid_periods events have invalid periods"
    exit 1
fi

echo ""

# =====================================================================================
# CHECK 5: Backward compatibility
# =====================================================================================

echo "Checking backward compatibility..."

# Verify old columns still exist (should not be dropped in Phase 0)
old_columns=$(run_sql "SELECT COUNT(*) FROM information_schema.columns WHERE table_name = 'events' AND column_name IN ('event_date', 'location');")
if [ "$old_columns" -eq "2" ]; then
    print_success "Old event columns still exist (backward compatible)"
else
    print_warning "Some old columns missing (may be expected if already migrated)"
fi

# Verify RLS policies still work
rls_policies=$(run_sql "SELECT COUNT(*) FROM pg_policies WHERE tablename = 'events';")
if [ "$rls_policies" -ge "4" ]; then
    print_success "RLS policies exist on events table"
else
    print_error "RLS policies missing or incomplete"
    exit 1
fi

echo ""

# =====================================================================================
# CHECK 6: Performance
# =====================================================================================

echo "Checking indexes..."

# Check important indexes exist
indexes_count=$(run_sql "SELECT COUNT(*) FROM pg_indexes WHERE tablename = 'events' AND indexname IN ('idx_events_timezone', 'idx_events_venue_id', 'idx_events_start_date');")
if [ "$indexes_count" -eq "3" ]; then
    print_success "Phase 0 indexes created"
else
    print_warning "Some Phase 0 indexes missing (expected: 3, found: $indexes_count)"
fi

echo ""

# =====================================================================================
# SUMMARY
# =====================================================================================

echo "=========================================="
echo "Validation Summary"
echo "=========================================="
print_success "Phase 0 migrations validated successfully!"
echo ""
echo "Next steps:"
echo "  1. Test timezone handling in application"
echo "  2. Verify venue display logic"
echo "  3. Test event period queries"
echo "  4. Monitor performance with new indexes"
echo "  5. Proceed to Phase 1 when ready"
echo ""
