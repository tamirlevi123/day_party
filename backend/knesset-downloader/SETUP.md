# Knesset Data Downloader Setup Guide

## Overview

This directory contains Python scripts to download Knesset data from the OData API and build a SQLite database that can be served to the Day Party mobile app.

## Prerequisites

1. **Python 3.8+** installed
2. **pip** package manager

## Installation

1. Install Python dependencies:
   ```bash
   pip install -r requirements.txt
   ```

## Usage

### Step 1: Download Data from Knesset OData API

The Knesset provides an OData API at: `https://knesset.gov.il/Odata/ParliamentInfo.svc`

Download each table you need:

```bash
# Download Bills (most important)
python odata_downloader.py KNS_Bill BillID 200 data/_KNS_Bill.json --top 100

# Download Persons (Knesset Members)
python odata_downloader.py KNS_Person PersonID 200 data/_KNS_Person.json --top 100

# Download Committee Sessions
python odata_downloader.py KNS_CommitteeSession CommitteeSessionID 200 data/_KNS_CommitteeSession.json --top 100

# Download Committees
python odata_downloader.py KNS_Committee CommitteeID 50 data/_KNS_Committee.json --top 100

# Download Status codes
python odata_downloader.py KNS_Status StatusID 50 data/_KNS_Status.json --top 100

# Download other tables as needed...
```

**Note:** 
- Adjust the number of calls (3rd argument) based on total records
- The script fetches 100 records per call by default (`--top 100`)
- Use `--filter` to filter data (e.g., `--filter KnessetNum=25` for current Knesset)

### Step 2: Build SQLite Database

After downloading all JSON files, build the SQLite database:

```bash
python initialize_database.py
```

This will:
- Read all `_KNS_*.json` files from the `data/` directory
- Infer table schemas automatically
- Create SQLite tables
- Populate the database
- Output: `../data/knesset_data.db` (in backend/data/)

### Step 3: Verify Database

The database file will be created at `backend/data/knesset_data.db`. You can verify it:

```bash
# Using sqlite3 command line (if installed)
sqlite3 ../data/knesset_data.db "SELECT COUNT(*) FROM _KNS_Bill;"
```

## Updating Data

To update the database with new data:

1. Run `odata_downloader.py` again - it will:
   - Update existing records (based on primary key)
   - Add new records
   - Preserve DYID (Day Party ID) for existing records

2. Rebuild the database:
   ```bash
   python initialize_database.py
   ```

3. The updated database will be available at `backend/data/knesset_data.db`

4. The Day Party server will serve this file via `/api/knesset-database/download`

5. Mobile apps will check `/api/knesset-database/info` and download updates automatically

## Tables Supported

The downloader supports all Knesset OData tables:
- `KNS_Bill` - Bills/Laws
- `KNS_Person` - Knesset Members  
- `KNS_Committee` - Committees
- `KNS_CommitteeSession` - Committee Sessions
- `KNS_PlenumSession` - Plenum Sessions
- `KNS_DocumentBill` - Bill Documents
- `KNS_Status` - Status codes
- `KNS_Faction` - Political factions
- `KNS_Position` - Positions
- `KNS_PersonToPosition` - Person-Position relationships
- And more...

## Troubleshooting

### "No module named 'requests'"
Install dependencies: `pip install -r requirements.txt`

### "Database file not found"
Make sure you've run `initialize_database.py` and the file exists at `backend/data/knesset_data.db`

### "Connection timeout"
The Knesset API may be slow. The script includes retries and delays. Be patient.

### "Table already exists"
The `initialize_database.py` script deletes and recreates the database. This is normal.

## Integration with Day Party

1. **Backend**: The database file at `backend/data/knesset_data.db` is served via:
   - `GET /api/knesset-database/info` - Returns last modified date
   - `GET /api/knesset-database/download` - Downloads the database file

2. **Mobile App**: The Flutter app:
   - Checks for updates on app start
   - Downloads database if newer version available
   - Falls back to bundled database in assets if download fails
   - Queries local SQLite database for all Knesset data

3. **Benefits**:
   - Fast queries (local database)
   - Works offline after initial download
   - Automatic updates when new data available
   - Large dataset doesn't impact API performance

