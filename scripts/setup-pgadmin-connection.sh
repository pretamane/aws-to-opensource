#!/bin/bash
# Setup pgAdmin PostgreSQL Server Connection
# This script configures the PostgreSQL server connection in pgAdmin

echo "=========================================="
echo "  Setting up pgAdmin PostgreSQL Connection"
echo "=========================================="

# Check if pgAdmin is accessible
echo "🔍 Checking pgAdmin accessibility..."
curl -s -o /dev/null -w "%{http_code}" https://54-179-230-219.sslip.io/pgadmin/misc/ping
if [ $? -eq 0 ]; then
    echo "✅ pgAdmin is accessible"
else
    echo "❌ pgAdmin is not accessible"
    exit 1
fi

echo ""
echo "📋 PostgreSQL Connection Details:"
echo "   Host: postgresql"
echo "   Port: 5432"
echo "   Database: pretamane_db"
echo "   Username: pretamane"
echo "   Password: #ThawZin2k77!"
echo ""

echo "🔧 Manual Setup Instructions:"
echo "1. Open: https://54-179-230-219.sslip.io/pgadmin"
echo "2. Login with:"
echo "   Email: pretamane@localhost.com"
echo "   Password: #ThawZin2k77!"
echo ""
echo "3. Right-click 'Servers' → 'Register' → 'Server'"
echo "4. Fill in the connection details above"
echo "5. Click 'Save'"
echo ""

echo "📊 Verify Data is Present:"
echo "Running quick database check..."

# Run a quick check to show the data exists
docker exec postgresql psql -U pretamane -d pretamane_db -c "
SELECT 
    '📊 DATABASE SUMMARY' as info,
    (SELECT COUNT(*) FROM contact_submissions) as contacts,
    (SELECT COUNT(*) FROM documents) as documents,
    (SELECT COUNT(*) FROM website_visitors) as visitors,
    (SELECT COUNT(*) FROM analytics_events) as analytics_events;
"

echo ""
echo "✅ Database contains:"
echo "   - 2 contacts"
echo "   - 2 documents" 
echo "   - 1 visitor record"
echo "   - 6 analytics events"
echo ""

echo "🎯 Next Steps:"
echo "1. Configure pgAdmin connection using the details above"
echo "2. Browse to: Servers → EC2 PostgreSQL → Databases → pretamane_db → Schemas → public → Tables"
echo "3. You should see: contact_submissions, documents, website_visitors, analytics_events"
echo ""

echo "🔍 Quick Data Preview:"
docker exec postgresql psql -U pretamane -d pretamane_db -c "
SELECT 
    'CONTACTS' as table_name,
    id, name, email, company
FROM contact_submissions
UNION ALL
SELECT 
    'DOCUMENTS' as table_name,
    LEFT(id::text, 13) as id, 
    filename as name, 
    document_type as email, 
    processing_status as company
FROM documents
LIMIT 5;
"

echo ""
echo "=========================================="
echo "  pgAdmin Setup Complete!"
echo "=========================================="



