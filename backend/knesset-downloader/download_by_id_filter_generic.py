"""
Generic filter-based downloader: Use $filter=<primary_key> gt <max_id> instead of $skip
Works for any table with a numeric primary key.

Strategy:
1. Order by <primary_key> asc
2. Filter: <primary_key> gt <max_id_seen_so_far>
3. Take top 100
4. Update max_id_seen_so_far to the highest ID in the batch
5. Repeat until no more records
"""
import requests
import json
import time
import urllib.parse
import sys
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

def fetch_odata_batch_filtered(table: str, filter_expr: str, top: int, orderby: str = None) -> list:
    """Fetches a batch of records from OData with a filter (no skip)."""
    params = {
        '$format': 'json',
        '$filter': filter_expr,
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
    if len(sys.argv) < 3:
        print("Usage: python download_by_id_filter_generic.py <table_name> <primary_key> [output_file]")
        print("Example: python download_by_id_filter_generic.py KNS_Bill BillID data/_KNS_Bill.json")
        sys.exit(1)
    
    table_name = sys.argv[1]
    primary_key = sys.argv[2]
    output_file = Path(sys.argv[3]) if len(sys.argv) > 3 else Path(f"data/_{table_name}.json")
    
    # Load existing data and find max primary key value
    existing_data = {}
    existing_pks = {}  # primary_key -> DYID mapping
    max_id = 0
    
    if output_file.exists():
        print(f"Loading existing data from {output_file}...")
        with open(output_file, 'r', encoding='utf-8') as f:
            existing_data = json.load(f)
            if isinstance(existing_data, dict):
                for dyid_key, record in existing_data.items():
                    if isinstance(record, dict) and primary_key in record:
                        pk_value = str(record[primary_key])
                        existing_pks[pk_value] = dyid_key
                        
                        # Find max ID
                        try:
                            pk_int = int(pk_value)
                            max_id = max(max_id, pk_int)
                        except ValueError:
                            pass
        print(f"Loaded {len(existing_data)} existing records")
        print(f"Max {primary_key}: {max_id:,}")
    
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
    
    # Strategy: Use filter instead of skip
    print(f"\nStrategy: Use $filter={primary_key} gt <max_id> instead of $skip")
    print("This ensures we only get records we haven't seen yet")
    
    new_records = 0
    updated_records = 0
    total_fetched = 0
    call_number = 0
    consecutive_empty_batches = 0
    max_consecutive_empty = 3
    
    # IMPORTANT: Start from 0, not max_id!
    # If records are missing in the middle, starting from max_id won't find them.
    # We'll scan from the beginning and deduplicate as we go.
    current_max_id = 0
    
    print(f"\nStarting filter-based download (starting from {primary_key} > {current_max_id})...")
    print(f"Note: Starting from 0 to catch ALL records, including ones missing in the middle")
    
    while True:
        call_number += 1
        
        # Build filter: primary_key gt current_max_id
        filter_expr = f"{primary_key} gt {current_max_id}"
        
        print(f"\nCall {call_number} (filter: {filter_expr})...", end=" ")
        
        # Fetch batch with filter (no skip needed!)
        batch = fetch_odata_batch_filtered(
            table_name,
            filter_expr,
            RECORDS_PER_CALL,
            f"{primary_key} asc"  # Order by ID to get them in sequence
        )
        
        if not batch:
            consecutive_empty_batches += 1
            print("Empty batch")
            if consecutive_empty_batches >= max_consecutive_empty:
                print(f"\nStopping: {max_consecutive_empty} consecutive empty batches")
                break
            # Try incrementing max_id slightly in case of exact match issue
            current_max_id += 1
            continue
        
        consecutive_empty_batches = 0
        print(f"Fetched {len(batch)} records")
        total_fetched += len(batch)
        
        # Process batch
        batch_new = 0
        batch_updated = 0
        batch_max_id = current_max_id
        
        for item in batch:
            if not isinstance(item, dict) or primary_key not in item:
                continue
            
            pk_value = str(item[primary_key])
            
            # Track the maximum ID in this batch
            try:
                pk_int = int(pk_value)
                batch_max_id = max(batch_max_id, pk_int)
            except ValueError:
                pass
            
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
        
        # Update current_max_id to the highest ID we saw in this batch
        current_max_id = batch_max_id
        
        print(f"  -> {batch_new} new, {batch_updated} updated, max_id now: {current_max_id:,}")
        
        # Check if we've caught up
        if len(existing_data) >= total_count:
            print(f"\nReached target count! ({len(existing_data):,} >= {total_count:,})")
            break
        
        # Save progress periodically (every 50 calls or if we got new records)
        if call_number % 50 == 0 or batch_new > 0:
            print(f"  Saving progress... ({len(existing_data):,} records, {new_records:,} new so far)")
            with open(output_file, 'w', encoding='utf-8') as f:
                json.dump(existing_data, f, ensure_ascii=False, indent=4)
        
        # Delay between calls
        time.sleep(DELAY_BETWEEN_CALLS_SEC)
    
    # Final save
    print(f"\n\nDownload complete!")
    print(f"Total calls: {call_number}")
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
