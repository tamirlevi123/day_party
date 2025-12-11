import sqlite3
import json
import os
from pathlib import Path
import logging
import time # Import time for performance measurement
from collections import OrderedDict # Import OrderedDict

# Configure logging
# Increase level to DEBUG to see detailed insertion logs if needed
logging.basicConfig(level=logging.DEBUG, format='%(asctime)s - %(levelname)s - %(message)s')

# Constants
DATA_DIR = Path(__file__).parent / 'data'
DB_PATH = Path(__file__).parent.parent / 'data' / 'knesset_data.db'  # Output to backend/data/
SAMPLE_SIZE = 100 # Number of records to sample for schema inference

def infer_sqlite_type(value):
    """Infers SQLite data type from a Python value."""
    if isinstance(value, bool):
        return "INTEGER" # Store booleans as 0 or 1
    elif isinstance(value, int):
        return "INTEGER"
    elif isinstance(value, float):
        return "REAL"
    elif isinstance(value, str):
        # Could add checks for date/time formats here if needed
        return "TEXT"
    elif value is None:
        return None # Type cannot be determined from None alone
    else:
        # For lists, dicts, or other types, store as JSON string
        return "TEXT"

def infer_schema_from_json(json_file_path, sample_size=SAMPLE_SIZE):
    """Infers table schema from a JSON file, using the first key as the primary key."""
    logging.info(f"Inferring schema from {json_file_path.name}...")
    columns = OrderedDict() # Use OrderedDict to preserve key order from the first record
    primary_key = None
    first_record_keys = []
    first_record_processed = False

    try:
        with open(json_file_path, 'r', encoding='utf-8') as f:
            # Try to read the first object to detect if it's a list or single object
            # More robust check for empty file or whitespace
            first_bytes = f.read(2).strip()
            f.seek(0) # Reset pointer after reading

            if not first_bytes:
                logging.warning(f"File {json_file_path.name} appears to be empty. Skipping.")
                return None, None

            first_char = first_bytes[0]

            if first_char == '[':
                # It's likely a list of objects
                data = json.load(f)
                if not isinstance(data, list):
                     logging.warning(f"Expected a list of objects in {json_file_path.name}, but found {type(data)}. Skipping schema inference for data population.")
                     return None, None
                records_to_sample = data[:sample_size]
            elif first_char == '{':
                 # It might be a single object or objects separated by newlines
                 logging.warning(f"{json_file_path.name} does not start with '['. Assuming newline-delimited JSON objects or single object for schema inference.")
                 try:
                     f.seek(0)
                     data = json.load(f) # Try loading the whole thing
                     if isinstance(data, dict):
                         logging.info(f"JSON in {json_file_path.name} is an object; inferring schema from its values.")
                         records_to_sample = list(data.values())[:sample_size] # Sample from the values
                     else: # If not dict, try line by line
                         f.seek(0)
                         records_to_sample = []
                         for i, line in enumerate(f):
                             if i >= sample_size: break
                             try: records_to_sample.append(json.loads(line))
                             except json.JSONDecodeError: logging.warning(f"Could not decode line {i+1} in {json_file_path.name} during sampling. Skipping."); continue
                         if not records_to_sample:
                             logging.error(f"Could not parse {json_file_path.name} as JSON objects for sampling. Skipping.")
                             return None, None

                 except json.JSONDecodeError:
                     logging.error(f"Failed to decode JSON from {json_file_path.name} during sampling. Skipping.")
                     return None, None
            else:
                logging.warning(f"Unrecognized JSON structure in {json_file_path.name} (starts with '{first_char}'). Skipping.")
                return None, None

        if not records_to_sample:
            logging.warning(f"No records found or sampled in {json_file_path.name}. Skipping.")
            return None, None

        # Gather all keys and infer types from the sample
        all_keys = set()
        # Process the first record to establish key order and identify the first key
        if records_to_sample and isinstance(records_to_sample[0], dict):
             first_record_keys = list(records_to_sample[0].keys())
             if first_record_keys:
                 primary_key_candidate = first_record_keys[0] # FIRST key is the candidate
                 logging.info(f"Setting '{primary_key_candidate}' as primary key candidate for {json_file_path.name}.")
                 potential_primary_keys = {primary_key_candidate} # Only consider the first key
             else:
                 potential_primary_keys = set()
             first_record_processed = True
             all_keys.update(first_record_keys)

        # Update all_keys with keys from the rest of the sample
        for record in records_to_sample[1:]:
            if isinstance(record, dict):
                all_keys.update(record.keys())

        # Use the order from the first record if available, otherwise use sorted keys
        ordered_keys = first_record_keys if first_record_processed else sorted(list(all_keys))

        # Determine data types by checking values across the sample
        for key in ordered_keys:
            sql_type = None
            all_types_observed = set()
            has_non_null = False
            for record in records_to_sample:
                 if isinstance(record, dict) and key in record:
                     value = record[key]
                     current_type = infer_sqlite_type(value)
                     if current_type:
                        all_types_observed.add(current_type)
                        has_non_null = True

            if not has_non_null:
                 sql_type = "TEXT" # Default to TEXT if only nulls found
            elif len(all_types_observed) == 1:
                 sql_type = all_types_observed.pop()
            elif all_types_observed == {"INTEGER", "REAL"}:
                 sql_type = "REAL" # Promote INT to REAL if both are present
            else:
                 # If mixed types (e.g., INT and TEXT), default to TEXT
                 sql_type = "TEXT"

            columns[key] = sql_type

        # Validate the primary key candidate (must be the first key)
        if potential_primary_keys:
            pk_candidate = potential_primary_keys.pop()
            if columns.get(pk_candidate) not in ("INTEGER", "REAL"):
                logging.warning(f"Designated primary key '{pk_candidate}' (first column) in {json_file_path.name} is not INTEGER/REAL ({columns.get(pk_candidate)}). Treating as standard column.")
                primary_key = None
            else:
                # Explicitly set the type to INTEGER for the PK if it was REAL
                columns[pk_candidate] = "INTEGER"
                primary_key = pk_candidate
                logging.info(f"Confirmed '{primary_key}' as primary key for {json_file_path.name}.")
        else:
            primary_key = None # No valid first key found or it wasn't suitable


        return columns, primary_key

    except FileNotFoundError:
        logging.error(f"File not found: {json_file_path}")
        return None, None
    except json.JSONDecodeError as e:
        logging.error(f"Error decoding JSON during schema inference from {json_file_path}: {e}")
        return None, None
    except Exception as e:
        logging.error(f"An unexpected error occurred processing {json_file_path} during schema inference: {e}", exc_info=True)
        return None, None


def create_table_statement(table_name, columns, primary_key=None):
    """Generates a CREATE TABLE SQL statement, adding UNIQUE constraint for DYID in _KNS_Person."""
    if not columns:
        return None

    column_defs = []
    # Use the order from OrderedDict
    for name, dtype in columns.items():
        col_def = f'"{name}" {dtype}'
        if name == primary_key:
            col_def += " PRIMARY KEY"
        # Add UNIQUE constraint for DYID in the _KNS_Person table
        if table_name == "_KNS_Person" and name == "DYID":
             col_def += " UNIQUE"
             logging.info(f"Added UNIQUE constraint to DYID column in {table_name}")

        column_defs.append(col_def)

    # Build the statement parts separately for clarity
    # Use simple comma and space separation, no literal newlines
    columns_sql = ", ".join(column_defs)
    statement = f'CREATE TABLE IF NOT EXISTS "{table_name}" ({columns_sql});' # Removed \n
    return statement

def populate_table_from_json(conn, cursor, table_name, json_file_path, columns):
    """Populates a table with data from a JSON file, with enhanced logging."""
    logging.info(f"--- Starting population for table '{table_name}' from {json_file_path.name} ---")
    start_time = time.time()
    inserted_count = 0
    processed_count = 0
    error_count = 0

    if not columns:
        logging.error(f"Cannot populate table '{table_name}', schema (columns) information is missing.")
        return

    # Prepare column names and placeholders for the INSERT statement
    # Use the order from the OrderedDict schema
    column_names = list(columns.keys())
    quoted_column_names = [f'"{name}"' for name in column_names]
    placeholders = ", ".join(["?"] * len(column_names))
    sql_insert = f'INSERT OR IGNORE INTO "{table_name}" ({", ".join(quoted_column_names)}) VALUES ({placeholders})'
    logging.debug(f"Using SQL for insertion into {table_name}: {sql_insert}")
    # Using INSERT OR IGNORE to skip rows that violate constraints (like duplicate primary keys)

    try:
        with open(json_file_path, 'r', encoding='utf-8') as f:
            # Read the entire file - handle list, single object, or newline-delimited
            try:
                raw_data = json.load(f)
                if isinstance(raw_data, list):
                    data = raw_data
                elif isinstance(raw_data, dict):
                    logging.info(f"JSON in {json_file_path.name} is an object; processing its values.")
                    data = list(raw_data.values()) # Get records from the values
                else:
                     logging.error(f"Unexpected data type loaded from {json_file_path.name}: {type(raw_data)}. Expected list or dict.")
                     return # Cannot proceed
            except json.JSONDecodeError:
                 # If loading as a single JSON object/list fails, try line-by-line
                 logging.warning(f"Could not load {json_file_path.name} as a single JSON list/object. Attempting line-by-line reading.")
                 f.seek(0) # Reset file pointer
                 data = []
                 line_num = 0
                 for line in f:
                    line_num += 1
                    line = line.strip()
                    if not line: continue # Skip empty lines
                    try:
                        data.append(json.loads(line))
                    except json.JSONDecodeError as line_e:
                         logging.error(f"Error decoding JSON on line {line_num} in {json_file_path.name}: {line_e}. Skipping line.")
                         error_count += 1
                         continue # Skip this line

            if not data:
                 logging.warning(f"No data loaded or parsed from {json_file_path.name}. Nothing to insert into '{table_name}'.")
                 return

            total_records = len(data)
            logging.info(f"Found {total_records} records in {json_file_path.name} to process for table '{table_name}'.")

            # Prepare data for bulk insertion if possible, or row-by-row
            rows_to_insert = []
            for i, record in enumerate(data):
                processed_count += 1
                if not isinstance(record, dict):
                    logging.warning(f"Skipping non-dictionary item #{i+1} in {json_file_path.name}: {record}")
                    error_count += 1
                    continue

                values = []
                valid_record = True
                for col_name in column_names:
                    value = record.get(col_name) # Use .get() for safety, defaults to None
                    col_type = columns[col_name]

                    # Convert complex types stored as TEXT back to JSON strings
                    if col_type == "TEXT" and not isinstance(value, (str, type(None))):
                        try:
                            values.append(json.dumps(value))
                        except TypeError:
                            logging.warning(f"Could not serialize value for column '{col_name}' in table '{table_name}' (Record #{i+1}). Inserting NULL. Value: {value}")
                            values.append(None)
                            error_count += 1
                            # Decide if this error makes the whole record invalid or just this column
                            # valid_record = False; break # Uncomment to skip entire record on serialization error
                    # Handle boolean conversion explicitly
                    elif col_type == "INTEGER" and isinstance(value, bool):
                         values.append(1 if value else 0)
                    else:
                        values.append(value)

                if valid_record:
                    rows_to_insert.append(tuple(values))
                    # Log first few records prepared for insertion
                    if i < 3: # Log only the first 3
                         logging.debug(f"Prepared row {i+1} for {table_name}: {tuple(values)}")
                else:
                    logging.warning(f"Skipping record #{i+1} due to processing errors.")


            # Execute insertion
            if rows_to_insert:
                logging.info(f"Attempting to insert {len(rows_to_insert)} rows into '{table_name}'...")
                inserted_count = -1 # Initialize with -1 as it might be unreliable
                try:
                    cursor.executemany(sql_insert, rows_to_insert)
                    # executemany rowcount is often unreliable (-1 or total attempted) with INSERT OR IGNORE.
                    inserted_count = cursor.rowcount # Get the potentially unreliable rowcount
                    conn.commit()
                except sqlite3.Error as e:
                    logging.error(f"Database error during bulk insert into '{table_name}': {e}")
                    conn.rollback() # Rollback on error
                    error_count += len(rows_to_insert) # Assume all failed if bulk insert fails
            else:
                 logging.warning(f"No valid rows prepared for insertion into '{table_name}'.")


    except FileNotFoundError:
        logging.error(f"File not found during population: {json_file_path}")
        return # Cannot proceed
    except Exception as e:
        logging.error(f"An unexpected error occurred processing {json_file_path} during data population for table '{table_name}': {e}", exc_info=True)
        error_count = total_records if 'total_records' in locals() else error_count + 1 # Estimate errors if load fails completely

    end_time = time.time()
    duration = end_time - start_time
    logging.info(f"--- Finished populating table '{table_name}' in {duration:.2f} seconds ---")
    # Log the reported rowcount, acknowledging potential inaccuracy with INSERT OR IGNORE
    logging.info(f"    Processed: {processed_count}, Cursor reported {inserted_count} rows affected (may be -1 or total attempted with INSERT OR IGNORE), Errors/Skipped: {error_count}")


def main():
    logging.info("Starting database initialization...")
    # Ensure data directory exists
    DATA_DIR.mkdir(parents=True, exist_ok=True)

    # Delete existing database file if it exists, to start fresh
    if DB_PATH.exists():
        logging.info(f"Deleting existing database: {DB_PATH}")
        DB_PATH.unlink()

    # Connect to SQLite database (this will create the file if it doesn't exist)
    conn = sqlite3.connect(DB_PATH)
    cursor = conn.cursor()
    logging.info(f"Database connection established: {DB_PATH}")

    # Predefined Schemas (Fallback or for specific needs) - Keep these? Maybe remove if inference is primary
    # We will rely primarily on inference now.
    # predefined_schemas = { ... } # Removed for brevity, rely on inference


    try:
        # Process each JSON file in the data directory
        json_files = sorted(list(DATA_DIR.glob('_K*.json'))) # Process specific files first if needed
        logging.info(f"Found {len(json_files)} JSON files matching pattern in {DATA_DIR}.")

        for json_file in json_files:
            table_name = json_file.stem # Use filename without extension as table name

            # 1. Infer Schema
            columns, primary_key = infer_schema_from_json(json_file)

            if not columns:
                logging.warning(f"Could not infer schema for {json_file.name}. Skipping table creation and population.")
                continue

            # 2. Create Table
            create_sql = create_table_statement(table_name, columns, primary_key)
            if create_sql:
                logging.info(f"Executing CREATE TABLE statement for '{table_name}'...")
                logging.debug(f"Schema for {table_name}:\n{create_sql}")
                try:
                    cursor.execute(create_sql)
                    conn.commit()
                except sqlite3.Error as e:
                     logging.error(f"Failed to create table '{table_name}': {e}")
                     continue # Skip population if table creation failed
            else:
                logging.error(f"Could not generate CREATE TABLE statement for {table_name}.")
                continue

            # 3. Populate Table
            populate_table_from_json(conn, cursor, table_name, json_file, columns)

    except Exception as e:
        logging.error(f"An error occurred during the main processing loop: {e}", exc_info=True)
    finally:
        # Close the database connection
        if conn:
            conn.close()
            logging.info("Database connection closed.")

if __name__ == "__main__":
    main() 