"""
Analyze why DocumentBill records were missed in the original download.
This helps us understand the root cause and design a better update mechanism.
"""
import json
from pathlib import Path

def analyze_download_pattern():
    """Analyze the download pattern to understand why records were missed."""
    
    file_path = Path("data/_KNS_DocumentBill.json")
    
    with open(file_path, 'r', encoding='utf-8') as f:
        data = json.load(f)
    
    # Get all DocumentBillIDs and their order
    document_bill_ids = []
    for key, record in data.items():
        if isinstance(record, dict) and 'DocumentBillID' in record:
            doc_id = record['DocumentBillID']
            # Convert to int for comparison
            try:
                doc_id_int = int(doc_id) if isinstance(doc_id, str) else doc_id
                document_bill_ids.append(doc_id_int)
            except (ValueError, TypeError):
                pass
    
    document_bill_ids.sort()
    
    print(f"Total records: {len(document_bill_ids):,}")
    print(f"DocumentBillID range: {document_bill_ids[0]:,} to {document_bill_ids[-1]:,}")
    
    # Analyze gaps
    gaps = []
    for i in range(len(document_bill_ids) - 1):
        gap = document_bill_ids[i+1] - document_bill_ids[i]
        if gap > 1000:  # Large gaps
            gaps.append((document_bill_ids[i], document_bill_ids[i+1], gap))
    
    print(f"\nLarge gaps (>1000) found: {len(gaps)}")
    if gaps:
        print("Sample gaps:")
        for start, end, gap_size in gaps[:10]:
            print(f"  Gap: {start:,} -> {end:,} (size: {gap_size:,})")
    
    # Check specific DocumentBillIDs from the image
    test_ids = [8611102, 8896042, 8915068, 8922796, 9005790]
    print(f"\n\nChecking specific DocumentBillIDs from BillID 1046149:")
    for test_id in test_ids:
        if test_id in document_bill_ids:
            position = document_bill_ids.index(test_id)
            print(f"  DocumentBillID {test_id:,}: FOUND at position {position:,}")
        else:
            print(f"  DocumentBillID {test_id:,}: MISSING")
    
    # Analyze the distribution
    print(f"\n\nDistribution analysis:")
    print(f"  First 10%: {document_bill_ids[:len(document_bill_ids)//10]}")
    print(f"  Last 10%: {document_bill_ids[-len(document_bill_ids)//10:]}")
    
    # Check if records are clustered by BillID
    bill_id_groups = {}
    for key, record in data.items():
        if isinstance(record, dict) and 'BillID' in record:
            bill_id = record['BillID']
            if bill_id not in bill_id_groups:
                bill_id_groups[bill_id] = []
            if 'DocumentBillID' in record:
                doc_id = record['DocumentBillID']
                try:
                    doc_id_int = int(doc_id) if isinstance(doc_id, str) else doc_id
                    bill_id_groups[bill_id].append(doc_id_int)
                except (ValueError, TypeError):
                    pass
    
    # Check BillID 1046149 specifically
    if 1046149 in bill_id_groups:
        docs = sorted(bill_id_groups[1046149])
        print(f"\n\nBillID 1046149 has {len(docs)} DocumentBill records:")
        print(f"  DocumentBillIDs: {docs}")
        print(f"  Range: {docs[0]:,} to {docs[-1]:,}")
    else:
        print(f"\n\nBillID 1046149 NOT FOUND in data!")

if __name__ == "__main__":
    analyze_download_pattern()
