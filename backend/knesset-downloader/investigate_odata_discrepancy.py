"""
Investigate the discrepancy between OData $count and actual fetchable records.
This will help us understand why we can't get all records via pagination.
"""
import requests
import json
import time
from pathlib import Path

BASE_OData_URL = "https://knesset.gov.il/Odata/ParliamentInfo.svc"

def get_odata_count(table_name: str) -> int:
    """Get the total count of records in an OData table."""
    url = f"{BASE_OData_URL}/{table_name}/$count"
    response = requests.get(url, timeout=30)
    response.raise_for_status()
    return int(response.text.strip())

def fetch_batch(table: str, skip: int, top: int, orderby: str = None) -> list:
    """Fetch a batch of records."""
    params = {
        '$format': 'json',
        '$skip': skip,
        '$top': top,
    }
    if orderby:
        params['$orderby'] = orderby
    
    query_string = '&'.join(f"{k}={v}" for k, v in params.items())
    url = f"{BASE_OData_URL}/{table}?{query_string}"
    
    headers = {'Accept': 'application/json;odata=verbose'}
    response = requests.get(url, headers=headers, timeout=60)
    response.raise_for_status()
    
    data = response.json()
    results = data.get('value')
    if results is None and 'd' in data and isinstance(data['d'], dict):
        results = data['d'].get('results')
    
    return results if results else []

def main():
    table_name = "KNS_DocumentBill"
    
    # Load existing DocumentBillIDs
    existing_file = Path("data/_KNS_DocumentBill.json")
    existing_ids = set()
    if existing_file.exists():
        with open(existing_file, 'r', encoding='utf-8') as f:
            data = json.load(f)
            for record in data.values():
                if isinstance(record, dict) and 'DocumentBillID' in record:
                    existing_ids.add(str(record['DocumentBillID']))
    
    print(f"Existing DocumentBillIDs: {len(existing_ids):,}")
    
    # Get OData count
    print("\n1. Checking OData $count...")
    total_count = get_odata_count(table_name)
    print(f"   OData $count: {total_count:,}")
    
    # Test: Fetch records without orderby to see total
    print("\n2. Testing pagination WITHOUT orderby...")
    all_fetched_ids = set()
    batches_tested = 0
    max_batches = 20  # Test first 20 batches
    
    for skip in range(0, max_batches * 100, 100):
        batch = fetch_batch(table_name, skip, 100, None)
        if not batch:
            break
        
        batch_ids = {str(r.get('DocumentBillID', '')) for r in batch if 'DocumentBillID' in r}
        all_fetched_ids.update(batch_ids)
        batches_tested += 1
        
        if skip % 1000 == 0:
            print(f"   Skip {skip}: {len(batch)} records, {len(batch_ids - existing_ids)} new IDs")
        time.sleep(0.5)
    
    print(f"   Total unique IDs fetched (no orderby): {len(all_fetched_ids):,}")
    print(f"   New IDs found: {len(all_fetched_ids - existing_ids):,}")
    
    # Test: Fetch records WITH orderby
    print("\n3. Testing pagination WITH orderby DocumentBillID asc...")
    all_ordered_ids = set()
    batches_tested_ordered = 0
    
    for skip in range(0, max_batches * 100, 100):
        batch = fetch_batch(table_name, skip, 100, "DocumentBillID asc")
        if not batch:
            break
        
        batch_ids = {str(r.get('DocumentBillID', '')) for r in batch if 'DocumentBillID' in r}
        all_ordered_ids.update(batch_ids)
        batches_tested_ordered += 1
        
        if skip % 1000 == 0:
            print(f"   Skip {skip}: {len(batch)} records, {len(batch_ids - existing_ids)} new IDs")
        time.sleep(0.5)
    
    print(f"   Total unique IDs fetched (with orderby): {len(all_ordered_ids):,}")
    print(f"   New IDs found: {len(all_ordered_ids - existing_ids):,}")
    
    # Compare
    print("\n4. Analysis:")
    print(f"   OData $count says: {total_count:,} records")
    print(f"   We have locally: {len(existing_ids):,} unique DocumentBillIDs")
    print(f"   Missing according to count: {total_count - len(existing_ids):,}")
    print(f"   Unique IDs fetched (no orderby): {len(all_fetched_ids):,}")
    print(f"   Unique IDs fetched (with orderby): {len(all_ordered_ids):,}")
    
    # Check if there are duplicate DocumentBillIDs in OData
    print("\n5. Checking for duplicate DocumentBillIDs in OData...")
    sample_batch = fetch_batch(table_name, 0, 1000, "DocumentBillID asc")
    sample_ids = [str(r.get('DocumentBillID', '')) for r in sample_batch if 'DocumentBillID' in r]
    unique_sample = set(sample_ids)
    print(f"   Sample of 1000 records:")
    print(f"   Total records: {len(sample_ids)}")
    print(f"   Unique DocumentBillIDs: {len(unique_sample)}")
    print(f"   Duplicates in sample: {len(sample_ids) - len(unique_sample)}")
    
    if len(sample_ids) != len(unique_sample):
        print(f"   ⚠️  WARNING: Found duplicate DocumentBillIDs in OData!")
        duplicates = [id for id in sample_ids if sample_ids.count(id) > 1]
        print(f"   Duplicate IDs: {set(duplicates)}")
    
    # Hypothesis: Maybe $count includes deleted/null records?
    print("\n6. Testing if $count includes records with null DocumentBillID...")
    # This would require a filter test

if __name__ == "__main__":
    main()
