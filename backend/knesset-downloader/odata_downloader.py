import argparse
import requests
import json
import os
import time
import urllib.parse
from pathlib import Path
from datetime import datetime

# --- Configuration ---
BASE_OData_URL = "https://knesset.gov.il/Odata/ParliamentInfo.svc"
# Directory containing other JSON files to scan for max DYID
DATA_DIR = Path(__file__).parent / "data"
RECORDS_PER_CALL = 100
DELAY_BETWEEN_CALLS_SEC = 1
DEFAULT_TOP = 100 # Default records per OData call
MAX_RETRIES = 3
RETRY_DELAY = 5 # seconds

# --- Helper Functions ---

def safe_filename(name: str) -> str:
    """Sanitize a string to be safe for filenames."""
    # Remove or replace characters invalid for Windows/Linux filenames
    return "".join(c for c in name if c.isalnum() or c in ('_', '-')).rstrip()

def parse_datetime(date_string: str | None) -> datetime | None:
    """Parses OData weird date format /Date(timestamp+offset)/ or ISO format."""
    if not date_string:
        return None
    try:
        if date_string.startswith('/Date('):
            # Extract timestamp part, ignore offset for simplicity for now
            ts_part = date_string[6:].split('+')[0].split('-')[0]
            if ts_part:
                timestamp = int(ts_part)
                # OData timestamp is often milliseconds since epoch
                return datetime.fromtimestamp(timestamp / 1000)
        else:
            # Attempt standard ISO parsing
            return datetime.fromisoformat(date_string.replace('Z', '+00:00'))
    except (ValueError, IndexError) as e:
        print(f"  Warning: Could not parse date: {date_string}, Error: {e}")
        return None

def find_max_dyid(directory_path: Path, output_file_path: Path) -> int:
    """
    Scans JSON files in a directory and a specific output file to find the maximum existing DYID.
    """
    max_dyid = 0
    files_to_scan = []
    output_file_scanned = False

    # Prioritize checking the specific output file first
    if output_file_path.exists() and output_file_path.is_file():
        print(f"Including existing output file for DYID scan: {output_file_path}")
        files_to_scan.append(output_file_path)
        output_file_scanned = True # Mark that we intend to scan it
    else:
        print(f"Output file does not exist, will not be scanned for existing DYIDs: {output_file_path}")

    # Scan the data directory
    if directory_path.exists() and directory_path.is_dir():
        print(f"Scanning directory for existing DYIDs: {directory_path}")
        for filename in os.listdir(directory_path):
            if filename.lower().endswith(".json"):
                full_path = directory_path / filename
                # Avoid adding the output file again if it's inside DATA_DIR
                if full_path != output_file_path:
                    files_to_scan.append(full_path)
    else:
         print(f"Warning: Data directory not found, skipping scan: {directory_path}")


    for file_path in files_to_scan:
        try:
            print(f"  Scanning file: {file_path.name}...")
            with open(file_path, 'r', encoding='utf-8') as f:
                data = json.load(f)

                # Handle dict keyed by DYID (like our output format)
                if isinstance(data, dict):
                    for key in data.keys():
                        try:
                            dyid = int(key)
                            max_dyid = max(max_dyid, dyid)
                        except (ValueError, TypeError):
                            pass # Ignore keys that aren't integer DYIDs
                # Handle list of records, each having a DYID key
                elif isinstance(data, list):
                    for item in data:
                        if isinstance(item, dict) and 'DYID' in item:
                             try:
                                dyid = int(item['DYID'])
                                max_dyid = max(max_dyid, dyid)
                             except (ValueError, TypeError):
                                 pass # Ignore invalid DYID values
        except FileNotFoundError:
            # This should only happen if the output file was listed but deleted between the check and the open
            # Or if a file in DATA_DIR was deleted.
            print(f"  Warning: File not found during scan (was it deleted?): {file_path}")
        except json.JSONDecodeError:
            print(f"  Warning: Could not decode JSON from file: {file_path}")
        except Exception as e:
            print(f"  Warning: Error reading file {file_path}: {e}")

    print(f"Found Max Existing DYID after scan: {max_dyid}")
    return max_dyid

def load_existing_data(output_file_path: Path, primary_key_name: str) -> tuple[dict, dict]:
    """
    Loads existing data from the output JSON file.
    Returns two dictionaries:
    1. data_dict (dyid_str -> record)
    2. pk_to_dyid_lookup (primary_key_value -> dyid_str)
    """
    data_dict = {}
    pk_to_dyid_lookup = {}
    if output_file_path.exists() and output_file_path.is_file():
        try:
            print(f"Loading existing data from: {output_file_path}")
            with open(output_file_path, 'r', encoding='utf-8') as f:
                data_dict = json.load(f) # Assumes format { "dyid_str": {record} }
                if not isinstance(data_dict, dict):
                    print(f"Warning: Existing file {output_file_path} is not a JSON dictionary. Starting fresh.")
                    return {}, {}

                # Build the reverse lookup map
                for dyid_str, record in data_dict.items():
                    if isinstance(record, dict) and primary_key_name in record:
                        pk_value = record[primary_key_name]
                        if pk_value is not None: # Handle potential null PKs if necessary
                             pk_to_dyid_lookup[pk_value] = dyid_str
                    else:
                         print(f"Warning: Record with DYID {dyid_str} in existing file is malformed or missing primary key '{primary_key_name}'.")

            print(f"Loaded {len(data_dict)} existing records successfully.")
        except json.JSONDecodeError:
            print(f"Warning: Could not decode JSON from existing file: {output_file_path}. Starting fresh.")
            return {}, {}
        except Exception as e:
            print(f"Warning: Error reading existing file {output_file_path}: {e}. Starting fresh.")
            return {}, {}
    else:
        print(f"Output file not found ({output_file_path}). Will start with empty data.")
        # Returns the empty dicts initialized above

    return data_dict, pk_to_dyid_lookup

def build_odata_filter(filters: list[str] | None) -> str:
    """Builds the OData $filter string from a list of filter parts."""
    if filters is None or len(filters) == 0:
        return ""
    
    odata_parts = []
    i = 0
    valid_ops = {'eq', 'ne', 'gt', 'ge', 'lt', 'le'}

    while i < len(filters):
        # Pattern 1: field operator value (3 parts)
        if i + 2 < len(filters) and filters[i+1].lower() in valid_ops:
            field = filters[i]
            op = filters[i+1].lower()
            value = filters[i+2]
            # Basic quoting for non-numeric/bool/null values
            try:
                float(value)
            except ValueError:
                if value.lower() not in ['true', 'false', 'null']:
                    value = f"'{value}'" # Quote strings
            odata_parts.append(f"{field} {op} {value}")
            i += 3
        # Pattern 2: field=value (1 part)
        elif '=' in filters[i]:
            parts = filters[i].split('=', 1)
            if len(parts) == 2:
                field, value = parts
                # Basic quoting
                try:
                    float(value)
                except ValueError:
                     if value.lower() not in ['true', 'false', 'null']:
                        value = f"'{value}'"
                odata_parts.append(f"{field} eq {value}") # Default to 'eq'
                i += 1
            else:
                print(f"Warning: Skipping invalid filter format: {filters[i]}")
                i += 1
        else:
            print(f"Warning: Skipping invalid filter format: {filters[i]}")
            i += 1

    filter_string = " and ".join(odata_parts)
    print(f"Built OData Filter: {filter_string if filter_string else 'None'}")
    return filter_string

def fetch_odata(base_url: str, table: str, filters: str | None, orderby: str | None, skip: int, top: int) -> list | None:
    """Fetches data from a single OData request."""
    params = {
        '$format': 'json',
        '$skip': skip,
        '$top': top,
    }
    # Manually encode spaces as %20 within filter and orderby values, as some servers require it.
    encoded_filters = filters.replace(' ', '%20') if filters else None
    encoded_orderby = orderby.replace(' ', '%20') if orderby else None

    if encoded_filters:
        params['$filter'] = encoded_filters
    if encoded_orderby:
        params['$orderby'] = encoded_orderby

    # Encode the parameters, keeping pre-encoded %20 and other necessary OData chars safe.
    try:
        query_string = urllib.parse.urlencode(params, safe=":=',%", encoding='utf-8')
    except Exception as e:
        print(f"  Error encoding URL parameters: {e}")
        return None

    fetch_url = f"{base_url}/{table}?{query_string}"

    print(f"  Fetching: {fetch_url}")
    retries = 0
    while retries < MAX_RETRIES:
        try:
            headers = {'Accept': 'application/json;odata=verbose'}
            response = requests.get(fetch_url, headers=headers, timeout=60) # Increased timeout
            response.raise_for_status() # Raise HTTPError for bad responses (4xx or 5xx)

            data = response.json()
            # OData results wrapper depends on header (verbose vs minimalmetadata)
            # For verbose, it's often {'d': {'results': [...]}}
            # For minimalmetadata, it's often {'value': [...]} - Let's try 'value' first
            results = data.get('value')
            if results is None and 'd' in data and isinstance(data['d'], dict):
                 results = data['d'].get('results')

            if results is not None:
                 return results # Return the list of records
            else:
                print(f"  Warning: Could not find 'value' or 'd.results' in JSON response structure.")
                print(f"  Response sample: {str(data)[:200]}...") # Print sample
                return [] # Return empty list if structure is unexpected but request succeeded

        except requests.exceptions.Timeout:
            retries += 1
            print(f"  Timeout occurred. Retrying ({retries}/{MAX_RETRIES})... ({RETRY_DELAY}s delay)")
            time.sleep(RETRY_DELAY)
        except requests.exceptions.RequestException as e:
            error_details = ""
            if e.response is not None:
                try:
                    error_json = e.response.json()
                    error_details = f" Server response: {error_json}"
                except json.JSONDecodeError:
                    error_details = f" Server response text: {e.response.text}"
            print(f"  Error fetching data: {e}{error_details}")
            # Decide if retryable - often 4xx are not, 5xx might be
            if e.response is not None and 400 <= e.response.status_code < 500:
                 print("  Client error (4xx), not retrying.")
                 return None # Fatal client error
            retries += 1
            if retries < MAX_RETRIES:
                 print(f"  Request error. Retrying ({retries}/{MAX_RETRIES})... ({RETRY_DELAY}s delay)")
                 time.sleep(RETRY_DELAY)
            else:
                print("  Max retries reached.")
                return None # Max retries failed
        except json.JSONDecodeError as e:
            print(f"  Error decoding JSON response: {e}")
            # Log response text if possible
            if 'response' in locals() and hasattr(response, 'text'):
                 print(f"  Response text sample: {response.text[:200]}...")
            return None # Cannot parse JSON, fatal for this call
        except Exception as e:
            print(f"  An unexpected error occurred during fetch: {e}")
            return None # Unexpected error, fatal for this call

    return None # Should be unreachable if retries loop finishes, but good practice

def save_data(filepath: str, data: dict):
    """Saves the data dictionary values to a JSON file."""
    print("--- Saving Data ---")
    try:
        # Convert dict values (records) to a list for saving
        records_to_save = list(data.values())
        with open(filepath, 'w', encoding='utf-8') as f:
            json.dump(records_to_save, f, ensure_ascii=False, indent=2)
        print(f"Successfully saved data to: {os.path.basename(filepath)}")
    except Exception as e:
        print(f"Error saving data to {filepath}: {e}")
    print("----------------")

# --- Main Execution ---

def main():
    parser = argparse.ArgumentParser(description="Download data from Knesset OData service and accumulate in JSON.")
    parser.add_argument("table", help="Name of the OData table (e.g., KNS_Person).")
    parser.add_argument("primary_key", help="Name of the primary key column in the OData table (e.g., PersonID, BillID) used for matching existing records.")
    parser.add_argument("calls", type=int, help=f"Number of calls to make (fetches {RECORDS_PER_CALL} records per call).")
    parser.add_argument("output_file", help="Path to the output JSON file (will be created or appended to).")
    parser.add_argument("--filter", nargs='*', help="Filter criteria as key=value pairs separated by space (e.g., --filter KnessetNum=25 IsCurrent=true). String values do not need quotes here.")
    parser.add_argument("--sort", help="OData $orderby string (e.g., PersonID asc).")
    parser.add_argument("--skip", type=int, default=0, help="Initial number of records to $skip.")
    parser.add_argument("--top", type=int, default=DEFAULT_TOP, help=f"Records per call (default: {DEFAULT_TOP}).")
    parser.add_argument("--data-dir", default="./data", help="Directory containing existing JSON files for DYID scanning (default: ./data).")

    args = parser.parse_args()

    print("--- Script Starting ---")
    print(f"Parsed Arguments:")
    print(f"  Table: {args.table}")
    print(f"  Primary Key: {args.primary_key}")
    print(f"  Calls: {args.calls}")
    print(f"  Output File: {args.output_file}")
    print(f"  Filter: {args.filter}")
    print(f"  Sort: {args.sort}")
    print(f"  Skip: {args.skip}")
    print(f"  Top: {args.top}")
    print(f"  Data Dir: {args.data_dir}")
    print("-----------------------")

    output_file_path = Path(args.output_file)
    output_file_path.parent.mkdir(parents=True, exist_ok=True) # Ensure output directory exists

    # 1. Find max existing DYID
    print("--- Scanning for Max DYID ---")
    max_existing_dyid = find_max_dyid(DATA_DIR, output_file_path)
    next_dyid = max_existing_dyid + 1
    print(f"Next DYID will start from: {next_dyid}")
    print("-----------------------------")

    # 2. Load existing data from the target file
    print("--- Loading Existing Data ---")
    data_dict, pk_lookup = load_existing_data(output_file_path, args.primary_key)
    print(f"Loaded {len(data_dict)} records, {len(pk_lookup)} primary keys indexed.")
    print("---------------------------")

    # 3. Build OData filters
    filter_string = build_odata_filter(args.filter)
    print(f"Built OData Filter: {filter_string if filter_string else '(None)'}")

    # 4. Fetch data in loops
    print("--- Starting OData Fetch Loop ---")
    total_fetched_this_run = 0
    total_new_records = 0
    total_updated_records = 0

    for i in range(args.calls):
        current_skip = args.skip + (i * RECORDS_PER_CALL)
        print(f"\n--- Call {i+1}/{args.calls} (Skipping {current_skip}) ---")

        fetched_items = fetch_odata(
            BASE_OData_URL,
            args.table,
            filter_string,
            args.sort,
            current_skip,
            RECORDS_PER_CALL
        )

        if fetched_items is None:
            print("  Fetch failed for this call. Stopping.")
            break # Stop if fetch failed

        if not fetched_items:
            print("  No more items returned from OData service. Stopping.")
            break # Stop if no items returned

        print(f"  Fetched {len(fetched_items)} items.")
        total_fetched_this_run += len(fetched_items)

        # Process fetched items
        for item in fetched_items:
            if not isinstance(item, dict):
                print(f"  Warning: Fetched item is not a dictionary: {item}")
                continue
            if args.primary_key not in item:
                 print(f"  Warning: Primary key '{args.primary_key}' not found in fetched item. Skipping: {item}")
                 continue

            pk_value = item[args.primary_key]

            # Check if this primary key exists in our loaded data
            if pk_value in pk_lookup:
                existing_dyid_str = pk_lookup[pk_value]
                # Update existing record, but preserve original DYID
                item['DYID'] = int(existing_dyid_str) # Add DYID back (as int for consistency if needed, though key is string)
                data_dict[existing_dyid_str] = item
                total_updated_records += 1
            else:
                # Add as new record
                new_dyid = next_dyid
                new_dyid_str = str(new_dyid)
                item['DYID'] = new_dyid
                data_dict[new_dyid_str] = item
                pk_lookup[pk_value] = new_dyid_str # Update lookup for subsequent fetches in this run
                total_new_records += 1
                next_dyid += 1

        # Optional: Add delay only if more calls are expected and data was received
        if i < args.calls - 1 and fetched_items:
            print(f"  Waiting {DELAY_BETWEEN_CALLS_SEC} second(s)...")
            time.sleep(DELAY_BETWEEN_CALLS_SEC)

    print("--- OData Fetch Loop Finished ---")

    # 5. Save accumulated data
    print(f"\n--- Saving Data ---")
    print(f"Total fetched in this run: {total_fetched_this_run}")
    print(f"New records added: {total_new_records}")
    print(f"Existing records updated: {total_updated_records}")
    print(f"Total records in output file: {len(data_dict)}")
    print(f"Next DYID would be: {next_dyid}")

    try:
        with open(output_file_path, 'w', encoding='utf-8') as f:
            json.dump(data_dict, f, ensure_ascii=False, indent=4)
        print(f"Successfully saved data to: {output_file_path}")
    except Exception as e:
        print(f"Error saving data to {output_file_path}: {e}")

    print("--- Script Finished ---")


if __name__ == "__main__":
    main()