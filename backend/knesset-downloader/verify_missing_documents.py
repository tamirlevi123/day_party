"""
Verify if specific DocumentBill records are missing from our local file.
"""
import json
import requests
from pathlib import Path

BASE_OData_URL = "https://knesset.gov.il/Odata/ParliamentInfo.svc"

def check_documentbill_ids(document_bill_ids, local_file):
    """Check if specific DocumentBillIDs exist in local file."""
    # Load local data
    with open(local_file, 'r', encoding='utf-8') as f:
        local_data = json.load(f)
    
    # Build set of DocumentBillIDs we have
    local_ids = set()
    for key, record in local_data.items():
        if isinstance(record, dict) and 'DocumentBillID' in record:
            local_ids.add(str(record['DocumentBillID']))
    
    # Check which ones are missing
    missing = []
    found = []
    for doc_id in document_bill_ids:
        doc_id_str = str(doc_id)
        if doc_id_str in local_ids:
            found.append(doc_id)
        else:
            missing.append(doc_id)
    
    return found, missing

def fetch_documents_by_billid(bill_id):
    """Fetch all DocumentBill records for a specific BillID from OData."""
    url = f"{BASE_OData_URL}/KNS_DocumentBill()?$filter=BillID eq {bill_id}&$format=json"
    
    try:
        headers = {'Accept': 'application/json;odata=verbose'}
        response = requests.get(url, headers=headers, timeout=30)
        response.raise_for_status()
        
        data = response.json()
        results = data.get('value')
        if results is None and 'd' in data and isinstance(data['d'], dict):
            results = data['d'].get('results')
        
        return results if results else []
    except Exception as e:
        print(f"Error fetching BillID {bill_id}: {e}")
        return []

def main():
    # Test with the BillID from the image
    test_bill_id = 1046149
    local_file = Path("data/_KNS_DocumentBill.json")
    
    print(f"Fetching DocumentBill records for BillID {test_bill_id} from OData...")
    odata_records = fetch_documents_by_billid(test_bill_id)
    
    if not odata_records:
        print("No records found in OData!")
        return
    
    print(f"Found {len(odata_records)} records in OData")
    
    # Extract DocumentBillIDs
    odata_ids = [str(r['DocumentBillID']) for r in odata_records if 'DocumentBillID' in r]
    print(f"DocumentBillIDs from OData: {odata_ids}")
    
    # Check which ones we have locally
    found, missing = check_documentbill_ids(odata_ids, local_file)
    
    print(f"\nFound locally: {len(found)}")
    print(f"Missing locally: {len(missing)}")
    
    if missing:
        print(f"\nMissing DocumentBillIDs: {missing}")
        print("\nSample missing records:")
        for record in odata_records:
            if str(record.get('DocumentBillID')) in missing:
                print(f"  DocumentBillID: {record.get('DocumentBillID')}")
                print(f"    GroupTypeDesc: {record.get('GroupTypeDesc')}")
                print(f"    FilePath: {record.get('FilePath')}")
                print()

if __name__ == "__main__":
    main()
