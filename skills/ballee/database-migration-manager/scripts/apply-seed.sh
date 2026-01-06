#!/bin/bash

# Seed super-admin user after database reset
# Usage: ./scripts/apply-seed.sh

echo "🌱 Applying seed data..."

PGPASSWORD=postgres psql -h 127.0.0.1 -p 54322 -U postgres -d postgres -f supabase/seed.sql

echo "✅ Seed data applied"
echo ""
echo "Login credentials:"
echo "  Email: antoine@ballee.co"
echo "  Password: password"
