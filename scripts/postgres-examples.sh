#!/bin/bash
# PostgreSQL CLI Examples and Common Operations

EC2_IP="54.179.230.219"
DB_NAME="pretamane_db"
DB_USER="app_user"

echo "=== PostgreSQL CLI Examples ==="
echo ""
echo "Prerequisites:"
echo "  export PGPASSWORD='your-password'"
echo "  (Get password from: grep DB_PASSWORD /home/ubuntu/app/docker-compose/.env on EC2)"
echo ""
echo "---"
echo ""

# Example 1: List all tables
echo "Example 1: List all tables"
echo "Command:"
echo "  psql -h $EC2_IP -p 5432 -U $DB_USER -d $DB_NAME -c '\dt'"
echo ""

# Example 2: Count records in each table
echo "Example 2: Count records in all tables"
echo "Command:"
cat << 'SQL'
  psql -h 54.179.230.219 -p 5432 -U app_user -d pretamane_db << EOF
SELECT 
    'contact_submissions' as table_name,
    COUNT(*) as count
FROM contact_submissions
UNION ALL
SELECT 
    'documents' as table_name,
    COUNT(*) as count
FROM documents
UNION ALL
SELECT 
    'website_visitors' as table_name,
    COUNT(*) as count
FROM website_visitors;
EOF
SQL
echo ""

# Example 3: Get recent contacts
echo "Example 3: Get 5 most recent contacts"
echo "Command:"
cat << 'SQL'
  psql -h 54.179.230.219 -p 5432 -U app_user -d pretamane_db -c \
  "SELECT id, name, email, company, timestamp 
   FROM contact_submissions 
   ORDER BY timestamp DESC 
   LIMIT 5;"
SQL
echo ""

# Example 4: Document statistics by type
echo "Example 4: Document statistics by type"
echo "Command:"
cat << 'SQL'
  psql -h 54.179.230.219 -p 5432 -U app_user -d pretamane_db -c \
  "SELECT 
      document_type,
      COUNT(*) as total_docs,
      pg_size_pretty(SUM(size)::bigint) as total_size,
      pg_size_pretty(AVG(size)::bigint) as avg_size
   FROM documents
   GROUP BY document_type
   ORDER BY COUNT(*) DESC;"
SQL
echo ""

# Example 5: Export data to CSV
echo "Example 5: Export contacts to CSV"
echo "Command:"
cat << 'SQL'
  psql -h 54.179.230.219 -p 5432 -U app_user -d pretamane_db -c \
  "COPY (SELECT * FROM contact_submissions ORDER BY timestamp DESC) 
   TO STDOUT WITH CSV HEADER" > contacts.csv
SQL
echo ""

# Example 6: Search for specific contact
echo "Example 6: Search for contact by email"
echo "Command:"
cat << 'SQL'
  psql -h 54.179.230.219 -p 5432 -U app_user -d pretamane_db -c \
  "SELECT id, name, email, company, message, timestamp 
   FROM contact_submissions 
   WHERE email ILIKE '%@example.com%';"
SQL
echo ""

# Example 7: Get contact with their documents
echo "Example 7: Get contact with all their documents"
echo "Command:"
cat << 'SQL'
  psql -h 54.179.230.219 -p 5432 -U app_user -d pretamane_db -c \
  "SELECT 
      c.id as contact_id,
      c.name,
      c.email,
      COUNT(d.id) as document_count,
      pg_size_pretty(COALESCE(SUM(d.size), 0)::bigint) as total_size
   FROM contact_submissions c
   LEFT JOIN documents d ON c.id = d.contact_id
   GROUP BY c.id, c.name, c.email
   ORDER BY COUNT(d.id) DESC
   LIMIT 10;"
SQL
echo ""

# Example 8: Database statistics
echo "Example 8: Get database size and table sizes"
echo "Command:"
cat << 'SQL'
  psql -h 54.179.230.219 -p 5432 -U app_user -d pretamane_db << EOF
-- Database size
SELECT pg_size_pretty(pg_database_size('pretamane_db')) as database_size;

-- Table sizes
SELECT 
    tablename,
    pg_size_pretty(pg_total_relation_size('public.'||tablename)) as size
FROM pg_tables
WHERE schemaname = 'public'
ORDER BY pg_total_relation_size('public.'||tablename) DESC;
EOF
SQL
echo ""

# Example 9: Interactive session
echo "Example 9: Start interactive psql session"
echo "Command:"
echo "  psql -h $EC2_IP -p 5432 -U $DB_USER -d $DB_NAME"
echo ""
echo "  Once inside psql:"
echo "    \\dt              - List tables"
echo "    \\d table_name    - Describe table"
echo "    \\l               - List databases"
echo "    \\timing          - Toggle query timing"
echo "    \\q               - Quit"
echo ""

# Example 10: Backup database
echo "Example 10: Backup entire database"
echo "Command:"
echo "  pg_dump -h $EC2_IP -p 5432 -U $DB_USER -d $DB_NAME -F c -f pretamane_backup.dump"
echo ""
echo "  Restore from backup:"
echo "  pg_restore -h $EC2_IP -p 5432 -U $DB_USER -d $DB_NAME pretamane_backup.dump"
echo ""

echo "---"
echo ""
echo "Tip: For automated scripts, use environment variables:"
echo "  export PGHOST=$EC2_IP"
echo "  export PGPORT=5432"
echo "  export PGUSER=$DB_USER"
echo "  export PGDATABASE=$DB_NAME"
echo "  export PGPASSWORD='your-password'"
echo ""
echo "Then you can just run: psql -c 'SELECT * FROM contact_submissions LIMIT 5;'"

