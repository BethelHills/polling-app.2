-- Polling App Database Schema for Supabase
-- Run these commands in your Supabase SQL editor

-- Create polls table
CREATE TABLE polls (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  title VARCHAR(200) NOT NULL,
  description TEXT,
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create poll_options table
CREATE TABLE poll_options (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  poll_id UUID REFERENCES polls(id) ON DELETE CASCADE,
  text VARCHAR(100) NOT NULL,
  votes INTEGER DEFAULT 0,
  order_index INTEGER NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create votes table
CREATE TABLE votes (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  poll_id UUID REFERENCES polls(id) ON DELETE CASCADE,
  option_id UUID REFERENCES poll_options(id) ON DELETE CASCADE,
  voter_ip INET,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create indexes for better performance
CREATE INDEX idx_polls_active ON polls(is_active);
CREATE INDEX idx_polls_created_at ON polls(created_at DESC);
CREATE INDEX idx_poll_options_poll_id ON poll_options(poll_id);
CREATE INDEX idx_votes_poll_id ON votes(poll_id);
CREATE INDEX idx_votes_option_id ON votes(option_id);

-- Enable Row Level Security (RLS)
ALTER TABLE polls ENABLE ROW LEVEL SECURITY;
ALTER TABLE poll_options ENABLE ROW LEVEL SECURITY;
ALTER TABLE votes ENABLE ROW LEVEL SECURITY;

-- Create policies for public read access
CREATE POLICY "Polls are viewable by everyone" ON polls
  FOR SELECT USING (true);

CREATE POLICY "Poll options are viewable by everyone" ON poll_options
  FOR SELECT USING (true);

CREATE POLICY "Votes are viewable by everyone" ON votes
  FOR SELECT USING (true);

-- Create policies for inserting votes (public can vote)
CREATE POLICY "Anyone can vote" ON votes
  FOR INSERT WITH CHECK (true);

-- Create policies for updating poll option vote counts
CREATE POLICY "Vote counts can be updated" ON poll_options
  FOR UPDATE USING (true);

-- Create a function to update the updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ language 'plpgsql';

-- Create trigger to automatically update updated_at
CREATE TRIGGER update_polls_updated_at 
  BEFORE UPDATE ON polls 
  FOR EACH ROW 
  EXECUTE FUNCTION update_updated_at_column();

-- Insert some sample data for testing
INSERT INTO polls (title, description) VALUES 
  ('What is your favorite programming language?', 'Help us understand the community preferences for programming languages.'),
  ('Which framework do you prefer for web development?', 'Share your opinion on popular web development frameworks.'),
  ('How do you prefer to learn new technologies?', 'Understanding learning preferences helps us create better resources.');

-- Insert sample options for the first poll
INSERT INTO poll_options (poll_id, text, order_index) 
SELECT 
  p.id,
  option_text,
  option_order
FROM polls p,
(VALUES 
  ('JavaScript', 0),
  ('Python', 1),
  ('TypeScript', 2),
  ('Java', 3),
  ('Go', 4),
  ('Rust', 5)
) AS options(option_text, option_order)
WHERE p.title = 'What is your favorite programming language?';

-- Insert sample options for the second poll
INSERT INTO poll_options (poll_id, text, order_index) 
SELECT 
  p.id,
  option_text,
  option_order
FROM polls p,
(VALUES 
  ('React', 0),
  ('Vue.js', 1),
  ('Angular', 2),
  ('Svelte', 3),
  ('Next.js', 4)
) AS options(option_text, option_order)
WHERE p.title = 'Which framework do you prefer for web development?';

-- Insert sample options for the third poll
INSERT INTO poll_options (poll_id, text, order_index) 
SELECT 
  p.id,
  option_text,
  option_order
FROM polls p,
(VALUES 
  ('Online courses', 0),
  ('Documentation', 1),
  ('Video tutorials', 2),
  ('Books', 3),
  ('Hands-on projects', 4),
  ('Community forums', 5)
) AS options(option_text, option_order)
WHERE p.title = 'How do you prefer to learn new technologies?';
