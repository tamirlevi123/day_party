# Knesset Data Downloader

This directory contains Python scripts to download Knesset data from the OData API and build a SQLite database.

## Setup

1. **Install Python dependencies:**
   ```bash
   pip install -r requirements.txt
   ```

2. **Download Knesset data:**
   The downloader fetches data from the Knesset OData API: `https://knesset.gov.il/Odata/ParliamentInfo.svc`

## Usage

### Step 1: Download Data from OData API

Download each table separately using `odata_downloader.py`:

```bash
# Download Bills (KNS_Bill)
python odata_downloader.py KNS_Bill BillID 100 data/_KNS_Bill.json --top 100

# Download Persons (KNS_Person)
python odata_downloader.py KNS_Person PersonID 100 data/_KNS_Person.json --top 100

# Download Committee Sessions
python odata_downloader.py KNS_CommitteeSession CommitteeSessionID 100 data/_KNS_CommitteeSession.json --top 100

# Download other tables as needed...
```

**Note:** Adjust the number of calls based on the total number of records. The script fetches 100 records per call by default.

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
- Output: `knesset_data.db`

### Step 3: Copy Database to Server

Copy the generated `knesset_data.db` to `backend/data/knesset_data.db`:

```bash
copy knesset_data.db ..\data\knesset_data.db
```

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
- And more...

## Updating Data

To update the database with new data:

1. Run `odata_downloader.py` again - it will update existing records and add new ones
2. Rebuild the database with `initialize_database.py`
3. Copy the updated database to the server

The downloader uses DYID (Day Party ID) to track records and will update existing records based on the primary key.

