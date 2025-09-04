-- Migration: Add unique constraint to votes table
-- This prevents users from voting multiple times on the same poll

-- Check if the constraint already exists before adding it
DO $$
BEGIN
    -- Add unique constraint if it doesn't exist
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint 
        WHERE conname = 'unique_user_poll_vote'
    ) THEN
        ALTER TABLE votes ADD CONSTRAINT unique_user_poll_vote UNIQUE (poll_id, user_id);
        RAISE NOTICE 'Added unique constraint: unique_user_poll_vote';
    ELSE
        RAISE NOTICE 'Constraint unique_user_poll_vote already exists';
    END IF;
END $$;

-- Optional: Clean up any existing duplicate votes before applying constraint
-- Uncomment the following lines if you need to remove duplicates first
/*
DELETE FROM votes 
WHERE id NOT IN (
    SELECT MIN(id) 
    FROM votes 
    GROUP BY poll_id, user_id
);
*/

-- Verify the constraint was added
SELECT 
    conname as constraint_name,
    contype as constraint_type,
    pg_get_constraintdef(oid) as constraint_definition
FROM pg_constraint 
WHERE conname = 'unique_user_poll_vote';
