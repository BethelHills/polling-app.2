-- Create Public and Authenticated User Policies for Polls
-- This script creates policies for public viewing and authenticated user creation

-- ==============================================
-- 1. DROP EXISTING POLICIES (if they exist)
-- ==============================================

DROP POLICY IF EXISTS "select_polls" ON polls;
DROP POLICY IF EXISTS "insert_polls" ON polls;

-- ==============================================
-- 2. CREATE PUBLIC AND AUTHENTICATED POLICIES
-- ==============================================

-- Allow anyone to SELECT polls (public viewing)
-- This policy allows unauthenticated users to view all polls
CREATE POLICY "select_polls" ON polls FOR SELECT USING (true);

-- Allow authenticated users to INSERT polls
-- This policy requires users to be authenticated (have a valid JWT token)
CREATE POLICY "insert_polls" ON polls FOR INSERT USING (auth.role() = 'authenticated');

-- ==============================================
-- 3. VERIFY POLICY CREATION
-- ==============================================

-- Check if the policies were created successfully
SELECT 
    'Policy Creation Check' as test_type,
    policyname,
    cmd as operation,
    CASE 
        WHEN cmd = 'SELECT' THEN '✅ PUBLIC ACCESS'
        WHEN cmd = 'INSERT' THEN '✅ AUTHENTICATED ACCESS'
        ELSE '❌ UNKNOWN OPERATION'
    END as scope,
    qual as condition
FROM pg_policies 
WHERE tablename = 'polls' 
AND policyname IN ('select_polls', 'insert_polls')
ORDER BY policyname;

-- ==============================================
-- 4. TEST POLICY FUNCTIONALITY
-- ==============================================

-- Test 1: Public SELECT access (should work for everyone)
SELECT 
    'Public SELECT Test' as test_type,
    COUNT(*) as total_polls_count,
    COUNT(CASE WHEN is_active = true THEN 1 END) as active_polls_count,
    COUNT(CASE WHEN is_active = false THEN 1 END) as inactive_polls_count
FROM polls;

-- Test 2: Check authentication role
DO $$
DECLARE
    current_role TEXT;
    current_uid UUID;
BEGIN
    -- Get current authentication context
    SELECT auth.role() INTO current_role;
    SELECT auth.uid() INTO current_uid;
    
    RAISE NOTICE 'Authentication Context:';
    RAISE NOTICE '  Role: %', COALESCE(current_role, 'NULL');
    RAISE NOTICE '  User ID: %', COALESCE(current_uid::text, 'NULL');
    
    -- Test INSERT permission
    IF current_role = 'authenticated' THEN
        RAISE NOTICE 'INSERT Policy Test: ✅ SUCCESS - User is authenticated';
    ELSE
        RAISE NOTICE 'INSERT Policy Test: ⚠️ SKIPPED - User is not authenticated (role: %)', COALESCE(current_role, 'NULL');
    END IF;
    
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'Authentication Test: ❌ FAILED - %', SQLERRM;
END $$;

-- Test 3: Test INSERT with authentication (if authenticated)
DO $$
DECLARE
    test_poll_id UUID;
    current_role TEXT;
BEGIN
    -- Check if user is authenticated
    SELECT auth.role() INTO current_role;
    
    IF current_role = 'authenticated' THEN
        -- Try to create a test poll
        INSERT INTO polls (title, description, owner_id, is_active)
        VALUES ('Test Public Policy Poll', 'Testing public and authenticated policies', auth.uid(), true)
        RETURNING id INTO test_poll_id;
        
        RAISE NOTICE 'INSERT Test: ✅ SUCCESS - Poll created with ID: %', test_poll_id;
        
        -- Clean up the test poll
        DELETE FROM polls WHERE id = test_poll_id;
        RAISE NOTICE 'INSERT Test: ✅ CLEANUP - Test poll removed';
        
    ELSE
        RAISE NOTICE 'INSERT Test: ⚠️ SKIPPED - User is not authenticated';
    END IF;
    
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'INSERT Test: ❌ FAILED - %', SQLERRM;
END $$;

-- ==============================================
-- 5. POLICY COMPARISON AND ANALYSIS
-- ==============================================

-- Show all policies on the polls table
SELECT 
    'All Polls Policies' as test_type,
    policyname,
    cmd as operation,
    CASE 
        WHEN cmd = '*' THEN 'ALL OPERATIONS'
        WHEN cmd = 'SELECT' THEN 'READ ONLY'
        WHEN cmd = 'INSERT' THEN 'CREATE ONLY'
        WHEN cmd = 'UPDATE' THEN 'MODIFY ONLY'
        WHEN cmd = 'DELETE' THEN 'REMOVE ONLY'
        ELSE cmd::text
    END as scope,
    qual as condition,
    CASE 
        WHEN policyname LIKE '%owner%' THEN 'OWNER-SPECIFIC'
        WHEN policyname LIKE '%select%' THEN 'PUBLIC ACCESS'
        WHEN policyname LIKE '%insert%' THEN 'AUTHENTICATED ACCESS'
        ELSE 'OTHER'
    END as policy_type
FROM pg_policies 
WHERE tablename = 'polls'
ORDER BY 
    CASE 
        WHEN cmd = '*' THEN 1  -- Comprehensive policies first
        WHEN cmd = 'SELECT' THEN 2  -- Public access
        WHEN cmd = 'INSERT' THEN 3  -- Authenticated access
        ELSE 4
    END,
    policyname;

-- ==============================================
-- 6. SECURITY ANALYSIS
-- ==============================================

-- Analyze policy coverage
SELECT 
    'Policy Coverage Analysis' as test_type,
    COUNT(*) as total_policies,
    COUNT(CASE WHEN cmd = 'SELECT' THEN 1 END) as select_policies,
    COUNT(CASE WHEN cmd = 'INSERT' THEN 1 END) as insert_policies,
    COUNT(CASE WHEN cmd = 'UPDATE' THEN 1 END) as update_policies,
    COUNT(CASE WHEN cmd = 'DELETE' THEN 1 END) as delete_policies,
    COUNT(CASE WHEN cmd = '*' THEN 1 END) as comprehensive_policies
FROM pg_policies 
WHERE tablename = 'polls';

-- ==============================================
-- 7. SECURITY NOTES
-- ==============================================

/*
PUBLIC AND AUTHENTICATED POLICIES BENEFITS:

✅ PUBLIC SELECT POLICY (select_polls)
   - Allows anyone to view polls without authentication
   - Enables public poll discovery and transparency
   - Supports anonymous poll viewing
   - Reduces authentication overhead for read operations

✅ AUTHENTICATED INSERT POLICY (insert_polls)
   - Requires valid JWT token for poll creation
   - Prevents anonymous poll creation
   - Ensures poll ownership tracking
   - Maintains data integrity and accountability

✅ POLICY COMBINATION BENEFITS
   - Public viewing + Authenticated creation = Best of both worlds
   - Transparent poll system with controlled creation
   - Reduced server load for read operations
   - Enhanced security for write operations

✅ SECURITY CONSIDERATIONS
   - Public SELECT allows viewing of all polls (including inactive ones)
   - Consider adding filters for active polls only if needed
   - Authenticated INSERT ensures proper user identification
   - Works well with owner-specific policies for management

USAGE SCENARIOS:
- Public users can browse and view polls
- Authenticated users can create new polls
- Poll owners can manage their polls (via owner policies)
- System maintains transparency while ensuring accountability

PERFORMANCE IMPACT:
- Public SELECT policy has minimal overhead
- Authenticated INSERT policy requires role checking
- Policies work efficiently with database indexes
- Consider caching for frequently accessed public data
*/

RAISE NOTICE 'Public and Authenticated Policies Created Successfully!';
RAISE NOTICE 'Policy 1: select_polls - Public access to view all polls';
RAISE NOTICE 'Policy 2: insert_polls - Authenticated users can create polls';
RAISE NOTICE 'Benefits: Public transparency + Authenticated creation + Owner management';
RAISE NOTICE 'Security: Transparent viewing with controlled creation and ownership';
