"""
More efficient approach: Use $filter to fetch only records with DocumentBillID > max_existing_id
This avoids pagination issues with sparse IDs.
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

def fetch_odata_batch_filtered(table: str, filter_expr: str | None, skip: int, top: int, orderby: str = None) -> list:
    """Fetches a batch of records from OData with optional filter."""
    params = {
        '$format': 'json',
        '$skip': skip,
        '$top': top,
    }
    
    if filter_expr:
        params['$filter'] = filter_expr
    
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
    
    # Load existing data and find max DocumentBillID
    existing_data = {}
    existing_pks = {}  # DocumentBillID -> DYID mapping
    max_document_bill_id = 0
    
    if output_file.exists():
        print(f"Loading existing data from {output_file}...")
        with open(output_file, 'r', encoding='utf-8') as f:
            existing_data = json.load(f)
            if isinstance(existing_data, dict):
                for dyid_key, record in existing_data.items():
                    if isinstance(record, dict) and primary_key in record:
                        pk_value = str(record[primary_key])
                        existing_pks[pk_value] = dyid_key
                        
                        # Find max DocumentBillID
                        try:
                            pk_int = int(pk_value)
                            max_document_bill_id = max(max_document_bill_id, pk_int)
                        except ValueError:
                            pass
        print(f"Loaded {len(existing_data)} existing records")
        print(f"Max DocumentBillID: {max_document_bill_id:,}")
    
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
    
    # Since missing records are scattered (not at the end), we need to fetch all records
    # but use deduplication to efficiently handle ones we already have
    print(f"\nStrategy: Fetch ALL records ordered by DocumentBillID")
    print("Missing records are scattered in the middle, so we'll fetch everything")
    print("and use deduplication to skip records we already have")
    
    # Calculate calls needed to cover all records
    calls_needed = (total_count // RECORDS_PER_CALL) + 1
    print(f"\nStarting complete download with deduplication ({calls_needed} calls needed)...")
    
    new_records = 0
    updated_records = 0
    total_fetched = 0
    skipped_existing = 0
    
    # Fetch all records, deduplicating as we go
    for i in range(calls_needed):
        skip = i * RECORDS_PER_CALL
        print(f"\nCall {i+1}/{calls_needed} (skip={skip:,})...", end=" ")
        
        batch = fetch_odata_batch_filtered(
            table_name, 
            None,  # No filter - fetch all
            skip, 
            RECORDS_PER_CALL, 
            f"{primary_key} asc"
        )
        
        if not batch:
            print("Empty batch - reached end")
            break
        
        print(f"Fetched {len(batch)} records")
        total_fetched += len(batch)
        
        # Process batch with deduplication
        batch_new = 0
        batch_updated = 0
        batch_skipped = 0
        for item in batch:
            if not isinstance(item, dict) or primary_key not in item:
                continue
            
            pk_value = str(item[primary_key])
            
            # Check if we already have this record
            if pk_value in existing_pks:
                # Skip if we already have it (no need to update unless data changed)
                batch_skipped += 1
                skipped_existing += 1
            else:
                # New record - assign new DYID
                max_dyid = max((int(k) for k in existing_data.keys() if k.isdigit()), default=0)
                new_dyid = max_dyid + 1
                item['DYID'] = new_dyid
                existing_data[str(new_dyid)] = item
                existing_pks[pk_value] = str(new_dyid)
                new_records += 1
                batch_new += 1
        
        print(f"  -> {batch_new} new, {batch_skipped} skipped (already have)")
        
        # Check if we've caught up
        if len(existing_data) >= total_count:
            print(f"\nReached target count! ({len(existing_data):,} >= {total_count:,})")
            break
        
        # Save progress periodically (every 100 calls or if we got new records)
        if (i + 1) % 100 == 0 or batch_new > 0:
            print(f"  Saving progress... ({len(existing_data):,} records, {new_records:,} new so far)")
            with open(output_file, 'w', encoding='utf-8') as f:
                json.dump(existing_data, f, ensure_ascii=False, indent=4)
        
        # Delay between calls
        time.sleep(DELAY_BETWEEN_CALLS_SEC)
    
    # Final save
    print(f"\n\nDownload complete!")
    print(f"Total fetched: {total_fetched:,}")
    print(f"New records: {new_records:,}")
    print(f"Skipped (already had): {skipped_existing:,}")
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
