"""
Analyze which DocumentBillIDs we have and which are missing.
"""
import json
from pathlib import Path

def main():
    file_path = Path("data/_KNS_DocumentBill.json")
    
    with open(file_path, 'r', encoding='utf-8') as f:
        data = json.load(f)
    
    # Get all DocumentBillIDs
    document_bill_ids = set()
    for key, record in data.items():
        if isinstance(record, dict) and 'DocumentBillID' in record:
            doc_id = record['DocumentBillID']
            # DocumentBillID might be string or int
            if isinstance(doc_id, str):
                try:
                    document_bill_ids.add(int(doc_id))
                except ValueError:
                    document_bill_ids.add(doc_id)
            else:
                document_bill_ids.add(doc_id)
    
    print(f"Total records: {len(data):,}")
    print(f"Unique DocumentBillIDs: {len(document_bill_ids):,}")
    
    if document_bill_ids:
        numeric_ids = [id for id in document_bill_ids if isinstance(id, int)]
        if numeric_ids:
            min_id = min(numeric_ids)
            max_id = max(numeric_ids)
            print(f"DocumentBillID range: {min_id:,} to {max_id:,}")
            print(f"Gaps in sequence: {max_id - min_id + 1 - len(numeric_ids):,}")

if __name__ == "__main__":
    main()
