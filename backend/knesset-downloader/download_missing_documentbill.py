"""
Efficient script to download only MISSING DocumentBill records.
Instead of re-downloading everything, this script:
1. Checks what we already have
2. Fetches only the missing records using ordered pagination
3. Merges new records with existing ones
"""
import requests
import json
import time
import urllib.parse
from pathlib import Path

BASE_OData_URL = "https://knesset.gov.il/Odata/ParliamentInfo.svc"
RECORDS_PER_CALL = 100
DELAY_BETWEEN_CALLS_SEC = 1
MAX_RETRIES = 3
RETRY_DELAY = 5

def get_odata_count(table_name: str) -> int:
    """Get the total count of records in an OData table."""
    url = f"{BASE_OData_URL}/{table_name}/$count"
    response = requests.get(url, timeout=30)
    response.raise_for_status()
    return int(response.text.strip())

def fetch_odata_batch(table: str, skip: int, top: int, orderby: str = None) -> list:
    """Fetches a batch of records from OData."""
    params = {
        '$format': 'json',
        '$skip': skip,
        '$top': top,
    }
    
    if orderby:
        params['$orderby'] = orderby
    
    query_string = urllib.parse.urlencode(params, safe=":=',%", encoding='utf-8')
    url = f"{BASE_OData_URL}/{table}?{query_string}"
    
    retries = 0
    while retries < MAX_RETRIES:
        try:
            headers = {'Accept': 'application/json;odata=verbose'}
            response = requests.get(url, headers=headers, timeout=60)
            response.raise_for_status()
            
            data = response.json()
            results = data.get('value')
            if results is None and 'd' in data and isinstance(data['d'], dict):
                results = data['d'].get('results')
            
            if results is not None:
                return results
            return []
        except Exception as e:
            retries += 1
            if retries < MAX_RETRIES:
                print(f"  Retry {retries}/{MAX_RETRIES} after error: {e}")
                time.sleep(RETRY_DELAY)
            else:
                print(f"  Failed after {MAX_RETRIES} retries: {e}")
                return []
    return []

def main():
    table_name = "KNS_DocumentBill"
    primary_key = "DocumentBillID"
    output_file = Path("data/_KNS_DocumentBill.json")
    
    # Load existing data
    existing_data = {}
    existing_pks = {}  # DocumentBillID -> DYID mapping
    if output_file.exists():
        print(f"Loading existing data from {output_file}...")
        with open(output_file, 'r', encoding='utf-8') as f:
            existing_data = json.load(f)
            if isinstance(existing_data, dict):
                for dyid_key, record in existing_data.items():
                    if isinstance(record, dict) and primary_key in record:
                        pk_value = str(record[primary_key])
                        existing_pks[pk_value] = dyid_key
        print(f"Loaded {len(existing_data)} existing records")
    
    # Get total count from OData
    print(f"\nChecking OData count for {table_name}...")
    total_count = get_odata_count(table_name)
    print(f"Total records in OData: {total_count:,}")
    print(f"Existing records: {len(existing_data):,}")
    missing_count = total_count - len(existing_data)
    print(f"Missing records: {missing_count:,}")
    
    if missing_count <= 0:
        print("\nAll records already downloaded!")
        return
    
    # Calculate how many calls we need to fetch missing records
    # We'll start from skip=existing_count and fetch forward
    calls_needed = (missing_count // RECORDS_PER_CALL) + 10  # Add buffer for safety
    print(f"\nStarting incremental download ({calls_needed} calls estimated)...")
    print("Strategy: Fetch records ordered by DocumentBillID, starting from where we left off")
    
    new_records = 0
    updated_records = 0
    total_fetched = 0
    consecutive_empty_batches = 0
    max_consecutive_empty = 3  # Stop after 3 consecutive empty batches
    
    # Fetch missing records using ordered pagination
    # Start from skip=existing_count to get records we haven't seen
    for i in range(calls_needed):
        skip = len(existing_data) + (i * RECORDS_PER_CALL)
        print(f"\nCall {i+1}/{calls_needed} (skip={skip:,})...", end=" ")
        
        # Use orderby to get records in predictable order
        batch = fetch_odata_batch(table_name, skip, RECORDS_PER_CALL, f"{primary_key} asc")
        
        if not batch:
            consecutive_empty_batches += 1
            print("Empty batch")
            if consecutive_empty_batches >= max_consecutive_empty:
                print(f"\nStopping: {max_consecutive_empty} consecutive empty batches")
                break
            continue
        
        consecutive_empty_batches = 0  # Reset counter
        print(f"Fetched {len(batch)} records")
        total_fetched += len(batch)
        
        # Process batch
        batch_new = 0
        batch_updated = 0
        for item in batch:
            if not isinstance(item, dict) or primary_key not in item:
                continue
            
            pk_value = str(item[primary_key])
            
            # Check if we already have this record
            if pk_value in existing_pks:
                # Update existing record
                dyid_key = existing_pks[pk_value]
                if 'DYID' in existing_data[dyid_key]:
                    item['DYID'] = existing_data[dyid_key]['DYID']
                existing_data[dyid_key] = item
                updated_records += 1
                batch_updated += 1
            else:
                # New record - assign new DYID
                max_dyid = max((int(k) for k in existing_data.keys() if k.isdigit()), default=0)
                new_dyid = max_dyid + 1
                item['DYID'] = new_dyid
                existing_data[str(new_dyid)] = item
                existing_pks[pk_value] = str(new_dyid)
                new_records += 1
                batch_new += 1
        
        print(f"  -> {batch_new} new, {batch_updated} updated")
        
        # Check if we've caught up
        if len(existing_data) >= total_count:
            print(f"\nReached target count! ({len(existing_data):,} >= {total_count:,})")
            break
        
        # Save progress periodically (every 50 calls or if we got new records)
        if (i + 1) % 50 == 0 or batch_new > 0:
            print(f"  Saving progress... ({len(existing_data):,} records)")
            with open(output_file, 'w', encoding='utf-8') as f:
                json.dump(existing_data, f, ensure_ascii=False, indent=4)
        
        # Delay between calls
        time.sleep(DELAY_BETWEEN_CALLS_SEC)
    
    # Final save
    print(f"\n\nDownload complete!")
    print(f"Total fetched: {total_fetched:,}")
    print(f"New records: {new_records:,}")
    print(f"Updated records: {updated_records:,}")
    print(f"Total records in file: {len(existing_data):,}")
    
    with open(output_file, 'w', encoding='utf-8') as f:
        json.dump(existing_data, f, ensure_ascii=False, indent=4)
    
    print(f"\nSaved to {output_file}")
    
    # Verify final count
    final_count = get_odata_count(table_name)
    if len(existing_data) >= final_count:
        print(f"\n[SUCCESS] All {final_count:,} records downloaded!")
    else:
        remaining = final_count - len(existing_data)
        print(f"\n[INFO] Still missing {remaining:,} records")
        print(f"Progress: {len(existing_data):,} / {final_count:,} ({100*len(existing_data)/final_count:.1f}%)")

if __name__ == "__main__":
    main()
