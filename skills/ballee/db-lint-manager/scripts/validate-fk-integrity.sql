-- FK Integrity Validator
-- Run against local, staging, or production to find FK issues

-- ============================================================================
-- 1. LIST ALL FOREIGN KEY CONSTRAINTS
-- ============================================================================
SELECT
    '=== ALL FOREIGN KEY CONSTRAINTS ===' as section;

SELECT
    tc.table_name as child_table,
    kcu.column_name as fk_column,
    ccu.table_name as parent_table,
    ccu.column_name as parent_column,
    tc.constraint_name
FROM information_schema.table_constraints tc
JOIN information_schema.key_column_usage kcu
    ON tc.constraint_name = kcu.constraint_name
    AND tc.table_schema = kcu.table_schema
JOIN information_schema.constraint_column_usage ccu
    ON ccu.constraint_name = tc.constraint_name
    AND ccu.table_schema = tc.table_schema
WHERE tc.constraint_type = 'FOREIGN KEY'
    AND tc.table_schema = 'public'
ORDER BY tc.table_name, kcu.column_name;

-- ============================================================================
-- 2. FIND COLUMNS THAT LOOK LIKE FKs BUT HAVE NO CONSTRAINT
-- ============================================================================
SELECT
    '=== POTENTIAL MISSING FK CONSTRAINTS ===' as section;

WITH fk_columns AS (
    SELECT
        kcu.table_name,
        kcu.column_name
    FROM information_schema.table_constraints tc
    JOIN information_schema.key_column_usage kcu
        ON tc.constraint_name = kcu.constraint_name
    WHERE tc.constraint_type = 'FOREIGN KEY'
        AND tc.table_schema = 'public'
),
id_columns AS (
    SELECT
        c.table_name,
        c.column_name,
        c.data_type
    FROM information_schema.columns c
    WHERE c.table_schema = 'public'
        AND (
            c.column_name LIKE '%_id'
            OR c.column_name LIKE '%_uuid'
        )
        AND c.column_name NOT IN ('id', 'external_id', 'meteor_id', 'airtable_id', 'stripe_id', 'tipalti_id')
        AND c.data_type IN ('uuid', 'bigint', 'integer', 'text')
)
SELECT
    ic.table_name,
    ic.column_name,
    ic.data_type,
    CASE
        WHEN ic.column_name LIKE 'profile_id%' THEN 'profiles'
        WHEN ic.column_name LIKE 'user_id%' THEN 'auth.users or profiles'
        WHEN ic.column_name LIKE 'account_id%' THEN 'accounts'
        WHEN ic.column_name LIKE 'event_id%' THEN 'events'
        WHEN ic.column_name LIKE 'client_id%' THEN 'clients'
        WHEN ic.column_name LIKE 'production_id%' THEN 'productions'
        WHEN ic.column_name LIKE 'venue_id%' THEN 'venues'
        WHEN ic.column_name LIKE 'invoice_id%' THEN 'invoices'
        ELSE 'UNKNOWN - investigate'
    END as likely_parent_table
FROM id_columns ic
LEFT JOIN fk_columns fk
    ON ic.table_name = fk.table_name
    AND ic.column_name = fk.column_name
WHERE fk.column_name IS NULL
ORDER BY ic.table_name, ic.column_name;

-- ============================================================================
-- 3. FIND ORPHAN RECORDS (Generic check for common relationships)
-- ============================================================================
SELECT
    '=== ORPHAN RECORD CHECK ===' as section;

-- Check events with invalid client_id
SELECT 'events with invalid client_id' as check_name, COUNT(*) as orphan_count
FROM events e
WHERE e.client_id IS NOT NULL
AND NOT EXISTS (SELECT 1 FROM clients c WHERE c.id = e.client_id);

-- Check productions with invalid client_id
SELECT 'productions with invalid client_id' as check_name, COUNT(*) as orphan_count
FROM productions p
WHERE p.client_id IS NOT NULL
AND NOT EXISTS (SELECT 1 FROM clients c WHERE c.id = p.client_id);

-- Check cast_assignments with invalid event_id
SELECT 'cast_assignments with invalid event_id' as check_name, COUNT(*) as orphan_count
FROM cast_assignments ca
WHERE NOT EXISTS (SELECT 1 FROM events e WHERE e.id = ca.event_id);

-- Check cast_assignments with invalid profile_id
SELECT 'cast_assignments with invalid profile_id' as check_name, COUNT(*) as orphan_count
FROM cast_assignments ca
WHERE NOT EXISTS (SELECT 1 FROM profiles p WHERE p.id = ca.profile_id);

-- Check invoices with invalid client_id
SELECT 'invoices with invalid client_id' as check_name, COUNT(*) as orphan_count
FROM invoices i
WHERE i.client_id IS NOT NULL
AND NOT EXISTS (SELECT 1 FROM clients c WHERE c.id = i.client_id);

-- Check hire_orders with invalid profile_id
SELECT 'hire_orders with invalid profile_id' as check_name, COUNT(*) as orphan_count
FROM hire_orders ho
WHERE NOT EXISTS (SELECT 1 FROM profiles p WHERE p.id = ho.profile_id);

-- Check reimbursement_requests with invalid profile_id
SELECT 'reimbursement_requests with invalid profile_id' as check_name, COUNT(*) as orphan_count
FROM reimbursement_requests rr
WHERE NOT EXISTS (SELECT 1 FROM profiles p WHERE p.id = rr.profile_id);

-- Check event_participants with invalid event_id
SELECT 'event_participants with invalid event_id' as check_name, COUNT(*) as orphan_count
FROM event_participants ep
WHERE NOT EXISTS (SELECT 1 FROM events e WHERE e.id = ep.event_id);

-- Check event_participants with invalid profile_id
SELECT 'event_participants with invalid profile_id' as check_name, COUNT(*) as orphan_count
FROM event_participants ep
WHERE NOT EXISTS (SELECT 1 FROM profiles p WHERE p.id = ep.profile_id);

-- Check profiles with invalid user_id (auth.users)
SELECT 'profiles with invalid user_id' as check_name, COUNT(*) as orphan_count
FROM profiles p
WHERE p.id IS NOT NULL
AND NOT EXISTS (SELECT 1 FROM auth.users u WHERE u.id = p.id);

-- ============================================================================
-- 4. CHECK POSTGREST RELATIONSHIP CONFIGURATION
-- ============================================================================
SELECT
    '=== POSTGREST RELATIONSHIP HINTS ===' as section;

-- Check for tables that might need relationship hints for nested queries
SELECT
    c.relname as table_name,
    CASE
        WHEN EXISTS (
            SELECT 1 FROM pg_constraint con
            WHERE con.conrelid = c.oid AND con.contype = 'f'
        ) THEN 'Has FK constraints'
        ELSE 'No FK constraints - may need hints for nested queries'
    END as fk_status,
    (
        SELECT COUNT(*) FROM pg_constraint con
        WHERE con.conrelid = c.oid AND con.contype = 'f'
    ) as fk_count
FROM pg_class c
JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE n.nspname = 'public'
AND c.relkind = 'r'
AND c.relname NOT LIKE 'pg_%'
AND c.relname NOT LIKE '_%;'
ORDER BY fk_count ASC, c.relname;

-- ============================================================================
-- 5. SUMMARY STATISTICS
-- ============================================================================
SELECT
    '=== SUMMARY ===' as section;

SELECT
    'Total tables' as metric,
    COUNT(*)::text as value
FROM information_schema.tables
WHERE table_schema = 'public' AND table_type = 'BASE TABLE'
UNION ALL
SELECT
    'Total FK constraints' as metric,
    COUNT(*)::text as value
FROM information_schema.table_constraints
WHERE constraint_type = 'FOREIGN KEY' AND table_schema = 'public'
UNION ALL
SELECT
    'Tables without any FK' as metric,
    COUNT(*)::text as value
FROM (
    SELECT t.table_name
    FROM information_schema.tables t
    WHERE t.table_schema = 'public' AND t.table_type = 'BASE TABLE'
    AND NOT EXISTS (
        SELECT 1 FROM information_schema.table_constraints tc
        WHERE tc.table_name = t.table_name
        AND tc.constraint_type = 'FOREIGN KEY'
        AND tc.table_schema = 'public'
    )
) as tables_without_fk;
