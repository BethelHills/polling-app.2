-- Comprehensive Database Migration: Add All Constraints and Security Features
-- This migration adds multiple constraints, indexes, and security features

-- ==============================================
-- 1. UNIQUE VOTE CONSTRAINT
-- ==============================================
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

-- ==============================================
-- 2. ADDITIONAL TABLE CONSTRAINTS
-- ==============================================

-- Polls table constraints
DO $$
BEGIN
    -- Ensure poll title is not empty
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint 
        WHERE conname = 'polls_title_not_empty'
    ) THEN
        ALTER TABLE polls ADD CONSTRAINT polls_title_not_empty CHECK (length(trim(title)) > 0);
        RAISE NOTICE 'Added constraint: polls_title_not_empty';
    END IF;

    -- Ensure poll title length is reasonable
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint 
        WHERE conname = 'polls_title_length'
    ) THEN
        ALTER TABLE polls ADD CONSTRAINT polls_title_length CHECK (length(title) >= 3 AND length(title) <= 200);
        RAISE NOTICE 'Added constraint: polls_title_length';
    END IF;

    -- Ensure description length is reasonable
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint 
        WHERE conname = 'polls_description_length'
    ) THEN
        ALTER TABLE polls ADD CONSTRAINT polls_description_length CHECK (length(description) <= 500);
        RAISE NOTICE 'Added constraint: polls_description_length';
    END IF;
END $$;

-- Poll options table constraints
DO $$
BEGIN
    -- Ensure option text is not empty
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint 
        WHERE conname = 'poll_options_text_not_empty'
    ) THEN
        ALTER TABLE poll_options ADD CONSTRAINT poll_options_text_not_empty CHECK (length(trim(text)) > 0);
        RAISE NOTICE 'Added constraint: poll_options_text_not_empty';
    END IF;

    -- Ensure option text length is reasonable
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint 
        WHERE conname = 'poll_options_text_length'
    ) THEN
        ALTER TABLE poll_options ADD CONSTRAINT poll_options_text_length CHECK (length(text) >= 1 AND length(text) <= 100);
        RAISE NOTICE 'Added constraint: poll_options_text_length';
    END IF;

    -- Ensure vote count is non-negative
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint 
        WHERE conname = 'poll_options_votes_non_negative'
    ) THEN
        ALTER TABLE poll_options ADD CONSTRAINT poll_options_votes_non_negative CHECK (votes >= 0);
        RAISE NOTICE 'Added constraint: poll_options_votes_non_negative';
    END IF;

    -- Ensure order index is non-negative
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint 
        WHERE conname = 'poll_options_order_non_negative'
    ) THEN
        ALTER TABLE poll_options ADD CONSTRAINT poll_options_order_non_negative CHECK (order_index >= 0);
        RAISE NOTICE 'Added constraint: poll_options_order_non_negative';
    END IF;
END $$;

-- ==============================================
-- 3. PERFORMANCE INDEXES
-- ==============================================

-- Polls table indexes
CREATE INDEX IF NOT EXISTS idx_polls_owner_id ON polls(owner_id);
CREATE INDEX IF NOT EXISTS idx_polls_is_active ON polls(is_active);
CREATE INDEX IF NOT EXISTS idx_polls_created_at ON polls(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_polls_owner_active ON polls(owner_id, is_active);

-- Poll options table indexes
CREATE INDEX IF NOT EXISTS idx_poll_options_poll_id ON poll_options(poll_id);
CREATE INDEX IF NOT EXISTS idx_poll_options_order ON poll_options(poll_id, order_index);
CREATE INDEX IF NOT EXISTS idx_poll_options_votes ON poll_options(poll_id, votes DESC);

-- Votes table indexes
CREATE INDEX IF NOT EXISTS idx_votes_poll_id ON votes(poll_id);
CREATE INDEX IF NOT EXISTS idx_votes_user_id ON votes(user_id);
CREATE INDEX IF NOT EXISTS idx_votes_poll_user ON votes(poll_id, user_id);
CREATE INDEX IF NOT EXISTS idx_votes_option_id ON votes(option_id);
CREATE INDEX IF NOT EXISTS idx_votes_created_at ON votes(created_at DESC);

-- ==============================================
-- 4. ROW LEVEL SECURITY (RLS) POLICIES
-- ==============================================

-- Enable RLS on all tables
ALTER TABLE polls ENABLE ROW LEVEL SECURITY;
ALTER TABLE poll_options ENABLE ROW LEVEL SECURITY;
ALTER TABLE votes ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if they exist (to avoid conflicts)
DROP POLICY IF EXISTS "Users can view all active polls" ON polls;
DROP POLICY IF EXISTS "Users can create polls" ON polls;
DROP POLICY IF EXISTS "Users can update their own polls" ON polls;
DROP POLICY IF EXISTS "Users can delete their own polls" ON polls;

DROP POLICY IF EXISTS "Users can view poll options for active polls" ON poll_options;
DROP POLICY IF EXISTS "Poll owners can manage options" ON poll_options;

DROP POLICY IF EXISTS "Users can view all votes" ON votes;
DROP POLICY IF EXISTS "Users can vote on active polls" ON votes;
DROP POLICY IF EXISTS "Users can only vote once per poll" ON votes;

-- Create comprehensive RLS policies
CREATE POLICY "Users can view all active polls" ON polls
  FOR SELECT USING (is_active = true);

CREATE POLICY "Users can create polls" ON polls
  FOR INSERT WITH CHECK (auth.uid() = owner_id);

CREATE POLICY "Users can update their own polls" ON polls
  FOR UPDATE USING (auth.uid() = owner_id);

CREATE POLICY "Users can delete their own polls" ON polls
  FOR DELETE USING (auth.uid() = owner_id);

CREATE POLICY "Users can view poll options for active polls" ON poll_options
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM polls 
      WHERE polls.id = poll_options.poll_id 
      AND polls.is_active = true
    )
  );

CREATE POLICY "Poll owners can manage options" ON poll_options
  FOR ALL USING (
    EXISTS (
      SELECT 1 FROM polls 
      WHERE polls.id = poll_options.poll_id 
      AND polls.owner_id = auth.uid()
    )
  );

CREATE POLICY "Users can view all votes" ON votes
  FOR SELECT USING (true);

CREATE POLICY "Users can vote on active polls" ON votes
  FOR INSERT WITH CHECK (
    auth.uid() = user_id AND
    EXISTS (
      SELECT 1 FROM polls 
      WHERE polls.id = votes.poll_id 
      AND polls.is_active = true
    )
  );

-- ==============================================
-- 5. TRIGGERS AND FUNCTIONS
-- ==============================================

-- Function to update vote counts
CREATE OR REPLACE FUNCTION update_poll_option_votes()
RETURNS TRIGGER AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    UPDATE poll_options 
    SET votes = votes + 1 
    WHERE id = NEW.option_id;
    RETURN NEW;
  ELSIF TG_OP = 'DELETE' THEN
    UPDATE poll_options 
    SET votes = votes - 1 
    WHERE id = OLD.option_id;
    RETURN OLD;
  END IF;
  RETURN NULL;
END;
$$ LANGUAGE plpgsql;

-- Function to update poll timestamps
CREATE OR REPLACE FUNCTION update_poll_timestamp()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Drop existing triggers if they exist
DROP TRIGGER IF EXISTS trigger_update_vote_counts ON votes;
DROP TRIGGER IF EXISTS trigger_update_poll_timestamp ON polls;

-- Create triggers
CREATE TRIGGER trigger_update_vote_counts
  AFTER INSERT OR DELETE ON votes
  FOR EACH ROW EXECUTE FUNCTION update_poll_option_votes();

CREATE TRIGGER trigger_update_poll_timestamp
  BEFORE UPDATE ON polls
  FOR EACH ROW EXECUTE FUNCTION update_poll_timestamp();

-- ==============================================
-- 6. DATA VALIDATION FUNCTIONS
-- ==============================================

-- Function to validate poll options uniqueness
CREATE OR REPLACE FUNCTION validate_poll_options_uniqueness()
RETURNS TRIGGER AS $$
BEGIN
  -- Check for duplicate option text within the same poll
  IF EXISTS (
    SELECT 1 FROM poll_options 
    WHERE poll_id = NEW.poll_id 
    AND LOWER(TRIM(text)) = LOWER(TRIM(NEW.text))
    AND id != COALESCE(NEW.id, '00000000-0000-0000-0000-000000000000'::uuid)
  ) THEN
    RAISE EXCEPTION 'Duplicate option text not allowed within the same poll';
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger for option uniqueness validation
DROP TRIGGER IF EXISTS trigger_validate_option_uniqueness ON poll_options;
CREATE TRIGGER trigger_validate_option_uniqueness
  BEFORE INSERT OR UPDATE ON poll_options
  FOR EACH ROW EXECUTE FUNCTION validate_poll_options_uniqueness();

-- ==============================================
-- 7. VERIFICATION QUERIES
-- ==============================================

-- Verify all constraints were added
SELECT 
    conname as constraint_name,
    contype as constraint_type,
    pg_get_constraintdef(oid) as constraint_definition
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

-- Verify all indexes were created
SELECT 
    indexname,
    tablename,
    indexdef
FROM pg_indexes 
WHERE indexname LIKE 'idx_%'
ORDER BY tablename, indexname;

-- Verify RLS is enabled
SELECT 
    schemaname,
    tablename,
    rowsecurity
FROM pg_tables 
WHERE tablename IN ('polls', 'poll_options', 'votes')
ORDER BY tablename;

-- Verify triggers exist
SELECT 
    trigger_name,
    event_object_table,
    action_timing,
    event_manipulation
FROM information_schema.triggers 
WHERE trigger_name LIKE 'trigger_%'
ORDER BY event_object_table, trigger_name;

RAISE NOTICE 'Comprehensive database migration completed successfully!';
