# Knesset Data Downloader - Quick Start

## First Time Setup

1. **Install Python dependencies:**
   ```bash
   cd backend/knesset-downloader
   pip install -r requirements.txt
   ```

2. **Download Knesset Bills (most important):**
   ```bash
   python odata_downloader.py KNS_Bill BillID 200 data/_KNS_Bill.json --top 100
   ```
   *Note: Adjust the number (200) based on total bills. Each call fetches 100 records.*

3. **Download other essential tables:**
   ```bash
   # Committees
   python odata_downloader.py KNS_Committee CommitteeID 50 data/_KNS_Committee.json --top 100
   
   # Status codes
   python odata_downloader.py KNS_Status StatusID 50 data/_KNS_Status.json --top 100
   
   # Knesset Members (optional)
   python odata_downloader.py KNS_Person PersonID 200 data/_KNS_Person.json --top 100
   ```

4. **Build SQLite database:**
   ```bash
   python initialize_database.py
   ```
   
   This creates `../data/knesset_data.db`

5. **Verify database was created:**
   ```bash
   # Check if file exists
   dir ..\data\knesset_data.db
   ```

## Updating Data

When you need to update the database with new bills:

1. **Re-download updated data:**
   ```bash
   python odata_downloader.py KNS_Bill BillID 200 data/_KNS_Bill.json --top 100
   ```

2. **Rebuild database:**
   ```bash
   python initialize_database.py
   ```

3. **Deploy:** Copy `backend/data/knesset_data.db` to your server

4. **Mobile apps** will automatically detect and download the update on next launch

## Testing the API

Once the database is built and the server is running:

```bash
# Check database info
curl http://localhost:3000/api/knesset-database/info

# Download database (large file)
curl http://localhost:3000/api/knesset-database/download -o knesset_data.db
```

## Troubleshooting

**"No module named 'requests'"**
- Run: `pip install -r requirements.txt`

**"Database file not found"**
- Make sure you ran `initialize_database.py`
- Check that `backend/data/knesset_data.db` exists

**"Connection timeout"**
- Knesset API can be slow, be patient
- Script includes automatic retries

