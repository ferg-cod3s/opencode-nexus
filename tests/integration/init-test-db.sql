-- Initialize test database for integration tests
-- This script runs when the PostgreSQL test container starts

-- Create test schemas
CREATE SCHEMA IF NOT EXISTS test_auth;
CREATE SCHEMA IF NOT EXISTS test_chat;
CREATE SCHEMA IF NOT EXISTS test_sessions;

-- Create test users table
CREATE TABLE IF NOT EXISTS test_auth.users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    username VARCHAR(50) UNIQUE NOT NULL,
    email VARCHAR(255) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    is_active BOOLEAN DEFAULT true
);

-- Create test sessions table
CREATE TABLE IF NOT EXISTS test_sessions.user_sessions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES test_auth.users(id) ON DELETE CASCADE,
    session_token VARCHAR(255) UNIQUE NOT NULL,
    expires_at TIMESTAMP WITH TIME ZONE NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    last_accessed TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create test chat messages table
CREATE TABLE IF NOT EXISTS test_chat.messages (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    session_id UUID NOT NULL REFERENCES test_sessions.user_sessions(id) ON DELETE CASCADE,
    role VARCHAR(20) NOT NULL CHECK (role IN ('user', 'assistant', 'system')),
    content TEXT NOT NULL,
    metadata JSONB DEFAULT '{}',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create test chat sessions table
CREATE TABLE IF NOT EXISTS test_chat.chat_sessions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES test_auth.users(id) ON DELETE CASCADE,
    title VARCHAR(255),
    model_name VARCHAR(100) DEFAULT 'gpt-4',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    is_active BOOLEAN DEFAULT true
);

-- Insert test data
INSERT INTO test_auth.users (username, email, password_hash) VALUES
('testuser1', 'test1@example.com', '$argon2id$v=19$m=65536,t=3,p=4$test_salt$test_hash'),
('testuser2', 'test2@example.com', '$argon2id$v=19$m=65536,t=3,p=4$test_salt$test_hash')
ON CONFLICT (email) DO NOTHING;

-- Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_users_email ON test_auth.users(email);
CREATE INDEX IF NOT EXISTS idx_users_username ON test_auth.users(username);
CREATE INDEX IF NOT EXISTS idx_sessions_token ON test_sessions.user_sessions(session_token);
CREATE INDEX IF NOT EXISTS idx_sessions_user_id ON test_sessions.user_sessions(user_id);
CREATE INDEX IF NOT EXISTS idx_messages_session_id ON test_chat.messages(session_id);
CREATE INDEX IF NOT EXISTS idx_chat_sessions_user_id ON test_chat.chat_sessions(user_id);

-- Grant permissions
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA test_auth TO test_user;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA test_sessions TO test_user;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA test_chat TO test_user;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA test_auth TO test_user;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA test_sessions TO test_user;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA test_chat TO test_user;