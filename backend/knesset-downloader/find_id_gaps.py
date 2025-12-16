"""
Find gaps in DocumentBillID sequence to identify missing records.
Since missing records are in the middle (not at the end), we need to:
1. Identify ranges where we have gaps
2. Fetch records in those ranges using filters
"""
import json
import requests
from pathlib import Path

BASE_OData_URL = "https://knesset.gov.il/Odata/ParliamentInfo.svc"

def get_odata_count(table_name: str) -> int:
    """Get the total count of records in an OData table."""
    url = f"{BASE_OData_URL}/{table_name}/$count"
    response = requests.get(url, timeout=30)
    response.raise_for_status()
    return int(response.text.strip())

def fetch_with_range_filter(table: str, min_id: int, max_id: int, top: int = 100) -> list:
    """Fetch records where DocumentBillID is between min_id and max_id."""
    filter_expr = f"DocumentBillID gt {min_id} and DocumentBillID le {max_id}"
    params = {
        '$format': 'json',
        '$filter': filter_expr,
        '$top': top,
        '$orderby': 'DocumentBillID asc'
    }
    
    query_string = '&'.join(f"{k}={v}" for k, v in params.items())
    url = f"{BASE_OData_URL}/{table}?{query_string}"
    
    try:
        headers = {'Accept': 'application/json;odata=verbose'}
        response = requests.get(url, headers=headers, timeout=60)
        response.raise_for_status()
        
        data = response.json()
        results = data.get('value')
        if results is None and 'd' in data and isinstance(data['d'], dict):
            results = data['d'].get('results')
        
        return results if results else []
    except Exception as e:
        print(f"Error: {e}")
        return []

def main():
    file_path = Path("data/_KNS_DocumentBill.json")
    
    # Load existing DocumentBillIDs
    print("Loading existing DocumentBillIDs...")
    with open(file_path, 'r', encoding='utf-8') as f:
        data = json.load(f)
    
    existing_ids = set()
    for record in data.values():
        if isinstance(record, dict) and 'DocumentBillID' in record:
            try:
                doc_id = int(record['DocumentBillID'])
                existing_ids.add(doc_id)
            except (ValueError, TypeError):
                pass
    
    print(f"Existing DocumentBillIDs: {len(existing_ids):,}")
    
    # Get OData count
    total_count = get_odata_count("KNS_DocumentBill")
    print(f"OData total: {total_count:,}")
    print(f"Missing: {total_count - len(existing_ids):,}")
    
    # Strategy: Sample different ID ranges to find where missing records are
    print("\nSampling different ID ranges to find missing records...")
    
    # Test ranges: check various parts of the ID space
    test_ranges = [
        (0, 100000),
        (100000, 500000),
        (500000, 1000000),
        (1000000, 2000000),
        (2000000, 3000000),
        (3000000, 4000000),
        (4000000, 5000000),
        (5000000, 6000000),
        (6000000, 7000000),
        (7000000, 8000000),
        (8000000, 9000000),
        (9000000, 10000000),
    ]
    
    found_in_ranges = {}
    
    for min_id, max_id in test_ranges:
        print(f"\nTesting range {min_id:,} to {max_id:,}...")
        batch = fetch_with_range_filter("KNS_DocumentBill", min_id, max_id, top=1000)
        
        if batch:
            batch_ids = {int(r.get('DocumentBillID', 0)) for r in batch if 'DocumentBillID' in r}
            new_ids = batch_ids - existing_ids
            print(f"  Found {len(batch)} records in OData")
            print(f"  New IDs in this range: {len(new_ids)}")
            
            if new_ids:
                found_in_ranges[(min_id, max_id)] = len(new_ids)
                print(f"  Sample new IDs: {sorted(list(new_ids))[:10]}")
    
    print("\n" + "="*80)
    print("SUMMARY")
    print("="*80)
    
    if found_in_ranges:
        print("\nRanges with missing records:")
        for (min_id, max_id), count in sorted(found_in_ranges.items(), key=lambda x: x[1], reverse=True):
            print(f"  {min_id:10,} to {max_id:10,}: {count} missing records")
    else:
        print("\nNo missing records found in sampled ranges.")
        print("This suggests missing records might be:")
        print("  1. Very scattered throughout the range")
        print("  2. In ranges we didn't test")
        print("  3. Have IDs outside the expected range")

if __name__ == "__main__":
    main()
