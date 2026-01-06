#!/bin/bash

# Validate that database functions reference only columns that exist in tables
# This catches schema mismatches before deployment

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}╔═══════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║     Validate Database Function Schema References         ║${NC}"
echo -e "${BLUE}╚═══════════════════════════════════════════════════════════╝${NC}"
echo ""

# Check if Supabase is running
if ! pg_isready -h 127.0.0.1 -p 54322 -U postgres >/dev/null 2>&1; then
    echo -e "${RED}❌ Local Supabase database not running${NC}"
    echo "Start it with: pnpm supabase:web:start"
    exit 1
fi

# Function to check if a function's column references match table schema
validate_function_columns() {
    local function_name=$1
    local table_name=$2
    local expected_columns=$3 # Comma-separated list

    echo -e "${BLUE}🔍 Validating ${function_name} → ${table_name}${NC}"

    # Get actual columns from table
    local actual_columns=$(PGPASSWORD=postgres psql -h 127.0.0.1 -p 54322 -U postgres -d postgres -t -c "
        SELECT column_name
        FROM information_schema.columns
        WHERE table_schema = 'public'
        AND table_name = '${table_name}'
        ORDER BY column_name;
    " | tr -d ' ' | grep -v '^$')

    # Convert to array
    IFS=',' read -ra expected_array <<< "$expected_columns"

    local missing_columns=()
    local all_valid=true

    for col in "${expected_array[@]}"; do
        col=$(echo "$col" | xargs) # trim whitespace
        if ! echo "$actual_columns" | grep -q "^${col}$"; then
            missing_columns+=("$col")
            all_valid=false
        fi
    done

    if [ "$all_valid" = true ]; then
        echo -e "${GREEN}✅ All columns exist in ${table_name}${NC}"
        return 0
    else
        echo -e "${RED}❌ Missing columns in ${table_name}:${NC}"
        for col in "${missing_columns[@]}"; do
            echo -e "${RED}   - ${col}${NC}"
        done
        return 1
    fi
}

# Validate atomic_profile_update function
echo -e "${YELLOW}Validating atomic_profile_update function...${NC}"
echo ""

validation_passed=true

# Validate profiles table columns
if ! validate_function_columns \
    "atomic_profile_update" \
    "profiles" \
    "id,first_name,last_name,date_of_birth,phone_number,street_address,apartment,city,state_province,postal_code,country_of_residence,emergency_contact_name,emergency_contact_phone,emergency_contact_relationship,id_passport_number,tax_id,tax_number,notes"; then
    validation_passed=false
fi

echo ""

# Validate professional_profiles table columns
if ! validate_function_columns \
    "atomic_profile_update" \
    "professional_profiles" \
    "user_id,profile_type,bio,years_of_experience,dance_styles,instagram_handle,tiktok_handle,portfolio_url,ballee_profile_slug,is_active,available_for_hire"; then
    validation_passed=false
fi

echo ""

# Validate dancer_profiles table columns
if ! validate_function_columns \
    "atomic_profile_update" \
    "dancer_profiles" \
    "id,height_cm,weight_kg,bust_cm,waist_cm,hips_cm,clothing_size,shoe_size,pointe_shoe_brand,pointe_shoe_size,geographic_availability"; then
    validation_passed=false
fi

echo ""

# Validate identity_verifications table columns
if ! validate_function_columns \
    "atomic_profile_update" \
    "identity_verifications" \
    "user_id,verification_status"; then
    validation_passed=false
fi

echo ""
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"

if [ "$validation_passed" = true ]; then
    echo -e "${GREEN}✅ All function schema validations passed!${NC}"
    exit 0
else
    echo -e "${RED}❌ Schema validation failed${NC}"
    echo ""
    echo "Action required:"
    echo "1. Check that all migrations have been applied: pnpm supabase:web:reset"
    echo "2. Verify migrations add all columns referenced in functions"
    echo "3. Update functions to match current table schema"
    exit 1
fi
