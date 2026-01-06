#!/bin/bash

# Database Schema Contract Validator
# Purpose: Verify database functions match actual table schemas
# Usage: ./scripts/validate-db-contracts.sh
# Exit code: 0 if all contracts valid, 1 if any mismatches found

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🔍 Database Schema Contract Validator${NC}"
echo "=========================================="
echo ""

# Check if Supabase is running
if ! command -v pg_isready >/dev/null 2>&1 || ! pg_isready -h 127.0.0.1 -p 54322 -U postgres > /dev/null 2>&1; then
    echo -e "${RED}❌ Supabase is not running${NC}"
    echo -e "${YELLOW}Run: pnpm supabase:start${NC}"
    exit 1
fi

export PGPASSWORD=postgres

# Track validation results
TOTAL_CHECKS=0
PASSED_CHECKS=0
FAILED_CHECKS=0

# Function to validate INSERT/UPDATE columns against table schema
validate_function_columns() {
    local function_name=$1
    local table_name=$2
    local columns=$3  # Comma-separated list

    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))

    echo -e "${BLUE}Checking:${NC} $function_name → $table_name"

    # Convert comma-separated columns to array
    IFS=',' read -ra COLS <<< "$columns"

    # Get actual table columns
    actual_columns=$(psql -h 127.0.0.1 -p 54322 -U postgres -d postgres -t -c "
        SELECT column_name
        FROM information_schema.columns
        WHERE table_schema = 'public'
          AND table_name = '$table_name'
        ORDER BY ordinal_position;
    " 2>/dev/null | tr -d ' ' | grep -v '^$')

    if [ -z "$actual_columns" ]; then
        echo -e "  ${RED}❌ Table '$table_name' not found${NC}"
        FAILED_CHECKS=$((FAILED_CHECKS + 1))
        return 1
    fi

    # Check each column
    missing_columns=()
    for col in "${COLS[@]}"; do
        # Trim whitespace
        col=$(echo "$col" | tr -d ' ')

        # Check if column exists in table
        if ! echo "$actual_columns" | grep -q "^${col}$"; then
            missing_columns+=("$col")
        fi
    done

    if [ ${#missing_columns[@]} -eq 0 ]; then
        echo -e "  ${GREEN}✅ All columns exist${NC}"
        PASSED_CHECKS=$((PASSED_CHECKS + 1))
        return 0
    else
        echo -e "  ${RED}❌ Missing columns:${NC} ${missing_columns[*]}"
        FAILED_CHECKS=$((FAILED_CHECKS + 1))
        return 1
    fi
}

echo -e "${BLUE}Validating atomic_profile_update function...${NC}"
echo ""

# Validate profiles table
validate_function_columns \
    "atomic_profile_update" \
    "profiles" \
    "first_name,last_name,date_of_birth,phone_number,country_of_residence,city,street_address,apartment,state_province,postal_code,emergency_contact_name,emergency_contact_phone,emergency_contact_relationship,id_passport_number,tax_id,tax_number,notes"

# Validate professional_profiles table
validate_function_columns \
    "atomic_profile_update" \
    "professional_profiles" \
    "user_id,profile_type,bio,instagram_handle,tiktok_handle,dance_styles"

# Validate dancer_profiles table
validate_function_columns \
    "atomic_profile_update" \
    "dancer_profiles" \
    "height_cm,weight_kg,bust_cm,waist_cm,hips_cm,clothing_size,shoe_size,pointe_shoe_brand,pointe_shoe_size,geographic_availability"

# Validate identity_verifications table
validate_function_columns \
    "atomic_profile_update" \
    "identity_verifications" \
    "user_id,document_type,document_number,country_code,front_image_url,back_image_url,selfie_image_url,verification_status"

echo ""
echo "=========================================="
echo -e "${BLUE}Summary:${NC}"
echo -e "  ${GREEN}Passed: $PASSED_CHECKS${NC}"
echo -e "  ${RED}Failed: $FAILED_CHECKS${NC}"
echo -e "  Total:  $TOTAL_CHECKS"
echo ""

if [ $FAILED_CHECKS -gt 0 ]; then
    echo -e "${RED}❌ Schema contract validation failed${NC}"
    echo ""
    echo -e "${BLUE}To fix:${NC}"
    echo -e "  1. Check migration files in supabase/migrations/"
    echo -e "  2. Verify function INSERT/UPDATE statements match table schemas"
    echo -e "  3. Use: \\d table_name in psql to see actual columns"
    exit 1
fi

echo -e "${GREEN}✅ All schema contracts are valid${NC}"
exit 0
