# How Thread Cards Are Displayed - Complete Flow

## Overview
This document explains the complete flow of how thread cards are displayed in the Flutter app, from initial request to final rendering.

## Flow Diagram

```
Flutter App (ThreadListScreen)
    ↓
ThreadProvider.loadThreads()
    ↓
TopicService.getTopicThreads()
    ↓
HTTP GET /api/topics/:topicId/threads?statusID=114
    ↓
Backend: topic.controller.ts → getTopicThreads()
    ↓
Prisma: thread.findMany() + nodes (with metadataJson)
    ↓
For each thread:
  - Extract metadata.statusID from root node
  - Lookup statusDescription from in-memory cache
  - Enhance metadata with statusDescription
    ↓
Filter threads by statusID (if filter provided)
    ↓
Return JSON response with threads array
    ↓
Flutter: ThreadSummary.fromJson() → creates ThreadSummary objects
    ↓
ThreadListScreen: ListView.builder() → renders Card widgets
    ↓
Display: Shows title, description, statusDescription, billId, nodeCount
```

## Detailed Step-by-Step Flow

### 1. Flutter App Initialization (`thread_list_screen.dart`)

**Location:** `day_party_flutter/lib/screens/thread_list_screen.dart`

**What happens:**
- `ThreadListScreen` widget builds
- Creates `ThreadProvider` and `KnessetDatabaseProvider` via `MultiProvider`
- On first load (when `threads.isEmpty`), triggers `loadThreads()` with default filter `'114'`

**Code:**
```dart
if (provider.threads.isEmpty && !provider.isLoading) {
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (provider.statusFilter == null) {
      provider.setStatusFilter(topicId, '114', ...);
    } else {
      provider.loadThreads(topicId, ...);
    }
  });
}
```

### 2. ThreadProvider (`thread_provider.dart`)

**Location:** `day_party_flutter/lib/providers/thread_provider.dart`

**What happens:**
- `loadThreads()` is called with `topicId` and optional `statusIDs` filter
- Calls `TopicService.getTopicThreads()` with the filter
- Stores returned threads in `_threads` list
- Notifies listeners (UI rebuilds)

**Code:**
```dart
Future<void> loadThreads(String topicId, {List<ThreadSummary>? availableMemes}) async {
  _threads = await _topicService.getTopicThreads(topicId, statusIDs: _statusFilter);
  notifyListeners();
}
```

**Default Filter:** `_statusFilter = '114'` (statusID 114)

### 3. TopicService (`topic_service.dart`)

**Location:** `day_party_flutter/lib/services/topic_service.dart`

**What happens:**
- Makes HTTP GET request to `/topics/:topicId/threads`
- Adds `statusID` query parameter if filter is provided
- Parses JSON response into `ThreadsResponse`
- Returns list of `ThreadSummary` objects

**Code:**
```dart
Future<List<ThreadSummary>> getTopicThreads(String topicId, {String? statusIDs}) async {
  final queryParams = statusIDs != null ? {'statusID': statusIDs} : null;
  final response = await _dio.get('/topics/$topicId/threads', queryParameters: queryParams);
  final data = ThreadsResponse.fromJson(response.data);
  return data.threads;
}
```

**HTTP Request Example:**
```
GET /api/topics/{topicId}/threads?statusID=114
```

### 4. Backend Controller (`topic.controller.ts`)

**Location:** `backend/src/controllers/topic.controller.ts`

**What happens:**
- Receives request with `topicId` and optional `statusID` query param
- Parses comma-separated statusIDs (e.g., "114,115" → [114, 115])
- Verifies topic exists
- Fetches threads from database using Prisma

**SQL Query (via Prisma):**
```sql
SELECT 
  Thread.*,
  (SELECT COUNT(*) FROM Node WHERE Node.threadId = Thread.id) as nodeCount
FROM Thread
WHERE Thread.topicId = ? 
  AND Thread.status = 'open'
ORDER BY Thread.createdAt DESC

-- For each thread, also fetch root node metadata:
SELECT metadataJson 
FROM Node 
WHERE Node.threadId = ? 
  AND Node.parentNodeId IS NULL 
LIMIT 1
```

**Code:**
```typescript
const threads = await prisma.thread.findMany({
  where: { topicId: topicId, status: 'open' },
  include: {
    _count: { select: { nodes: true } },
    nodes: {
      where: { parentNodeId: null },
      select: { metadataJson: true },
      take: 1,
    },
  },
  orderBy: { createdAt: 'desc' },
});
```

### 5. Status Description Lookup (`knesset-status.service.ts`)

**Location:** `backend/src/services/knesset-status.service.ts`

**What happens:**
- For each thread, extracts `metadata.statusID` from root node
- Looks up status description from **in-memory cache** (no SQL query!)
- Cache was loaded at server startup from `_KNS_Status` table

**Status Cache Loading (at server startup):**
```sql
SELECT StatusID, `Desc`
FROM `_KNS_Status`
```

**Status Lookup (in-memory, no SQL):**
```typescript
const statusDescription = getStatusDescription(billStatusID);
// Returns: statusCache.get(statusID) || null
```

**Code:**
```typescript
// At server startup:
await loadStatusCache(); // Loads all statuses into Map<StatusID, Desc>

// For each thread:
const statusDescription = getStatusDescription(billStatusID);
```

### 6. Thread Formatting & Filtering

**Location:** `backend/src/controllers/topic.controller.ts`

**What happens:**
- Maps each thread to response format
- Enhances metadata with `statusDescription`
- Filters threads by `statusID` if filter provided
- Returns JSON response

**Code:**
```typescript
let formattedThreads = threads.map((thread) => {
  const metadata = thread.nodes[0]?.metadataJson;
  const billStatusID = metadata?.statusID;
  const statusDescription = getStatusDescription(billStatusID);
  
  return {
    threadId: thread.id,
    title: thread.title,
    description: thread.description,
    nodeCount: thread._count.nodes,
    metadata: { ...metadata, statusDescription },
  };
});

// Filter by statusIDs
if (statusIDs?.length > 0) {
  formattedThreads = formattedThreads.filter((thread) => {
    const billStatusID = thread.metadata?.statusID;
    return statusIDs.includes(billStatusID);
  });
}
```

**Response JSON Example:**
```json
{
  "threads": [
    {
      "threadId": "abc123",
      "title": "הצעת חוק...",
      "description": "...",
      "nodeCount": 3,
      "metadata": {
        "billId": 2194599,
        "statusID": 114,
        "statusDescription": "לדיון במליאה לקראת קריאה שנייה-שלישית"
      }
    }
  ]
}
```

### 7. Flutter Model Parsing (`thread.dart`)

**Location:** `day_party_flutter/lib/models/thread.dart`

**What happens:**
- `ThreadSummary.fromJson()` parses JSON response
- Extracts `metadata` object
- Provides getters: `billId`, `billStatusID`, `statusDescription`

**Code:**
```dart
class ThreadSummary {
  final Map<String, dynamic>? metadata;
  
  int? get billStatusID => metadata?['statusID'] as int?;
  int? get billId => metadata?['billId'] as int?;
  String? get statusDescription => metadata?['statusDescription'] as String?;
}
```

### 8. UI Rendering (`thread_list_screen.dart`)

**Location:** `day_party_flutter/lib/screens/thread_list_screen.dart`

**What happens:**
- `ListView.builder()` creates cards for each thread
- Each card displays:
  - Title (from `thread.title`)
  - Description preview (from `thread.description`)
  - Status badge (from `thread.statusDescription`)
  - Bill ID (from `thread.billId`)
  - Post count (from `thread.nodeCount`)

**Code:**
```dart
Card(
  child: ListTile(
    title: Text(thread.title),
    subtitle: Column(
      children: [
        if (thread.description != null)
          _buildDescriptionPreview(thread.description!),
        Wrap(
          children: [
            Text('${thread.nodeCount} posts'),
            if (thread.billId != null)
              Text('Bill ID: ${thread.billId}'),
            if (thread.statusDescription != null)
              Container(
                child: Text(thread.statusDescription!),
                // Blue badge styling
              ),
          ],
        ),
      ],
    ),
  ),
)
```

## SQL Queries Executed

### 1. Server Startup: Status Cache Loading
```sql
SELECT StatusID, `Desc`
FROM `_KNS_Status`
```
**When:** Once at server startup  
**Result:** Loaded into in-memory `Map<StatusID, Desc>`

### 2. Get Topic Threads
```sql
-- Prisma generates this query:
SELECT 
  Thread.id, Thread.topicId, Thread.title, Thread.description, 
  Thread.status, Thread.createdAt
FROM Thread
WHERE Thread.topicId = ? AND Thread.status = 'open'
ORDER BY Thread.createdAt DESC

-- For each thread, fetch root node metadata:
SELECT Node.metadataJson
FROM Node
WHERE Node.threadId = ? AND Node.parentNodeId IS NULL
LIMIT 1

-- Count nodes for each thread:
SELECT COUNT(*) as nodeCount
FROM Node
WHERE Node.threadId = ?
```

**When:** Every time `/api/topics/:topicId/threads` is called  
**Parameters:** `topicId` (from URL), `statusID` (from query param, optional)

## Key Points

1. **Status descriptions come from in-memory cache** - No SQL query per thread!
2. **Filtering happens server-side** - Only matching threads are returned
3. **Metadata is stored in root node** - Each thread's root node contains `metadataJson` with `billId` and `statusID`
4. **Default filter is '114'** - Applied on first load
5. **Status lookup is O(1)** - Uses Map lookup, very fast

## Debugging

All SQL queries and responses are now logged with `[SQL]` prefix. Check backend console for:
- `[SQL] Query: ...` - The SQL statement
- `[SQL] Params: ...` - Query parameters
- `[SQL] Duration: ...` - Query execution time
- `[TopicController]` - Thread processing logs
- `[KnessetStatus]` - Status cache operations
