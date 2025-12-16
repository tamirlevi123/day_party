"""
Check counts for all downloaded tables and compare with OData.
This helps identify if the missing records issue is widespread.
"""
import json
import requests
from pathlib import Path

BASE_OData_URL = "https://knesset.gov.il/Odata/ParliamentInfo.svc"
DATA_DIR = Path("data")

def get_odata_count(table_name: str) -> int | None:
    """Get the total count of records in an OData table."""
    url = f"{BASE_OData_URL}/{table_name}/$count"
    try:
        response = requests.get(url, timeout=30)
        response.raise_for_status()
        return int(response.text.strip())
    except Exception as e:
        return None

def get_local_count(json_file: Path) -> int:
    """Get count of records in local JSON file."""
    try:
        with open(json_file, 'r', encoding='utf-8') as f:
            data = json.load(f)
            if isinstance(data, dict):
                return len(data)
            elif isinstance(data, list):
                return len(data)
            return 0
    except Exception as e:
        return 0

def get_table_name_from_file(filename: str) -> str:
    """Extract table name from filename like '_KNS_Bill.json' -> 'KNS_Bill'"""
    if filename.startswith('_KNS_') and filename.endswith('.json'):
        return filename[1:-5]  # Remove '_' prefix and '.json' suffix
    return None

def main():
    print("Checking all downloaded tables...")
    print("=" * 80)
    
    # Find all JSON files in data directory
    json_files = list(DATA_DIR.glob("_KNS_*.json"))
    
    if not json_files:
        print("No KNS_*.json files found in data directory")
        return
    
    results = []
    
    for json_file in sorted(json_files):
        table_name = get_table_name_from_file(json_file.name)
        if not table_name:
            continue
        
        print(f"\n{table_name}:")
        print(f"  File: {json_file.name}")
        
        # Get local count
        local_count = get_local_count(json_file)
        print(f"  Local records: {local_count:,}")
        
        # Get OData count
        odata_count = get_odata_count(table_name)
        if odata_count is None:
            print(f"  OData count: [ERROR - could not fetch]")
            results.append({
                'table': table_name,
                'local': local_count,
                'odata': None,
                'missing': None,
                'status': 'ERROR'
            })
            continue
        
        print(f"  OData count: {odata_count:,}")
        
        # Calculate missing
        missing = odata_count - local_count
        percentage = (local_count / odata_count * 100) if odata_count > 0 else 0
        
        if missing == 0:
            status = "OK"
            print(f"  Status: [OK] All records downloaded")
        elif missing > 0:
            status = "MISSING"
            print(f"  Status: [MISSING] {missing:,} records ({100-percentage:.1f}%)")
        else:
            status = "EXTRA"
            print(f"  Status: [EXTRA] {abs(missing):,} more records locally (data may have changed)")
        
        results.append({
            'table': table_name,
            'local': local_count,
            'odata': odata_count,
            'missing': missing,
            'percentage': percentage,
            'status': status
        })
    
    # Summary
    print("\n" + "=" * 80)
    print("SUMMARY")
    print("=" * 80)
    
    ok_tables = [r for r in results if r['status'] == 'OK']
    missing_tables = [r for r in results if r['status'] == 'MISSING']
    error_tables = [r for r in results if r['status'] == 'ERROR']
    
    print(f"\nTotal tables checked: {len(results)}")
    print(f"  OK (complete): {len(ok_tables)}")
    print(f"  Missing records: {len(missing_tables)}")
    print(f"  Errors: {len(error_tables)}")
    
    if missing_tables:
        print(f"\nTables with missing records:")
        for r in sorted(missing_tables, key=lambda x: x['missing'], reverse=True):
            print(f"  {r['table']:30} Missing: {r['missing']:8,} ({100-r['percentage']:5.1f}%)")
    
    if error_tables:
        print(f"\nTables with errors:")
        for r in error_tables:
            print(f"  {r['table']}")

if __name__ == "__main__":
    main()
