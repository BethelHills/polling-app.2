-- Create audit_logs table for tracking critical user actions
-- This table stores logs for security monitoring and incident investigation

CREATE TABLE IF NOT EXISTS audit_logs (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    action VARCHAR(50) NOT NULL,
    target_type VARCHAR(50) NOT NULL, -- 'poll', 'vote', 'user', 'system'
    target_id UUID, -- ID of the target resource (poll_id, vote_id, etc.)
    ip_address INET,
    user_agent TEXT,
    request_id VARCHAR(100), -- For correlating with request logs
    metadata JSONB, -- Additional context data
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW() NOT NULL
);

-- Create indexes for efficient querying
CREATE INDEX IF NOT EXISTS idx_audit_logs_user_id ON audit_logs(user_id);
CREATE INDEX IF NOT EXISTS idx_audit_logs_action ON audit_logs(action);
CREATE INDEX IF NOT EXISTS idx_audit_logs_target_type ON audit_logs(target_type);
CREATE INDEX IF NOT EXISTS idx_audit_logs_target_id ON audit_logs(target_id);
CREATE INDEX IF NOT EXISTS idx_audit_logs_created_at ON audit_logs(created_at);
CREATE INDEX IF NOT EXISTS idx_audit_logs_ip_address ON audit_logs(ip_address);

-- Composite index for common queries
CREATE INDEX IF NOT EXISTS idx_audit_logs_user_action ON audit_logs(user_id, action);
CREATE INDEX IF NOT EXISTS idx_audit_logs_target ON audit_logs(target_type, target_id);
CREATE INDEX IF NOT EXISTS idx_audit_logs_time_action ON audit_logs(created_at, action);

-- Enable Row Level Security
ALTER TABLE audit_logs ENABLE ROW LEVEL SECURITY;

-- Create RLS policies
-- Only authenticated users can insert audit logs
CREATE POLICY "insert_audit_logs" ON audit_logs
    FOR INSERT WITH CHECK (auth.role() = 'authenticated');

-- Only system admins can read audit logs (you can adjust this based on your needs)
CREATE POLICY "select_audit_logs_admin" ON audit_logs
    FOR SELECT USING (
        auth.role() = 'authenticated' AND 
        EXISTS (
            SELECT 1 FROM auth.users 
            WHERE auth.users.id = auth.uid() 
            AND auth.users.raw_user_meta_data->>'role' = 'admin'
        )
    );

-- Users can read their own audit logs
CREATE POLICY "select_audit_logs_own" ON audit_logs
    FOR SELECT USING (user_id = auth.uid());

-- No updates or deletes allowed (audit logs should be immutable)
CREATE POLICY "no_update_audit_logs" ON audit_logs
    FOR UPDATE USING (false);

CREATE POLICY "no_delete_audit_logs" ON audit_logs
    FOR DELETE USING (false);

-- Add comments for documentation
COMMENT ON TABLE audit_logs IS 'Audit trail for critical user actions and system events';
COMMENT ON COLUMN audit_logs.user_id IS 'ID of the user who performed the action (NULL for system actions)';
COMMENT ON COLUMN audit_logs.action IS 'Type of action performed (create_poll, vote, delete_poll, etc.)';
COMMENT ON COLUMN audit_logs.target_type IS 'Type of target resource (poll, vote, user, system)';
COMMENT ON COLUMN audit_logs.target_id IS 'ID of the target resource';
COMMENT ON COLUMN audit_logs.ip_address IS 'IP address of the request';
COMMENT ON COLUMN audit_logs.user_agent IS 'User agent string from the request';
COMMENT ON COLUMN audit_logs.request_id IS 'Unique request ID for correlation';
COMMENT ON COLUMN audit_logs.metadata IS 'Additional context data as JSON';
COMMENT ON COLUMN audit_logs.created_at IS 'Timestamp when the action occurred';

-- Create a function to automatically clean up old audit logs (optional)
CREATE OR REPLACE FUNCTION cleanup_old_audit_logs()
RETURNS void AS $$
BEGIN
    -- Delete audit logs older than 1 year (adjust as needed)
    DELETE FROM audit_logs 
    WHERE created_at < NOW() - INTERVAL '1 year';
    
    -- Log the cleanup action
    INSERT INTO audit_logs (action, target_type, metadata, created_at)
    VALUES (
        'cleanup_audit_logs',
        'system',
        jsonb_build_object(
            'deleted_count', ROW_COUNT,
            'cleanup_date', NOW()
        ),
        NOW()
    );
END;
$$ LANGUAGE plpgsql;

-- Create a scheduled job to run cleanup (if using pg_cron extension)
-- SELECT cron.schedule('cleanup-audit-logs', '0 2 * * 0', 'SELECT cleanup_old_audit_logs();');
