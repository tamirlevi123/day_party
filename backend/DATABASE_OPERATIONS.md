# Database Operations Guide

## Overview

This guide covers common database operations for the Day Party platform. The database is **MySQL 8+** with utf8mb4 encoding.

## Preferred Method: MySQL Workbench

**For simple SQL operations, MySQL Workbench is the easiest and most straightforward approach.** No scripts or command-line tools needed - just connect and run SQL queries directly.

### Connecting to Database

1. Open **MySQL Workbench**
2. Create a new connection or use existing connection:
   - **Hostname**: `localhost` (or your database server IP)
   - **Port**: `3306`
   - **Username**: `dayparty` (or your database user)
   - **Password**: Your database password
   - **Default Schema**: `dayparty`

3. Click **Connect** to establish connection

### Running SQL Queries

1. Click **File** → **New Query Tab** (or press `Ctrl+T`)
2. Type or paste your SQL query
3. Click the **Execute** button (⚡ lightning bolt icon) or press `Ctrl+Enter`
4. View results in the **Result Grid** below

## Common Operations

### Delete Threads from a Topic

To delete all threads and their nodes from a specific topic:

```sql
-- First, delete all nodes in threads belonging to the topic
DELETE n FROM nodes n
INNER JOIN threads t ON n.thread_id = t.id
INNER JOIN topics top ON t.topic_id = top.id
WHERE top.name = 'אזרחים כותבים חוקה';

-- Then, delete all threads in the topic
DELETE t FROM threads t
INNER JOIN topics top ON t.topic_id = top.id
WHERE top.name = 'אזרחים כותבים חוקה';
```

**Note**: Replace `'אזרחים כותבים חוקה'` with your target topic name.

### Verify Deletion

Before or after deletion, verify the count:

```sql
-- Count threads in topic
SELECT COUNT(*) as thread_count 
FROM threads t
INNER JOIN topics top ON t.topic_id = top.id
WHERE top.name = 'אזרחים כותבים חוקה';

-- Count nodes in topic's threads
SELECT COUNT(*) as node_count
FROM nodes n
INNER JOIN threads t ON n.thread_id = t.id
INNER JOIN topics top ON t.topic_id = top.id
WHERE top.name = 'אזרחים כותבים חוקה';
```

### Delete Import Users (Optional)

If you want to also remove import users created during data imports:

```sql
DELETE FROM users 
WHERE email LIKE '%_import@dayparty.com' OR email = 'import@dayparty.com';
```

### Set Admin Role

To grant admin access to a user:

```sql
UPDATE users 
SET role = 'admin' 
WHERE email = 'your-email@example.com';
```

### View Topic Information

```sql
-- List all topics
SELECT id, name, description, visibility, created_at 
FROM topics 
ORDER BY created_at DESC;

-- Find threads in a topic
SELECT t.id, t.title, t.created_at, u.display_name as creator
FROM threads t
INNER JOIN topics top ON t.topic_id = top.id
LEFT JOIN users u ON t.created_by = u.id
WHERE top.name = 'אזרחים כותבים חוקה'
ORDER BY t.created_at DESC;
```

## Alternative Methods

### Using Command Line (if needed)

If you prefer command-line tools, you can use:

```powershell
# Connect to MySQL
mysql -u dayparty -p dayparty

# Then run SQL commands or source a file
source scripts/cleanup-imported-threads.sql
```

### Using Prisma Studio (for browsing)

For visual browsing and editing:

```powershell
cd backend
cmd /c npx prisma studio
```

This opens a web interface at `http://localhost:5555` where you can browse and edit data.

### Using TypeScript Scripts (for complex operations)

For complex operations that require logic or multiple steps, use the TypeScript scripts in `backend/scripts/`:

```powershell
cd backend
cmd /c npx tsx scripts/cleanup-imported-threads.ts --topic-name "Topic Name"
```

## Safety Tips

1. **Always backup before bulk deletions**: Use MySQL Workbench's **Server** → **Data Export** feature
2. **Test queries first**: Use `SELECT` to verify what will be deleted before running `DELETE`
3. **Use transactions**: Wrap operations in transactions to allow rollback:
   ```sql
   START TRANSACTION;
   -- Your DELETE statements here
   -- Review results, then:
   COMMIT;  -- or ROLLBACK; if something went wrong
   ```
4. **Double-check WHERE clauses**: Make sure your conditions are correct before executing

## Database Connection Details

- **Database Type**: MySQL 8+
- **Database Name**: `dayparty`
- **Character Set**: `utf8mb4`
- **Collation**: `utf8mb4_unicode_ci`
- **Connection String Format**: `mysql://username:password@host:port/database`

## Related Files

- `backend/prisma/schema.prisma` - Database schema definition
- `backend/scripts/cleanup-imported-threads.sql` - SQL cleanup script (can be run in Workbench)
- `backend/scripts/cleanup-imported-threads.ts` - TypeScript cleanup script (for complex operations)
- `09-Data-Model.md` - Data model documentation

---

**Remember**: For simple SQL operations, MySQL Workbench is the easiest method. Use scripts only when you need programmatic logic or automation.

