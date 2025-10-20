-- PostgreSQL Schema Initialization
-- Replaces AWS DynamoDB tables with PostgreSQL tables using JSONB

-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ============================================================================
-- CONTACT SUBMISSIONS TABLE
-- ============================================================================
-- Replaces: realistic-demo-pretamane-contact-submissions DynamoDB table
CREATE TABLE IF NOT EXISTS contact_submissions (
    id VARCHAR(255) PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    email VARCHAR(255) NOT NULL,
    company VARCHAR(255),
    service VARCHAR(255),
    budget VARCHAR(100),
    message TEXT NOT NULL,
    timestamp TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    status VARCHAR(50) DEFAULT 'new',
    source VARCHAR(100) DEFAULT 'website',
    user_agent TEXT,
    page_url TEXT,
    document_processing_enabled BOOLEAN DEFAULT TRUE,
    search_capabilities BOOLEAN DEFAULT TRUE,
    document_insights JSONB,
    last_updated TIMESTAMPTZ,
    
    -- Additional metadata
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Indexes for contact submissions
CREATE INDEX idx_contact_email ON contact_submissions(email);
CREATE INDEX idx_contact_timestamp ON contact_submissions(timestamp DESC);
CREATE INDEX idx_contact_status ON contact_submissions(status);
CREATE INDEX idx_contact_source ON contact_submissions(source);
CREATE INDEX idx_contact_insights ON contact_submissions USING GIN(document_insights);

-- ============================================================================
-- WEBSITE VISITORS TABLE
-- ============================================================================
-- Replaces: realistic-demo-pretamane-website-visitors DynamoDB table
CREATE TABLE IF NOT EXISTS website_visitors (
    id VARCHAR(255) PRIMARY KEY DEFAULT 'visitor_count',
    count INTEGER NOT NULL DEFAULT 0,
    last_updated TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Initialize visitor counter
INSERT INTO website_visitors (id, count, last_updated)
VALUES ('visitor_count', 0, NOW())
ON CONFLICT (id) DO NOTHING;

-- ============================================================================
-- DOCUMENTS TABLE
-- ============================================================================
-- Replaces: realistic-demo-pretamane-documents DynamoDB table
CREATE TABLE IF NOT EXISTS documents (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    contact_id VARCHAR(255) NOT NULL,
    filename VARCHAR(500) NOT NULL,
    size BIGINT NOT NULL,
    content_type VARCHAR(255) NOT NULL,
    document_type VARCHAR(100) NOT NULL,
    description TEXT,
    tags JSONB DEFAULT '[]'::jsonb,
    upload_timestamp TIMESTAMPTZ NOT NULL,
    processing_status VARCHAR(50) DEFAULT 'pending',
    s3_bucket VARCHAR(255),
    s3_key TEXT,
    efs_path TEXT,
    file_hash VARCHAR(64),
    processing_metadata JSONB,
    processing_timestamp TIMESTAMPTZ,
    complexity_score NUMERIC(5,2),
    indexed_timestamp TIMESTAMPTZ,
    
    -- Additional metadata
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    
    -- Foreign key
    FOREIGN KEY (contact_id) REFERENCES contact_submissions(id) ON DELETE CASCADE
);

-- Indexes for documents
CREATE INDEX idx_documents_contact_id ON documents(contact_id);
CREATE INDEX idx_documents_filename ON documents(filename);
CREATE INDEX idx_documents_type ON documents(document_type);
CREATE INDEX idx_documents_status ON documents(processing_status);
CREATE INDEX idx_documents_upload_time ON documents(upload_timestamp DESC);
CREATE INDEX idx_documents_tags ON documents USING GIN(tags);
CREATE INDEX idx_documents_metadata ON documents USING GIN(processing_metadata);

-- ============================================================================
-- ANALYTICS TABLE (NEW)
-- ============================================================================
-- Store analytics data for dashboard
CREATE TABLE IF NOT EXISTS analytics_events (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    event_type VARCHAR(100) NOT NULL,
    event_data JSONB NOT NULL,
    timestamp TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    
    -- Indexes
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_analytics_type ON analytics_events(event_type);
CREATE INDEX idx_analytics_timestamp ON analytics_events(timestamp DESC);
CREATE INDEX idx_analytics_data ON analytics_events USING GIN(event_data);

-- ============================================================================
-- FUNCTIONS AND TRIGGERS
-- ============================================================================

-- Function to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Triggers for updated_at
CREATE TRIGGER update_contact_submissions_updated_at BEFORE UPDATE
    ON contact_submissions FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_documents_updated_at BEFORE UPDATE
    ON documents FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- Function to increment visitor count (replaces DynamoDB atomic counter)
CREATE OR REPLACE FUNCTION increment_visitor_count()
RETURNS INTEGER AS $$
DECLARE
    new_count INTEGER;
BEGIN
    UPDATE website_visitors 
    SET count = count + 1,
        last_updated = NOW()
    WHERE id = 'visitor_count'
    RETURNING count INTO new_count;
    
    RETURN new_count;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- VIEWS FOR ANALYTICS
-- ============================================================================

-- Contact summary view
CREATE OR REPLACE VIEW v_contact_summary AS
SELECT 
    COUNT(*) as total_contacts,
    COUNT(CASE WHEN status = 'new' THEN 1 END) as new_contacts,
    COUNT(CASE WHEN status = 'contacted' THEN 1 END) as contacted,
    COUNT(CASE WHEN status = 'closed' THEN 1 END) as closed_contacts,
    COUNT(DISTINCT source) as unique_sources,
    DATE_TRUNC('day', timestamp) as submission_date
FROM contact_submissions
GROUP BY DATE_TRUNC('day', timestamp)
ORDER BY submission_date DESC;

-- Document processing summary
CREATE OR REPLACE VIEW v_document_summary AS
SELECT 
    COUNT(*) as total_documents,
    COUNT(CASE WHEN processing_status = 'completed' THEN 1 END) as completed,
    COUNT(CASE WHEN processing_status = 'pending' THEN 1 END) as pending,
    COUNT(CASE WHEN processing_status = 'failed' THEN 1 END) as failed,
    SUM(size) as total_size_bytes,
    AVG(complexity_score) as avg_complexity,
    document_type,
    DATE_TRUNC('day', upload_timestamp) as upload_date
FROM documents
GROUP BY document_type, DATE_TRUNC('day', upload_timestamp)
ORDER BY upload_date DESC;

-- Top contacts by document count
CREATE OR REPLACE VIEW v_top_contacts AS
SELECT 
    cs.id,
    cs.name,
    cs.email,
    cs.company,
    COUNT(d.id) as document_count,
    SUM(d.size) as total_size_bytes,
    MAX(d.upload_timestamp) as last_upload
FROM contact_submissions cs
LEFT JOIN documents d ON cs.id = d.contact_id
GROUP BY cs.id, cs.name, cs.email, cs.company
ORDER BY document_count DESC, last_upload DESC;

-- ============================================================================
-- SAMPLE DATA (Optional - for testing)
-- ============================================================================

-- Insert sample contact (commented out for production)
-- INSERT INTO contact_submissions (
--     id, name, email, company, service, budget, message, 
--     status, source, timestamp
-- ) VALUES (
--     'sample_contact_001',
--     'John Doe',
--     'john@example.com',
--     'Acme Corporation',
--     'Web Development',
--     '$10,000 - $50,000',
--     'Interested in cloud architecture services',
--     'new',
--     'website',
--     NOW()
-- );

-- ============================================================================
-- PERMISSIONS
-- ============================================================================

-- Grant permissions to app_user
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO app_user;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO app_user;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA public TO app_user;

-- ============================================================================
-- COMMENTS FOR DOCUMENTATION
-- ============================================================================

COMMENT ON TABLE contact_submissions IS 'Contact form submissions - migrated from DynamoDB';
COMMENT ON TABLE website_visitors IS 'Visitor counter - migrated from DynamoDB';
COMMENT ON TABLE documents IS 'Uploaded documents metadata - migrated from DynamoDB';
COMMENT ON TABLE analytics_events IS 'Analytics events for dashboard';

COMMENT ON FUNCTION increment_visitor_count() IS 'Atomic visitor counter - replaces DynamoDB UpdateItem';


