-- Cleanup script to remove all threads and nodes in the "אזרחים כותבים חוקה" topic
--
-- RECOMMENDED: Use MySQL Workbench - easiest method for simple SQL operations
--   1. Open MySQL Workbench
--   2. Connect to your database
--   3. Open a new query tab (Ctrl+T)
--   4. Copy and paste the SQL below
--   5. Execute (Ctrl+Enter)
--
-- Alternative methods:
--   - MySQL command line: mysql -u dayparty -p dayparty < cleanup-imported-threads.sql
--   - MySQL client: source cleanup-imported-threads.sql

-- First, delete all nodes in threads belonging to the topic
DELETE n FROM nodes n
INNER JOIN threads t ON n.thread_id = t.id
INNER JOIN topics top ON t.topic_id = top.id
WHERE top.name = 'אזרחים כותבים חוקה';

-- Then, delete all threads in the topic
DELETE t FROM threads t
INNER JOIN topics top ON t.topic_id = top.id
WHERE top.name = 'אזרחים כותבים חוקה';

-- Optional: Delete import users (uncomment if needed)
-- DELETE FROM users 
-- WHERE email LIKE '%_import@dayparty.com' OR email = 'import@dayparty.com';

-- Verify deletion (run separately to check)
-- SELECT COUNT(*) as remaining_threads FROM threads t
-- INNER JOIN topics top ON t.topic_id = top.id
-- WHERE top.name = 'אזרחים כותבים חוקה';

