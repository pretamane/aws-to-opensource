# pgAdmin Connection Guide

##  Database Status: FULLY POPULATED

**Data Confirmed:**
- **2 Contacts:** John Doe, Jane Smith
- **2 Documents:** project-requirements.pdf, architecture-diagram.png  
- **1 Visitor Record:** Count = 42
- **6 Analytics Events:** Page views, submissions, uploads

---

##  pgAdmin Connection Setup

### Step 1: Access pgAdmin
**URL:** https://54-179-230-219.sslip.io/pgadmin

### Step 2: Login
- **Email:** `pretamane@localhost.com`
- **Password:** `#ThawZin2k77!`

### Step 3: Add PostgreSQL Server

1. **Right-click "Servers"** in the left panel
2. **Select "Register" → "Server"**
3. **Fill in the General tab:**
   - **Name:** `EC2 PostgreSQL`
4. **Switch to Connection tab:**
   - **Host name/address:** `postgresql`
   - **Port:** `5432`
   - **Maintenance database:** `pretamane_db`
   - **Username:** `pretamane`
   - **Password:** `#ThawZin2k77!`
5. **Click "Save"**

### Step 4: Browse Your Data

Once connected, navigate to:
```
Servers → EC2 PostgreSQL → Databases → pretamane_db → Schemas → public → Tables
```

**You should see 4 tables:**
- `contact_submissions` (2 rows)
- `documents` (2 rows)  
- `website_visitors` (1 row)
- `analytics_events` (6 rows)

---

##  Quick Data Verification

### View Contacts
```sql
SELECT id, name, email, company, service 
FROM contact_submissions;
```

### View Documents  
```sql
SELECT id, filename, document_type, processing_status, size
FROM documents;
```

### View Visitor Count
```sql
SELECT * FROM website_visitors;
```

### View Analytics
```sql
SELECT event_type, COUNT(*) as count
FROM analytics_events 
GROUP BY event_type;
```

---

##  Troubleshooting

### If Connection Fails:

1. **Check Host Name:** Use `postgresql` (not `localhost` or IP)
2. **Check Port:** Must be `5432`
3. **Check Database:** Must be `pretamane_db`
4. **Check Credentials:** Username `pretamane`, Password `#ThawZin2k77!`

### If Tables Appear Empty:

The data IS there - you might be looking at the wrong database or schema. Make sure you're in:
- **Database:** `pretamane_db`
- **Schema:** `public`
- **Tables:** `contact_submissions`, `documents`, `website_visitors`, `analytics_events`

---

##  Expected Data

### Contacts (2 records)
```
contact_sample_001 | John Doe   | john.doe@example.com    | Acme Corporation
contact_sample_002 | Jane Smith | jane.smith@techcorp.com | TechCorp Solutions
```

### Documents (2 records)
```
a06a2a8b-11f7 | project-requirements.pdf | requirements  | completed
d4c194c0-8c01 | architecture-diagram.png | diagram       | completed
```

### Visitor Count
```
visitor_count | 42 | 2025-10-21 06:33:08
```

### Analytics Events (6 records)
```
page_view (2), contact_submission (2), document_upload (2)
```

---

##  Success Indicators

You'll know it's working when you can:
1.  Connect to the server without errors
2.  See 4 tables in the public schema
3.  Right-click any table → "View/Edit Data" → "All Rows"
4.  See the sample data displayed

---

**Database is 100% populated and ready for use!**



