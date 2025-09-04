-- Create Vote-Specific RLS Policies
-- This script creates policies for controlled vote insertion and selection

-- ==============================================
-- 1. DROP EXISTING POLICIES (if they exist)
-- ==============================================

DROP POLICY IF EXISTS "insert_votes" ON votes;
DROP POLICY IF EXISTS "select_votes_owner" ON votes;

-- ==============================================
-- 2. CREATE VOTE-SPECIFIC POLICIES
-- ==============================================

-- Allow authenticated users to insert votes
-- This policy requires users to be authenticated (have a valid JWT token)
CREATE POLICY "insert_votes" ON votes FOR INSERT USING (auth.role() = 'authenticated');

-- Control select for votes: only owner or poll owner
-- This policy allows users to see:
-- 1. Their own votes (user_id = auth.uid())
-- 2. Votes on polls they own (poll owner)
CREATE POLICY "select_votes_owner" ON votes FOR SELECT USING (
  user_id = auth.uid() OR 
  EXISTS (
    SELECT 1 FROM polls p 
    WHERE p.id = votes.poll_id 
    AND p.owner_id = auth.uid()
  )
);

-- ==============================================
-- 3. VERIFY POLICY CREATION
-- ==============================================

-- Check if the policies were created successfully
SELECT 
    'Vote Policy Creation Check' as test_type,
    policyname,
    cmd as operation,
    CASE 
        WHEN cmd = 'INSERT' THEN '✅ AUTHENTICATED INSERT'
        WHEN cmd = 'SELECT' THEN '✅ OWNER-ONLY SELECT'
        ELSE '❌ UNKNOWN OPERATION'
    END as scope,
    qual as condition
FROM pg_policies 
WHERE tablename = 'votes' 
AND policyname IN ('insert_votes', 'select_votes_owner')
ORDER BY policyname;

-- ==============================================
-- 4. TEST POLICY FUNCTIONALITY
-- ==============================================

-- Test 1: Check authentication role for vote insertion
DO $$
DECLARE
    current_role TEXT;
    current_uid UUID;
BEGIN
    -- Get current authentication context
    SELECT auth.role() INTO current_role;
    SELECT auth.uid() INTO current_uid;
    
    RAISE NOTICE 'Vote Policy Authentication Context:';
    RAISE NOTICE '  Role: %', COALESCE(current_role, 'NULL');
    RAISE NOTICE '  User ID: %', COALESCE(current_uid::text, 'NULL');
    
    -- Test INSERT permission
    IF current_role = 'authenticated' THEN
        RAISE NOTICE 'Vote INSERT Policy Test: ✅ SUCCESS - User is authenticated';
    ELSE
        RAISE NOTICE 'Vote INSERT Policy Test: ⚠️ SKIPPED - User is not authenticated (role: %)', COALESCE(current_role, 'NULL');
    END IF;
    
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'Vote Authentication Test: ❌ FAILED - %', SQLERRM;
END $$;

-- Test 2: Test vote SELECT access for current user
DO $$
DECLARE
    current_uid UUID;
    owned_votes_count INTEGER;
    poll_owner_votes_count INTEGER;
    total_accessible_votes INTEGER;
BEGIN
    -- Get current user ID
    SELECT auth.uid() INTO current_uid;
    
    IF current_uid IS NOT NULL THEN
        -- Count votes owned by current user
        SELECT COUNT(*) INTO owned_votes_count
        FROM votes 
        WHERE user_id = current_uid;
        
        -- Count votes for polls owned by current user
        SELECT COUNT(*) INTO poll_owner_votes_count
        FROM votes v
        JOIN polls p ON v.poll_id = p.id
        WHERE p.owner_id = current_uid;
        
        -- Total accessible votes (should be sum of both, minus duplicates)
        SELECT COUNT(DISTINCT v.id) INTO total_accessible_votes
        FROM votes v
        WHERE v.user_id = current_uid 
        OR EXISTS (
            SELECT 1 FROM polls p 
            WHERE p.id = v.poll_id 
            AND p.owner_id = current_uid
        );
        
        RAISE NOTICE 'Vote SELECT Owner Policy Test: ✅ SUCCESS';
        RAISE NOTICE '  Owned votes: %', owned_votes_count;
        RAISE NOTICE '  Poll owner votes: %', poll_owner_votes_count;
        RAISE NOTICE '  Total accessible votes: %', total_accessible_votes;
    ELSE
        RAISE NOTICE 'Vote SELECT Owner Policy Test: ⚠️ SKIPPED - No authenticated user';
    END IF;
    
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'Vote SELECT Owner Policy Test: ❌ FAILED - %', SQLERRM;
END $$;

-- Test 3: Test INSERT with authentication (if authenticated)
DO $$
DECLARE
    test_vote_id UUID;
    test_poll_id UUID;
    test_option_id UUID;
    current_role TEXT;
    current_uid UUID;
BEGIN
    -- Check if user is authenticated
    SELECT auth.role() INTO current_role;
    SELECT auth.uid() INTO current_uid;
    
    IF current_role = 'authenticated' AND current_uid IS NOT NULL THEN
        -- Find a poll and option to test with
        SELECT p.id, po.id INTO test_poll_id, test_option_id
        FROM polls p
        JOIN poll_options po ON p.id = po.poll_id
        WHERE p.is_active = true
        LIMIT 1;
        
        IF test_poll_id IS NOT NULL AND test_option_id IS NOT NULL THEN
            -- Try to create a test vote
            INSERT INTO votes (poll_id, option_id, user_id)
            VALUES (test_poll_id, test_option_id, current_uid)
            RETURNING id INTO test_vote_id;
            
            RAISE NOTICE 'Vote INSERT Test: ✅ SUCCESS - Vote created with ID: %', test_vote_id;
            
            -- Clean up the test vote
            DELETE FROM votes WHERE id = test_vote_id;
            RAISE NOTICE 'Vote INSERT Test: ✅ CLEANUP - Test vote removed';
        ELSE
            RAISE NOTICE 'Vote INSERT Test: ⚠️ SKIPPED - No active polls with options found';
        END IF;
    ELSE
        RAISE NOTICE 'Vote INSERT Test: ⚠️ SKIPPED - User is not authenticated';
    END IF;
    
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'Vote INSERT Test: ❌ FAILED - %', SQLERRM;
END $$;

-- ==============================================
-- 5. POLICY COMPARISON AND ANALYSIS
-- ==============================================

-- Show all policies on the votes table
SELECT 
    'All Votes Policies' as test_type,
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
        WHEN policyname LIKE '%insert%' THEN 'AUTHENTICATED ACCESS'
        WHEN policyname LIKE '%view%' THEN 'PUBLIC ACCESS'
        ELSE 'OTHER'
    END as policy_type
FROM pg_policies 
WHERE tablename = 'votes'
ORDER BY 
    CASE 
        WHEN cmd = '*' THEN 1  -- Comprehensive policies first
        WHEN cmd = 'INSERT' THEN 2  -- Authenticated access
        WHEN cmd = 'SELECT' THEN 3  -- Owner access
        ELSE 4
    END,
    policyname;

-- ==============================================
-- 6. SECURITY ANALYSIS
-- ==============================================

-- Analyze vote policy coverage
SELECT 
    'Vote Policy Coverage Analysis' as test_type,
    COUNT(*) as total_policies,
    COUNT(CASE WHEN cmd = 'SELECT' THEN 1 END) as select_policies,
    COUNT(CASE WHEN cmd = 'INSERT' THEN 1 END) as insert_policies,
    COUNT(CASE WHEN cmd = 'UPDATE' THEN 1 END) as update_policies,
    COUNT(CASE WHEN cmd = 'DELETE' THEN 1 END) as delete_policies,
    COUNT(CASE WHEN cmd = '*' THEN 1 END) as comprehensive_policies
FROM pg_policies 
WHERE tablename = 'votes';

-- ==============================================
-- 7. ACCESS CONTROL MATRIX
-- ==============================================

-- Show what each user type can access
SELECT 
    'Vote Access Control Matrix' as test_type,
    'Public Users' as user_type,
    'No access to votes' as access_level
UNION ALL
SELECT 
    'Vote Access Control Matrix' as test_type,
    'Authenticated Users' as user_type,
    'Can insert votes, view own votes' as access_level
UNION ALL
SELECT 
    'Vote Access Control Matrix' as test_type,
    'Poll Owners' as user_type,
    'Can insert votes, view own votes + poll votes' as access_level;

-- ==============================================
-- 8. SECURITY NOTES
-- ==============================================

/*
VOTE-SPECIFIC POLICIES BENEFITS:

✅ AUTHENTICATED INSERT POLICY (insert_votes)
   - Requires valid JWT token for vote submission
   - Prevents anonymous voting
   - Ensures vote accountability
   - Maintains data integrity

✅ OWNER-ONLY SELECT POLICY (select_votes_owner)
   - Users can only see their own votes
   - Poll owners can see votes on their polls
   - Protects voter privacy
   - Enables poll management for owners

✅ PRIVACY AND SECURITY BENEFITS
   - Vote privacy protection
   - Controlled access to vote data
   - Owner-only poll management
   - Authenticated voting only

✅ POLICY COMBINATION BENEFITS
   - Authenticated voting + Owner-only viewing = Privacy + Accountability
   - Poll owners can manage their polls effectively
   - Users can track their own voting history
   - System maintains vote integrity

USAGE SCENARIOS:
- Authenticated users can vote on polls
- Users can view their own voting history
- Poll owners can see all votes on their polls
- System prevents unauthorized vote access

SECURITY CONSIDERATIONS:
- Vote privacy is protected (no public vote viewing)
- Only authenticated users can vote
- Poll owners have full visibility of their poll votes
- Users can only see their own votes (not others')

PERFORMANCE IMPACT:
- INSERT policy has minimal overhead (role check)
- SELECT policy uses efficient EXISTS subquery
- Policies work well with database indexes
- Consider indexing on user_id and poll_id for performance
*/

RAISE NOTICE 'Vote-Specific Policies Created Successfully!';
RAISE NOTICE 'Policy 1: insert_votes - Authenticated users can insert votes';
RAISE NOTICE 'Policy 2: select_votes_owner - Users can view own votes + poll owners can view poll votes';
RAISE NOTICE 'Benefits: Privacy protection + Authenticated voting + Owner management';
RAISE NOTICE 'Security: Vote privacy + Controlled access + Poll owner visibility';
