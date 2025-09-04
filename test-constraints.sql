-- Test Script: Verify Database Constraints Work Correctly
-- Run this after applying the comprehensive migration

-- ==============================================
-- 1. TEST UNIQUE VOTE CONSTRAINT
-- ==============================================
DO $$
DECLARE
    test_poll_id UUID;
    test_user_id UUID;
    test_option_id UUID;
BEGIN
    RAISE NOTICE 'Testing unique vote constraint...';
    
    -- Create test data (you'll need to replace with actual IDs)
    -- test_poll_id := 'your-poll-uuid-here';
    -- test_user_id := 'your-user-uuid-here';
    -- test_option_id := 'your-option-uuid-here';
    
    -- This test will fail if you don't have actual UUIDs
    -- Uncomment and modify the following lines with real data:
    
    /*
    -- First vote should succeed
    INSERT INTO votes (poll_id, user_id, option_id) 
    VALUES (test_poll_id, test_user_id, test_option_id);
    RAISE NOTICE 'First vote inserted successfully';
    
    -- Second vote should fail
    BEGIN
        INSERT INTO votes (poll_id, user_id, option_id) 
        VALUES (test_poll_id, test_user_id, test_option_id);
        RAISE NOTICE 'ERROR: Second vote was allowed (constraint failed!)';
    EXCEPTION
        WHEN unique_violation THEN
            RAISE NOTICE 'SUCCESS: Second vote correctly rejected';
    END;
    */
    
    RAISE NOTICE 'Unique vote constraint test completed (modify with real UUIDs to test)';
END $$;

-- ==============================================
-- 2. TEST DATA VALIDATION CONSTRAINTS
-- ==============================================

-- Test poll title constraints
DO $$
BEGIN
    RAISE NOTICE 'Testing poll title constraints...';
    
    -- Test empty title (should fail)
    BEGIN
        INSERT INTO polls (title, owner_id) VALUES ('', 'test-user-id');
        RAISE NOTICE 'ERROR: Empty title was allowed';
    EXCEPTION
        WHEN check_violation THEN
            RAISE NOTICE 'SUCCESS: Empty title correctly rejected';
    END;
    
    -- Test title too short (should fail)
    BEGIN
        INSERT INTO polls (title, owner_id) VALUES ('ab', 'test-user-id');
        RAISE NOTICE 'ERROR: Short title was allowed';
    EXCEPTION
        WHEN check_violation THEN
            RAISE NOTICE 'SUCCESS: Short title correctly rejected';
    END;
    
    -- Test title too long (should fail)
    BEGIN
        INSERT INTO polls (title, owner_id) VALUES (repeat('a', 201), 'test-user-id');
        RAISE NOTICE 'ERROR: Long title was allowed';
    EXCEPTION
        WHEN check_violation THEN
            RAISE NOTICE 'SUCCESS: Long title correctly rejected';
    END;
    
    RAISE NOTICE 'Poll title constraint tests completed';
END $$;

-- Test poll options constraints
DO $$
BEGIN
    RAISE NOTICE 'Testing poll options constraints...';
    
    -- Test empty option text (should fail)
    BEGIN
        INSERT INTO poll_options (poll_id, text, order_index) 
        VALUES ('test-poll-id', '', 0);
        RAISE NOTICE 'ERROR: Empty option text was allowed';
    EXCEPTION
        WHEN check_violation THEN
            RAISE NOTICE 'SUCCESS: Empty option text correctly rejected';
    END;
    
    -- Test negative vote count (should fail)
    BEGIN
        INSERT INTO poll_options (poll_id, text, votes, order_index) 
        VALUES ('test-poll-id', 'Test Option', -1, 0);
        RAISE NOTICE 'ERROR: Negative vote count was allowed';
    EXCEPTION
        WHEN check_violation THEN
            RAISE NOTICE 'SUCCESS: Negative vote count correctly rejected';
    END;
    
    RAISE NOTICE 'Poll options constraint tests completed';
END $$;

-- ==============================================
-- 3. VERIFY CONSTRAINTS EXIST
-- ==============================================

-- Check all constraints are in place
SELECT 
    'CONSTRAINT CHECK' as test_type,
    conname as constraint_name,
    contype as constraint_type,
    CASE 
        WHEN contype = 'u' THEN 'UNIQUE'
        WHEN contype = 'c' THEN 'CHECK'
        WHEN contype = 'f' THEN 'FOREIGN KEY'
        WHEN contype = 'p' THEN 'PRIMARY KEY'
        ELSE contype::text
    END as constraint_type_name
FROM pg_constraint 
WHERE conname IN (
    'unique_user_poll_vote',
    'polls_title_not_empty',
    'polls_title_length',
    'polls_description_length',
    'poll_options_text_not_empty',
    'poll_options_text_length',
    'poll_options_votes_non_negative',
    'poll_options_order_non_negative'
)
ORDER BY conname;

-- ==============================================
-- 4. VERIFY INDEXES EXIST
-- ==============================================

SELECT 
    'INDEX CHECK' as test_type,
    indexname,
    tablename,
    CASE 
        WHEN indexdef LIKE '%UNIQUE%' THEN 'UNIQUE INDEX'
        ELSE 'INDEX'
    END as index_type
FROM pg_indexes 
WHERE indexname LIKE 'idx_%'
ORDER BY tablename, indexname;

-- ==============================================
-- 5. VERIFY RLS IS ENABLED
-- ==============================================

SELECT 
    'RLS CHECK' as test_type,
    tablename,
    CASE 
        WHEN rowsecurity THEN 'ENABLED'
        ELSE 'DISABLED'
    END as rls_status
FROM pg_tables 
WHERE tablename IN ('polls', 'poll_options', 'votes')
ORDER BY tablename;

-- ==============================================
-- 6. VERIFY TRIGGERS EXIST
-- ==============================================

SELECT 
    'TRIGGER CHECK' as test_type,
    trigger_name,
    event_object_table,
    action_timing,
    event_manipulation
FROM information_schema.triggers 
WHERE trigger_name LIKE 'trigger_%'
ORDER BY event_object_table, trigger_name;

-- ==============================================
-- 7. PERFORMANCE TEST QUERIES
-- ==============================================

-- Test query performance with new indexes
EXPLAIN (ANALYZE, BUFFERS) 
SELECT p.*, COUNT(po.id) as option_count
FROM polls p
LEFT JOIN poll_options po ON p.id = po.poll_id
WHERE p.is_active = true
GROUP BY p.id
ORDER BY p.created_at DESC
LIMIT 10;

-- Test vote counting performance
EXPLAIN (ANALYZE, BUFFERS)
SELECT po.id, po.text, po.votes
FROM poll_options po
JOIN polls p ON po.poll_id = p.id
WHERE p.id = 'test-poll-id'
ORDER BY po.votes DESC;

RAISE NOTICE 'All constraint tests completed!';
RAISE NOTICE 'Check the results above to verify your database constraints are working correctly.';
