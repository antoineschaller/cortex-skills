#!/bin/bash
# =====================================================================================
# Phase 1 Migration Validation Script
# =====================================================================================
#
# PURPOSE: Validate Phase 1 migrations before deploying to production
#
# USAGE:
#   ./scripts/validate-phase1-migrations.sh
#
# CHECKS:
#   1. All Phase 1 migrations applied
#   2. event_showtimes table exists with correct structure
#   3. Participants have showtime support
#   4. Cast assignments have showtime support
#   5. Helper functions exist and work correctly
#   6. Views exist and return data
#   7. RLS policies configured correctly
#   8. No breaking changes introduced
#
# =====================================================================================

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Database connection (use local by default)
DB_HOST="${SUPABASE_DB_HOST:-127.0.0.1}"
DB_PORT="${SUPABASE_DB_PORT:-54322}"
DB_USER="${SUPABASE_DB_USER:-postgres}"
DB_PASSWORD="${SUPABASE_DB_PASSWORD:-postgres}"
DB_NAME="${SUPABASE_DB_NAME:-postgres}"

echo "=========================================="
echo "Phase 1 Migration Validation"
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

# Function to print info
print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

# =====================================================================================
# CHECK 1: Migration files applied
# =====================================================================================

echo "Checking migration status..."

# Check if Phase 1 migrations exist in migration table
phase1_migrations=(
    "20251112000000_create_event_showtimes"
    "20251112000001_add_showtime_support_to_participants"
    "20251112000002_add_showtime_support_to_cast_assignments"
)

for migration in "${phase1_migrations[@]}"; do
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
# CHECK 2: event_showtimes table
# =====================================================================================

echo "Checking event_showtimes table..."

# Check table exists
showtimes_table=$(run_sql "SELECT COUNT(*) FROM information_schema.tables WHERE table_name = 'event_showtimes';")
if [ "$showtimes_table" -eq "1" ]; then
    print_success "event_showtimes table exists"
else
    print_error "event_showtimes table missing"
    exit 1
fi

# Check required columns exist
required_columns=("id" "event_id" "showtime_date" "start_time" "start_datetime" "status" "display_order")
for col in "${required_columns[@]}"; do
    result=$(run_sql "SELECT COUNT(*) FROM information_schema.columns WHERE table_name = 'event_showtimes' AND column_name = '$col';")
    if [ "$result" -eq "1" ]; then
        print_success "Column event_showtimes.$col exists"
    else
        print_error "Column event_showtimes.$col missing"
        exit 1
    fi
done

# Check RLS enabled
rls_enabled=$(run_sql "SELECT relrowsecurity FROM pg_class WHERE relname = 'event_showtimes' AND relnamespace = 'public'::regnamespace;")
if [ "$rls_enabled" = "t" ]; then
    print_success "RLS enabled on event_showtimes"
else
    print_error "RLS not enabled on event_showtimes"
    exit 1
fi

# Check RLS policies
policy_count=$(run_sql "SELECT COUNT(*) FROM pg_policies WHERE tablename = 'event_showtimes';")
if [ "$policy_count" -ge "4" ]; then
    print_success "RLS policies exist on event_showtimes (found: $policy_count)"
else
    print_error "RLS policies missing on event_showtimes (expected: 4+, found: $policy_count)"
    exit 1
fi

echo ""

# =====================================================================================
# CHECK 3: Participant showtime support
# =====================================================================================

echo "Checking participant showtime support..."

# Check showtime_id column exists
participant_col=$(run_sql "SELECT COUNT(*) FROM information_schema.columns WHERE table_name = 'event_participants' AND column_name = 'showtime_id';")
if [ "$participant_col" -eq "1" ]; then
    print_success "event_participants.showtime_id column exists"
else
    print_error "event_participants.showtime_id column missing"
    exit 1
fi

# Check constraint exists
participant_constraint=$(run_sql "SELECT COUNT(*) FROM information_schema.table_constraints WHERE table_name = 'event_participants' AND constraint_name = 'participants_showtime_belongs_to_event';")
if [ "$participant_constraint" -eq "1" ]; then
    print_success "Participant showtime constraint exists"
else
    print_error "Participant showtime constraint missing"
    exit 1
fi

# Check helper functions
participant_functions=$(run_sql "SELECT COUNT(*) FROM pg_proc WHERE proname IN ('count_showtime_participants', 'count_showtime_confirmed', 'is_showtime_full');")
if [ "$participant_functions" -eq "3" ]; then
    print_success "Participant helper functions exist"
else
    print_warning "Some participant helper functions missing (expected: 3, found: $participant_functions)"
fi

# Check participation summary view
participant_view=$(run_sql "SELECT COUNT(*) FROM information_schema.views WHERE table_name = 'showtime_participation_summary';")
if [ "$participant_view" -eq "1" ]; then
    print_success "showtime_participation_summary view exists"
else
    print_error "showtime_participation_summary view missing"
    exit 1
fi

echo ""

# =====================================================================================
# CHECK 4: Cast assignment showtime support
# =====================================================================================

echo "Checking cast assignment showtime support..."

# Check showtime_id column exists
cast_col=$(run_sql "SELECT COUNT(*) FROM information_schema.columns WHERE table_name = 'cast_assignments' AND column_name = 'showtime_id';")
if [ "$cast_col" -eq "1" ]; then
    print_success "cast_assignments.showtime_id column exists"
else
    print_error "cast_assignments.showtime_id column missing"
    exit 1
fi

# Check constraint exists
cast_constraint=$(run_sql "SELECT COUNT(*) FROM information_schema.table_constraints WHERE table_name = 'cast_assignments' AND constraint_name = 'cast_showtime_belongs_to_event';")
if [ "$cast_constraint" -eq "1" ]; then
    print_success "Cast showtime constraint exists"
else
    print_error "Cast showtime constraint missing"
    exit 1
fi

# Check helper functions
cast_functions=$(run_sql "SELECT COUNT(*) FROM pg_proc WHERE proname IN ('get_showtime_cast', 'count_showtime_cast', 'is_showtime_cast_complete');")
if [ "$cast_functions" -eq "3" ]; then
    print_success "Cast helper functions exist"
else
    print_warning "Some cast helper functions missing (expected: 3, found: $cast_functions)"
fi

# Check cast summary view
cast_view=$(run_sql "SELECT COUNT(*) FROM information_schema.views WHERE table_name = 'showtime_cast_summary';")
if [ "$cast_view" -eq "1" ]; then
    print_success "showtime_cast_summary view exists"
else
    print_error "showtime_cast_summary view missing"
    exit 1
fi

echo ""

# =====================================================================================
# CHECK 5: Helper functions work correctly
# =====================================================================================

echo "Testing helper functions..."

# Test count_showtimes function
test_result=$(run_sql "SELECT public.count_showtimes(gen_random_uuid());")
if [ "$test_result" -eq "0" ]; then
    print_success "count_showtimes() function works"
else
    print_warning "count_showtimes() returned unexpected result: $test_result"
fi

# Test has_multiple_showtimes function
test_result=$(run_sql "SELECT public.has_multiple_showtimes(gen_random_uuid());")
if [ "$test_result" = "f" ]; then
    print_success "has_multiple_showtimes() function works"
else
    print_warning "has_multiple_showtimes() returned unexpected result: $test_result"
fi

echo ""

# =====================================================================================
# CHECK 6: Views return data (or empty sets)
# =====================================================================================

echo "Testing views..."

# Test events_with_showtime_summary view
view_result=$(run_sql "SELECT COUNT(*) FROM events_with_showtime_summary LIMIT 1;" 2>&1)
if [ $? -eq 0 ]; then
    print_success "events_with_showtime_summary view queryable"
else
    print_error "events_with_showtime_summary view has errors"
    exit 1
fi

# Test showtime_participation_summary view
view_result=$(run_sql "SELECT COUNT(*) FROM showtime_participation_summary LIMIT 1;" 2>&1)
if [ $? -eq 0 ]; then
    print_success "showtime_participation_summary view queryable"
else
    print_error "showtime_participation_summary view has errors"
    exit 1
fi

# Test showtime_cast_summary view
view_result=$(run_sql "SELECT COUNT(*) FROM showtime_cast_summary LIMIT 1;" 2>&1)
if [ $? -eq 0 ]; then
    print_success "showtime_cast_summary view queryable"
else
    print_error "showtime_cast_summary view has errors"
    exit 1
fi

echo ""

# =====================================================================================
# CHECK 7: Indexes exist
# =====================================================================================

echo "Checking indexes..."

# Count showtime indexes
showtime_indexes=$(run_sql "SELECT COUNT(*) FROM pg_indexes WHERE tablename = 'event_showtimes';")
if [ "$showtime_indexes" -ge "7" ]; then
    print_success "event_showtimes indexes created (found: $showtime_indexes)"
else
    print_warning "Some event_showtimes indexes missing (expected: 7+, found: $showtime_indexes)"
fi

# Count participant showtime indexes
participant_indexes=$(run_sql "SELECT COUNT(*) FROM pg_indexes WHERE tablename = 'event_participants' AND indexname LIKE '%showtime%';")
if [ "$participant_indexes" -ge "3" ]; then
    print_success "Participant showtime indexes created (found: $participant_indexes)"
else
    print_warning "Some participant showtime indexes missing (expected: 3+, found: $participant_indexes)"
fi

# Count cast showtime indexes
cast_indexes=$(run_sql "SELECT COUNT(*) FROM pg_indexes WHERE tablename = 'cast_assignments' AND indexname LIKE '%showtime%';")
if [ "$cast_indexes" -ge "4" ]; then
    print_success "Cast showtime indexes created (found: $cast_indexes)"
else
    print_warning "Some cast showtime indexes missing (expected: 4+, found: $cast_indexes)"
fi

echo ""

# =====================================================================================
# CHECK 8: Backward compatibility
# =====================================================================================

echo "Checking backward compatibility..."

# Verify showtime_id is nullable (not required yet)
nullable_check=$(run_sql "SELECT is_nullable FROM information_schema.columns WHERE table_name = 'event_participants' AND column_name = 'showtime_id';")
if [ "$nullable_check" = "YES" ]; then
    print_success "event_participants.showtime_id is nullable (backward compatible)"
else
    print_error "event_participants.showtime_id is NOT NULL (breaking change!)"
    exit 1
fi

nullable_check=$(run_sql "SELECT is_nullable FROM information_schema.columns WHERE table_name = 'cast_assignments' AND column_name = 'showtime_id';")
if [ "$nullable_check" = "YES" ]; then
    print_success "cast_assignments.showtime_id is nullable (backward compatible)"
else
    print_error "cast_assignments.showtime_id is NOT NULL (breaking change!)"
    exit 1
fi

# Verify old queries still work (events without showtimes)
event_query=$(run_sql "SELECT COUNT(*) FROM events;" 2>&1)
if [ $? -eq 0 ]; then
    print_success "Events table still queryable (backward compatible)"
else
    print_error "Events table query failed (breaking change!)"
    exit 1
fi

echo ""

# =====================================================================================
# CHECK 9: Data integrity
# =====================================================================================

echo "Checking data integrity..."

# Check for orphaned showtime references in participants
orphaned_participants=$(run_sql "SELECT COUNT(*) FROM event_participants ep WHERE ep.showtime_id IS NOT NULL AND NOT EXISTS (SELECT 1 FROM event_showtimes st WHERE st.id = ep.showtime_id);")
if [ "$orphaned_participants" -eq "0" ]; then
    print_success "No orphaned showtime references in participants"
else
    print_error "$orphaned_participants participants have orphaned showtime references"
    exit 1
fi

# Check for orphaned showtime references in cast
orphaned_casts=$(run_sql "SELECT COUNT(*) FROM cast_assignments ca WHERE ca.showtime_id IS NOT NULL AND NOT EXISTS (SELECT 1 FROM event_showtimes st WHERE st.id = ca.showtime_id);")
if [ "$orphaned_casts" -eq "0" ]; then
    print_success "No orphaned showtime references in cast assignments"
else
    print_error "$orphaned_casts cast assignments have orphaned showtime references"
    exit 1
fi

echo ""

# =====================================================================================
# SUMMARY
# =====================================================================================

echo "=========================================="
echo "Validation Summary"
echo "=========================================="
print_success "Phase 1 migrations validated successfully!"
echo ""
echo "Phase 1 Features Ready:"
echo "  ✅ event_showtimes table with timezone support"
echo "  ✅ Participant registration per showtime"
echo "  ✅ Cast assignments per showtime"
echo "  ✅ Helper functions for showtime queries"
echo "  ✅ Views for efficient data display"
echo "  ✅ RLS policies configured"
echo "  ✅ Backward compatible (no breaking changes)"
echo ""
echo "Next steps:"
echo "  1. Test showtime creation in admin UI"
echo "  2. Test participant registration for showtimes"
echo "  3. Test cast assignment to showtimes"
echo "  4. Monitor performance with new indexes"
echo "  5. Begin Phase 2 user adoption period"
echo ""
