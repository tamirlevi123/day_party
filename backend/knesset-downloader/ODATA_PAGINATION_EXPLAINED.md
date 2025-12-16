# OData Pagination: How Ordering and Skipping Work

## Basic Mechanics

### 1. Ordering (`$orderby`)

**Syntax:** `$orderby=<field> <direction>`

**Example:** `$orderby=DocumentBillID asc`

**What it does:**
- Orders ALL records in the table by the specified field
- `asc` = ascending (lowest to highest)
- `desc` = descending (highest to lowest)

**Result:** A sorted list of all records, e.g.:
```
[DocumentBillID: 75133, 75136, 75137, ..., 8611102, ..., 9065923, ...]
```

### 2. Skipping (`$skip`)

**Syntax:** `$skip=<number>`

**Example:** `$skip=100`

**What it does:**
- Skips the first N records from the **ordered result set**
- After ordering, skip removes the first N records
- Then returns the remaining records

**Example:**
- Ordered set: `[1, 2, 3, 4, 5, 6, 7, 8, 9, 10]`
- `$skip=3` → removes first 3 → `[4, 5, 6, 7, 8, 9, 10]`
- `$top=3` → takes first 3 → `[4, 5, 6]`

### 3. Top/Limit (`$top`)

**Syntax:** `$top=<number>`

**Example:** `$top=100`

**What it does:**
- Limits the number of records returned
- Applied AFTER skipping

## Complete Pagination Flow

### Step-by-Step Process:

1. **Order all records:** `$orderby=DocumentBillID asc`
   ```
   All records sorted: [ID1, ID2, ID3, ..., ID106711]
   ```

2. **Skip first N:** `$skip=89544`
   ```
   After skip: [ID89545, ID89546, ..., ID106711]
   ```

3. **Take next M:** `$top=100`
   ```
   Result: [ID89545, ID89546, ..., ID89644]
   ```

### Pagination Example:

```python
# Call 1: Get first 100 records
GET /KNS_DocumentBill?$orderby=DocumentBillID asc&$skip=0&$top=100
# Returns: Records 1-100 (by DocumentBillID order)

# Call 2: Get next 100 records  
GET /KNS_DocumentBill?$orderby=DocumentBillID asc&$skip=100&$top=100
# Returns: Records 101-200 (by DocumentBillID order)

# Call 3: Get next 100 records
GET /KNS_DocumentBill?$orderby=DocumentBillID asc&$skip=200&$top=100
# Returns: Records 201-300 (by DocumentBillID order)

# ... and so on
```

## How We Increase Skip

In our downloader, we increment skip like this:

```python
RECORDS_PER_CALL = 100

for i in range(total_calls_needed):
    skip = i * RECORDS_PER_CALL  # 0, 100, 200, 300, ...
    
    # Fetch batch
    batch = fetch_odata(
        table="KNS_DocumentBill",
        skip=skip,           # Increases: 0 → 100 → 200 → ...
        top=RECORDS_PER_CALL # Always 100
    )
```

**Example progression:**
- Call 1: `skip=0`   → Gets records 1-100
- Call 2: `skip=100`  → Gets records 101-200
- Call 3: `skip=200`  → Gets records 201-300
- Call 4: `skip=300`  → Gets records 301-400
- ...

## Why This Should Work

**In theory**, if:
1. OData `$count` returns 106,711
2. We order by `DocumentBillID asc`
3. We paginate with `skip=0, 100, 200, ..., 106600`
4. We should get all 106,711 unique records

**The problem we're seeing:**
- We can fetch 106,711 records via pagination ✅
- But they're all duplicates of our 89,544 records ❌
- This means we're getting the same records multiple times

## Possible Explanations

### Hypothesis 1: Duplicate DocumentBillIDs in OData
- OData might have duplicate DocumentBillIDs
- `$count` counts all rows (including duplicates)
- But when we deduplicate by DocumentBillID, we get fewer unique records

### Hypothesis 2: $count Includes Non-Fetchable Records
- `$count` might include:
  - Deleted records (soft deletes)
  - Records with null DocumentBillID
  - Records filtered out by OData security/permissions
- But these can't be fetched via normal queries

### Hypothesis 3: Pagination Ordering Issue
- The ordering might not be stable
- Records might appear in different positions on different calls
- This would cause us to see duplicates

## Testing Strategy

To verify which hypothesis is correct:

1. **Check for duplicates:** Fetch a large sample and check if DocumentBillID appears multiple times
2. **Check $count vs fetchable:** Try to fetch exactly `$count` records and see how many unique IDs we get
3. **Check ordering stability:** Fetch the same skip range multiple times and see if results are identical
