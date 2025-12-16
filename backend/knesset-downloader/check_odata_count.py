"""
Script to check the total count of records in Knesset OData service.
This helps determine how many records need to be downloaded.
"""
import requests
import sys

BASE_OData_URL = "https://knesset.gov.il/Odata/ParliamentInfo.svc"

def get_odata_count(table_name: str) -> int | None:
    """Get the total count of records in an OData table."""
    url = f"{BASE_OData_URL}/{table_name}/$count"
    
    print(f"Checking count for {table_name}...")
    print(f"URL: {url}")
    
    try:
        # Try without Accept header first (some OData services prefer plain text for $count)
        response = requests.get(url, timeout=30)
        response.raise_for_status()
        
        # OData $count returns just a number as plain text
        count = int(response.text.strip())
        return count
    except requests.exceptions.RequestException as e:
        print(f"Error fetching count: {e}")
        if hasattr(e, 'response') and e.response is not None:
            print(f"Response status: {e.response.status_code}")
            print(f"Response text: {e.response.text[:200]}")
        return None
    except ValueError as e:
        print(f"Error parsing count: {response.text[:200]}")
        return None

def main():
    if len(sys.argv) < 2:
        print("Usage: python check_odata_count.py <table_name>")
        print("Example: python check_odata_count.py KNS_DocumentBill")
        sys.exit(1)
    
    table_name = sys.argv[1]
    count = get_odata_count(table_name)
    
    if count is not None:
        print(f"\n[OK] Total records in OData: {count:,}")
        return count
    else:
        print("\n[ERROR] Failed to get count")
        sys.exit(1)

if __name__ == "__main__":
    main()
