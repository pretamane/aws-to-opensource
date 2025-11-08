-- Seed Data for Testing
-- Minimal sample data for contact, document, and visitor counter

-- Insert sample contact submission
INSERT INTO contact_submissions (
    id, name, email, company, service, budget, message,
    status, source, timestamp, user_agent, page_url,
    document_processing_enabled, search_capabilities
) VALUES (
    'contact_sample_001',
    'John Doe',
    'john.doe@example.com',
    'Acme Corporation',
    'Cloud Architecture',
    '$10,000 - $50,000',
    'Interested in migrating our infrastructure to cloud-native architecture. Looking for expertise in AWS to open-source migration.',
    'new',
    'website',
    NOW() - INTERVAL '2 days',
    'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36',
    '/',
    TRUE,
    TRUE
);

-- Insert second sample contact
INSERT INTO contact_submissions (
    id, name, email, company, service, budget, message,
    status, source, timestamp, user_agent, page_url,
    document_processing_enabled, search_capabilities
) VALUES (
    'contact_sample_002',
    'Jane Smith',
    'jane.smith@techcorp.com',
    'TechCorp Solutions',
    'DevOps Consulting',
    '$50,000 - $100,000',
    'Need help implementing CI/CD pipelines and container orchestration with Kubernetes.',
    'new',
    'website',
    NOW() - INTERVAL '1 day',
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64)',
    '/pages/services.html',
    TRUE,
    TRUE
);

-- Insert sample document for first contact
INSERT INTO documents (
    id, contact_id, filename, size, content_type, document_type,
    description, tags, upload_timestamp, processing_status,
    s3_bucket, s3_key
) VALUES (
    uuid_generate_v4(),
    'contact_sample_001',
    'project-requirements.pdf',
    245678,
    'application/pdf',
    'requirements',
    'Initial project requirements and scope document',
    '["requirements", "project-scope", "migration"]'::jsonb,
    NOW() - INTERVAL '2 days',
    'completed',
    'pretamane-data',
    'documents/contact_sample_001/project-requirements.pdf'
);

-- Insert second sample document
INSERT INTO documents (
    id, contact_id, filename, size, content_type, document_type,
    description, tags, upload_timestamp, processing_status,
    s3_bucket, s3_key
) VALUES (
    uuid_generate_v4(),
    'contact_sample_002',
    'architecture-diagram.png',
    1024567,
    'image/png',
    'diagram',
    'Current infrastructure architecture diagram',
    '["architecture", "infrastructure", "diagram"]'::jsonb,
    NOW() - INTERVAL '1 day',
    'completed',
    'pretamane-data',
    'documents/contact_sample_002/architecture-diagram.png'
);

-- Set initial visitor count
UPDATE website_visitors 
SET count = 42, 
    last_updated = NOW()
WHERE id = 'visitor_count';

-- Insert sample analytics events
INSERT INTO analytics_events (event_type, event_data, timestamp)
VALUES 
    ('page_view', '{"page": "/", "user_agent": "Mozilla/5.0"}'::jsonb, NOW() - INTERVAL '3 days'),
    ('page_view', '{"page": "/pages/services.html", "user_agent": "Mozilla/5.0"}'::jsonb, NOW() - INTERVAL '2 days'),
    ('contact_submission', '{"contact_id": "contact_sample_001", "source": "website"}'::jsonb, NOW() - INTERVAL '2 days'),
    ('document_upload', '{"document_type": "requirements", "size": 245678}'::jsonb, NOW() - INTERVAL '2 days'),
    ('contact_submission', '{"contact_id": "contact_sample_002", "source": "website"}'::jsonb, NOW() - INTERVAL '1 day'),
    ('document_upload', '{"document_type": "diagram", "size": 1024567}'::jsonb, NOW() - INTERVAL '1 day');

-- Verify seed data
SELECT 'Contacts seeded: ' || COUNT(*)::text FROM contact_submissions;
SELECT 'Documents seeded: ' || COUNT(*)::text FROM documents;
SELECT 'Visitor count: ' || count::text FROM website_visitors WHERE id = 'visitor_count';
SELECT 'Analytics events: ' || COUNT(*)::text FROM analytics_events;


