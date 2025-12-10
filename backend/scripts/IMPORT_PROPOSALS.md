# Import Proposals Script

This script imports proposals and comments from a PostgreSQL database (e.g., "אזרחים כותבים חוקה" / Consul) into the Day Party platform.

## Prerequisites

1. **Install dependencies:**
   ```bash
   npm install
   ```

2. **Ensure you have an admin user** in the Day Party database. The script will use this user to create the topic.

3. **Source PostgreSQL database** should be accessible and contain:
   - A `proposals` table
   - A `proposal_translations` table (for multilingual content)
   - A `comments` table
   - A `comment_translations` table (for multilingual content)

## Database Schema

The script works with Consul/Decidim-style PostgreSQL schema:

### Proposals Table
- `id` - Unique identifier (integer)
- `author_id` - Author ID (integer, nullable)
- `created_at` - Creation timestamp
- `published_at` - Publication timestamp (nullable)

### Proposal Translations Table
- `id` - Unique identifier (integer)
- `proposal_id` - Foreign key to proposals.id (integer)
- `locale` - Language code (e.g., 'he', 'en')
- `title` - Proposal title (varchar, nullable)
- `description` - Proposal body/content (text, nullable)
- `summary` - Proposal summary (text, nullable)

### Comments Table
- `id` - Unique identifier (integer)
- `commentable_id` - Foreign key (polymorphic, references proposals.id when commentable_type='Proposal')
- `commentable_type` - Type of commentable object (varchar, 'Proposal' for proposals)
- `user_id` - User ID (integer)
- `created_at` - Creation timestamp
- `ancestry` - Parent comment path for nested comments (varchar, nullable, format: "1/2/3")

### Comment Translations Table
- `id` - Unique identifier (integer)
- `comment_id` - Foreign key to comments.id (integer)
- `locale` - Language code (e.g., 'he', 'en')
- `body` - Comment body/content (text, nullable)

## Configuration

You can import from either a **dump file** or a **live database**. Set the following environment variables (or create a `.env` file in the `backend` directory):

### Option 1: Import from Dump File (Recommended)

```env
# Path to PostgreSQL dump file
SOURCE_DB_DUMP_FILE=C:\Temp\consul_production_backup_21_05_2025.dump

# Database connection (for creating temporary database - uses postgres database)
SOURCE_DB_HOST=localhost
SOURCE_DB_PORT=5432
SOURCE_DB_USER=postgres
SOURCE_DB_PASSWORD=your_password

# Locale for translations (default: he)
SOURCE_DB_LOCALE=he
```

**Note:** This method creates a temporary database, extracts the data, then automatically deletes it. You need `pg_restore` (part of PostgreSQL client tools) installed.

### Option 2: Import from Live Database

```env
# Source PostgreSQL Database Configuration
SOURCE_DB_HOST=localhost
SOURCE_DB_PORT=5432
SOURCE_DB_USER=postgres
SOURCE_DB_PASSWORD=your_password
SOURCE_DB_NAME=consul_production

# Locale for translations (default: he)
SOURCE_DB_LOCALE=he

# Dry run mode - set to 'true' to test parsing without importing (recommended first!)
DRY_RUN=true
```

**Note:** If `SOURCE_DB_DUMP_FILE` is set and the file exists, the script will use dump file mode. Otherwise, it will connect to the live database.

**Dry Run Mode:** Set `DRY_RUN=true` to test the parser and see what data will be imported without actually writing to your database. This is highly recommended for first-time use!

## Usage

The script accepts command-line arguments (no environment variables needed!):

### Test the parser first (recommended):

```bash
cd backend
tsx scripts/import-proposals.ts --dump-file "C:\Temp\consul_production_backup_21_05_2025.dump" --locale he --dry-run
```

This will:
- Parse the dump file
- Show sample proposals and comments
- Display statistics
- **Not import anything** into your database

Review the output to ensure the parsing looks correct!

### Run the actual import:

```bash
# From dump file (recommended):
tsx scripts/import-proposals.ts --dump-file "C:\Temp\consul_production_backup_21_05_2025.dump" --locale he

# From live database:
tsx scripts/import-proposals.ts --host localhost --port 5432 --user postgres --password mypass --database consul_production --locale he
```

### Command-line arguments:

- `--dump-file <path>` - Path to PostgreSQL dump file (recommended method)
- `--host <host>` - PostgreSQL host (default: localhost)
- `--port <port>` - PostgreSQL port (default: 5432)
- `--user <user>` - PostgreSQL user (default: postgres)
- `--password <password>` - PostgreSQL password
- `--database <name>` - PostgreSQL database name (default: consul_production)
- `--locale <locale>` - Locale for translations (default: he)
- `--dry-run` - Test parsing without importing

**Note:** Environment variables are still supported as fallback, but command-line arguments take precedence.

**How it works with dump files:**
- Parses the PostgreSQL custom format dump file directly
- Extracts proposals, translations, comments, and comment translations
- No database or pg_restore needed!
- Reads the binary format and extracts tab-separated data

## What the Script Does

1. **Creates a new topic** called "אזרחים כותבים חוקה" (or uses existing if found)

2. **Imports proposals as threads:**
   - Each published proposal becomes a thread in the new topic
   - Joins `proposals` with `proposal_translations` to get title and description in the specified locale
   - Proposal `title` (from translations) becomes thread `title`
   - Proposal `description` (from translations) is converted to Delta JSON format and stored as thread `description`
   - Falls back to `summary` if `description` is not available
   - HTML content is automatically converted to Delta format
   - Plain text is also converted to Delta format
   - Uses `published_at` date if available, otherwise `created_at`

3. **Imports comments as neutral nodes:**
   - Only imports comments where `commentable_type = 'Proposal'`
   - Joins `comments` with `comment_translations` to get body in the specified locale
   - Each comment becomes a node in its corresponding thread
   - Root comments (no `ancestry`) become root nodes
   - Reply comments (with `ancestry`) become child nodes with `neutral` relation
   - Parses `ancestry` field (format: "1/2/3") to determine parent comment
   - Comment `body` (from translations) is converted to Delta JSON format
   - All nodes are marked as `neutral` relation (as requested)

4. **Creates an import user** (`import@dayparty.com`) if it doesn't exist, used as the author for all imported content

## Output

The script provides progress updates:
- Connection status
- Number of proposals/comments found
- Import progress for each item
- Final summary with counts

Example output:
```
🚀 Starting proposal import...

📡 Connecting to source database: localhost:3306/huka
✅ Connected to source database

✅ Created topic: אזרחים כותבים חוקה
📁 Topic ID: abc123...

👤 Using import user ID: xyz789...

📥 Fetching proposals from proposals...
✅ Found 36 proposals

  ✅ Created thread: הפרדה בין הרשות המבצעת לבין הרשות המחוקקת...
  ✅ Created thread: הצעה נוספת...
  ...

📊 Threads imported: 36, failed: 0

📥 Fetching comments from comments...
✅ Found 150 comments

📊 Nodes imported: 150, failed: 0

✅ Import complete!

📈 Summary:
  Topics: 1
  Threads: 36 (0 failed)
  Nodes: 150 (0 failed)
```

## Troubleshooting

### "No admin user found"
- Create an admin user first using: `npm run admin:set`

### Connection errors
- Verify PostgreSQL server is running
- Check database credentials in environment variables
- Ensure the source database exists
- Verify you can connect using `psql` or another PostgreSQL client

### Table not found errors
- Verify table names match your schema (should be `proposals`, `proposal_translations`, `comments`, `comment_translations`)
- Ensure the database contains the Consul/Decidim schema

### Import failures
- Check the error messages for specific issues
- Verify data types match expectations
- Ensure foreign key relationships are correct
- Verify translations exist for the specified locale (`SOURCE_DB_LOCALE`)
- Check that proposals have `published_at` set (only published proposals are imported)

## Notes

- The script preserves original creation dates when available
- HTML content is automatically converted to Delta JSON format
- All imported nodes use `neutral` relation as requested
- The script is idempotent for topics (won't create duplicates)
- If you run the script multiple times, it will create duplicate threads/nodes (consider adding deduplication logic if needed)

