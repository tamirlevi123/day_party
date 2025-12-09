## Wireframes & Screen Specifications

Detailed wireframe descriptions for each screen in the Android MVP. These serve as specifications for implementation in Jetpack Compose.

### Wireframe Conventions

- **Spacing**: All measurements in dp (density-independent pixels)
- **Layout Direction**: Default LTR shown; RTL mirrors automatically
- **Elements**: Labeled with component types and key interactions
- **States**: Include loading, error, empty, and success states where relevant

---

### Authentication Flow

#### Screen 1: Splash Screen

**Purpose**: First screen on app launch, shows branding while checking auth state

**Layout**:
```
┌─────────────────────────┐
│                         │
│                         │
│    [App Logo/Icon]      │
│                         │
│   "Day Party"           │
│   מפלגת ד"י             │
│                         │
│                         │
│  [Loading indicator]    │
│                         │
└─────────────────────────┘
```

**Elements**:
- **Logo**: Centered, 120dp × 120dp
- **App Name**: Headline Medium, centered
- **Loading**: CircularProgressIndicator, 48dp, Primary Blue

**Behavior**:
- Auto-navigates after 1-2 seconds if user is authenticated (check token)
- Navigates to Onboarding if first launch
- Navigates to Main App if authenticated

**States**:
- Loading: Show spinner
- Error: Show error message, retry button

---

#### Screen 2: Onboarding/Welcome

**Purpose**: Introduce app, provide social login options

**Layout**:
```
┌─────────────────────────┐
│                         │
│    [App Logo]           │
│                         │
│  Welcome to Day Party   │
│  ברוכים הבאים למפלגת ד"י│
│                         │
│  Discuss and vote on    │
│  all matters            │
│                         │
│  [Google Sign In]       │ ← Primary Button
│                         │
│  [Facebook Sign In]     │ ← Secondary Button
│                         │
│  [Apple Sign In]        │ ← Secondary Button
│                         │
│                         │
│  Continue as Guest       │ ← Text Button
│                         │
└─────────────────────────┘
```

**Elements**:
- **Logo**: 100dp × 100dp, centered
- **Title**: Headline Large, centered
- **Description**: Body Large, centered, 2-3 lines max
- **Buttons**: Full width, 16dp margin horizontal, 12dp spacing vertical
- **Guest option**: Text Button, centered

**Behavior**:
- Tap social button → Opens Custom Tabs to provider OAuth
- Provider redirects to deep link → App handles callback
- Guest mode: Limited read-only access, prompt to login on vote/post

**States**:
- Default: Show all buttons
- Loading: Disable buttons, show progress on selected button
- Error: Show error snackbar, retry option

---

#### Screen 3: Social Auth Callback Handler

**Purpose**: Handles OAuth redirect, shows loading state (internal screen)

**Layout**: Similar to Splash, with "Signing you in..." message

**Behavior**:
- Receives deep link with OAuth code
- Calls `/auth/social/callback` API
- Stores JWT token in EncryptedSharedPreferences
- Navigates to Main App on success
- Shows error and returns to Onboarding on failure

---

### Main App Navigation

#### Screen 4: Main Container (Bottom Nav)

**Purpose**: Root container with bottom navigation

**Layout**:
```
┌─────────────────────────┐
│ [Top AppBar]            │
│                         │
│ [Screen Content Area]   │
│ (Home/Search/Activity/  │
│  Profile - see below)   │
│                         │
│                         │
│                         │
│                         │
│ ┌─────┬─────┬─────┬────┐│
│ │Home │Srch │Actv │Prof││ ← Bottom Navigation
│ └─────┴─────┴─────┴────┘│
└─────────────────────────┘
```

**Elements**:
- **Top AppBar**: Dynamic per screen (see individual screens)
- **Content**: Changes based on selected tab
- **Bottom Nav**: 4 tabs, always visible

**Navigation**:
- Tap tab → Switch content area (no back stack for bottom nav)
- Back button → Previous screen in current tab's stack

---

### Home/Feed Screens

#### Screen 5: Home Feed (Topics List)

**Purpose**: Show topics (categories) user can browse

**Layout**:
```
┌─────────────────────────┐
│ [≡] Day Party    [🔔]   │ ← Top AppBar
├─────────────────────────┤
│                         │
│  [Topic Card 1]         │
│  ┌───────────────────┐  │
│  │ 🏛️ National Issues │  │
│  │ 12 active threads │  │
│  └───────────────────┘  │
│                         │
│  [Topic Card 2]         │
│  ┌───────────────────┐  │
│  │ 🏘️ Local Issues    │  │
│  │ 5 active threads   │  │
│  └───────────────────┘  │
│                         │
│  [Topic Card 3]         │
│  ┌───────────────────┐  │
│  │ 📢 General         │  │
│  │ 23 active threads  │  │
│  └───────────────────┘  │
│                         │
│                         │
└─────────────────────────┘
```

**Elements**:
- **AppBar**: Title "Day Party", drawer menu, notifications icon
- **Topic Cards**: Standard Card, full width minus 16dp margin
- **Card Content**: Icon (32dp), Title (Headline Small), Subtitle (Body Medium)
- **Tap**: Navigate to Thread List for that topic

**States**:
- Loading: Skeleton loaders (3 cards)
- Empty: "No topics available" message
- Error: Error message, retry button

---

#### Screen 6: Thread List (within Topic)

**Purpose**: Show threads in selected topic, with filtering

**Layout**:
```
┌─────────────────────────┐
│ [←] National Issues      │ ← Top AppBar (back button)
├─────────────────────────┤
│ [New] [Hot] [Deadline]   │ ← Filter Tabs
├─────────────────────────┤
│                         │
│  [Thread Card 1]        │
│  ┌───────────────────┐  │
│  │ Economy Reform    │  │
│  │ Proposal: Tax...   │  │ ← Preview text
│  │                    │  │
│  │ 👤 42  💬 12       │  │ ← Vote count, reply count
│  │ ⏰ Closes: 2 days  │  │ ← Deadline (if set)
│  └───────────────────┘  │
│                         │
│  [Thread Card 2]        │
│  ┌───────────────────┐  │
│  │ Education Policy  │  │
│  │ Discussion about.. │  │
│  │                    │  │
│  │ 👤 89  💬 34       │  │
│  │ 🔥 Hot             │  │
│  └───────────────────┘  │
│                         │
└─────────────────────────┘
```

**Elements**:
- **Filter Tabs**: Horizontal scrollable chips/segments
- **Thread Cards**: Standard Card, clickable
- **Metadata**: Body Small text, icons 16dp

**Behavior**:
- Tap thread → Navigate to Thread Detail
- Filter tabs: Change sort order (API call)
- Pull to refresh: Reload threads

**States**:
- Filtering: Show loading on selected tab
- Empty: "No threads in this topic" message

---

#### Screen 7: Thread Detail

**Purpose**: Show root node and thread tree, enable voting/replying

**Layout**:
```
┌─────────────────────────┐
│ [←] Economy Reform [⋮]  │ ← Top AppBar (share menu)
├─────────────────────────┤
│                         │
│  [Root Node Card]       │
│  ┌───────────────────┐  │
│  │ 👤 Author Name    │  │
│  │ 📅 2 days ago     │  │
│  ├───────────────────┤  │
│  │ [Node Title]      │  │
│  │                   │  │
│  │ [Node Content]    │  │
│  │ Text and/or       │  │
│  │ embedded media    │  │
│  │                   │  │
│  ├───────────────────┤  │
│  │ [👍 42]    [8 👎] │  │ ← Vote tallies (Like left, Dislike right)
│  │ [👍]        [👎]  │  │ ← Vote buttons (if auth, icon-only, Like left, Dislike right)
│  │                   │  │
│  │ [Reply] Button    │  │
│  └───────────────────┘  │
│                         │
│  Replies (12)           │ ← Section header
│  ├─ [Reply Node Card 1] │ ← Expandable, indented 16dp
│  │  ┌───────────────────┐│
│  │  │ [PRO] 👤 Author   ││ ← Parent relation badge + author
│  │  │ 📅 1 hour ago      ││
│  │  ├───────────────────┤│
│  │  │ [Reply Content]   ││
│  │  └───────────────────┘│
│  │  └─ [Nested Reply]  │ ← Indented 32dp, shows [AGAINST/NEUTRAL]
│  ├─ [Reply Node Card 2] │
│  │  ┌───────────────────┐│
│  │  │ [AGAINST] 👤 User ││
│  │  │ 📅 2 hours ago     ││
│  │  └───────────────────┘│
│  └─ [Reply Node Card 3] │
│                         │
│  [+ Show More Replies]  │ ← Button to expand tree
│                         │
└─────────────────────────┘
```

- **Root Node**: Full card, prominent (no parent relation badge)
- **Embedded Media**: 16:9 player area supporting:
  - Uploaded video (Drive streaming)
  - External embeds (YouTube/Vimeo) rendered via WebView/YouTube Player with provider badge + "Open in YouTube" fallback
- **Reply Tree**: Collapsible, indented by level
- **Reply Node Headers**: Show parent relation badge (PRO/AGAINST/NEUTRAL) + author info
- **Vote Section**: Tally display + action buttons
  - Like (👍) buttons and tallies on LEFT
  - Dislike (👎) buttons and tallies on RIGHT
  - Abstain not displayed in UI (but tracked in backend)
- **FAB** (optional): Floating Action Button for "New Reply" (if long thread)

**Behavior**:
- Tap vote button → POST to API, update UI optimistically
- Vote layout: Like (👍) on left, Dislike (👎) on right
- Tap reply → Navigate to Create Node (pre-filled thread context)
- Tap node → Navigate to Node Detail
- Expand/collapse: Tap arrow icon or node header
- Long-press node → Context menu (edit if owner, report, share)

**States**:
- Loading node: Skeleton loader
- Voting: Disable buttons, show spinner
- Error: Snackbar with retry

---

#### Screen 8: Node Detail (Full Screen)

**Purpose**: Full-screen view of node with all actions

**Layout**:
```
┌─────────────────────────┐
│ [←] Node Title      [⋮] │ ← Top AppBar (edit/report/share menu)
├─────────────────────────┤
│                         │
│  👤 Author Name         │
│  📅 2 days ago          │
│  🔗 In: Economy Reform  │ ← Thread breadcrumb
│  [PRO]                  │ ← Parent relation badge (only if reply node, not root)
│                         │
│  [Node Title]           │ ← Headline Medium
│                         │
│  [Node Content Text]    │
│  ...full content...     │
│                         │
│  [Video Player]         │ ← If video attached or linked (inline 16:9)
│  [Source Badge]         │ ← e.g., "YouTube" chip when external
│  [Toggle: Text/Video]   │ ← If both
│                         │
│  ┌───────────────────┐  │
│  │ Vote Tally:        │  │
│  │ [👍 42]    [8 👎]  │  │ ← Like left, Dislike right
│  └───────────────────┘  │
│                         │
│  [👍]        [👎]      │ ← Vote action buttons (icon-only, Like left, Dislike right)
│                         │
│  [👁️ Show as Public]    │ ← Toggle (if voted)
│                         │
│  [📋 View Voters (42)]  │ ← Button (if public votes)
│                         │
│  ────────────────────── │
│                         │
│  [💬 Reply] Button      │
│                         │
│  Tree Navigation:       │
│  [← Parent] [→ Next]    │ ← Sibling navigation
│                         │
│  Related Replies (12)  │
│  [Reply preview cards  │
│   with PRO/AGAINST/    │
│   NEUTRAL badges]      │
│                         │
└─────────────────────────┘
```

**Elements**:
- **Video Player**: Media3 or embedded web player, full width, 16:9 aspect ratio
- **Source Badge**: Small chip above player when external (e.g., YouTube)
- **Open Externally Link**: Text button below player to launch provider app/site
- **Vote Section**: Prominent, card-style
  - Like (👍) buttons and tallies on LEFT
  - Dislike (👎) buttons and tallies on RIGHT
  - Abstain not displayed in UI (but tracked in backend)
- **Tree Navigation**: Bottom of content (if in tree)
- **Replies Preview**: Collapsed list, expand button

**Behavior**:
- Scrollable content (CoordinatorLayout/Column)
- Tap vote → Update immediately, show loading
- Vote layout: Like (👍) on left, Dislike (👎) on right
- Tap "View Voters" → Bottom sheet with voter list
- Tap reply → Navigate to Create Node
- Tree nav: Quick jump to parent/sibling (if applicable)

---

### Content Creation

#### Screen 9: Create/Edit Node

**Purpose**: Create new node or edit existing

**Layout**:
```
┌─────────────────────────┐
│ [←] Create Post    [X]   │ ← Top AppBar (cancel)
├─────────────────────────┤
│                         │
│  Title:                 │
│  ┌───────────────────┐  │
│  │ [Text Input]      │  │ ← Single line
│  └───────────────────┘  │
│                         │
│  Content:               │
│  ┌───────────────────┐  │
│  │                   │  │
│  │ [Multi-line Text] │  │
│  │                   │  │
│  │ (Markdown support)│  │
│  │                   │  │
│  └───────────────────┘  │
│                         │
│  Media:                 │
│  ┌───────────────────┐  │
│  │  [➕ Add Media]    │  │ ← Opens bottom sheet (upload vs link)
│  └───────────────────┘  │
│                         │
│  [Video: YouTube -    ] │ ← If linked (thumbnail + title + remove CTA)
│  [Video: upload.mp4]   │ ← If uploaded (file name + remove CTA)
│  [Preview player      ] │ ← Inline 16:9 preview when media selected
│                         │
│  Relation to parent:   │ ← Only shown if replying (not root)
│  (●) PRO  ( ) AGAINST  │ ← Radio buttons or segmented control
│  ( ) NEUTRAL           │
│                         │
│  [👤 Post Anonymously]  │ ← Toggle switch
│                         │
│  [Preview] Button       │ ← Secondary button
│                         │
│                         │
│  ┌───────────────────┐  │
│  │  [Post] Button    │  │ ← Primary, fixed bottom
│  └───────────────────┘  │
│                         │
└─────────────────────────┘
```

**Elements**:
- **Title Input**: Standard Input, single line
- **Content Input**: Text Area, min height 200dp
- **Media Card**: Outlined container with `Add Media` button
  - Tapping opens media source sheet with options:
    - Upload from device (reuse existing picker)
    - Paste external link (shows text field, paste button)
  - Once media is selected, show compact card with thumbnail, title, source icon, remove action, and inline preview (16:9)
- **Parent Relation Selector**: Radio buttons/segmented control (PRO/AGAINST/NEUTRAL) - only shown when replying, hidden for root nodes
- **Anonymous Toggle**: Switch component
- **Post Button**: Fixed at bottom (always visible), disabled until title/content filled and any external link validated

**Behavior**:
- Title required, min 3 chars
- Content required, min 10 chars
- Media optional. If user chooses:
  - **Upload**: prompt file picker (max 50MB, MP4). Show upload progress + success state.
  - **Link**: show paste field, auto-fetch preview via `/videos/preview`, display metadata + inline mini player before save.
- Validate external link before enabling Post (show errors in media card)
- **Parent relation**: Required if replying (PRO/AGAINST/NEUTRAL), hidden for root nodes
- Preview: Opens modal/sheet with formatted preview (includes embedded video/link preview)
- Post: Shows progress, navigates to Thread Detail on success
- Validation: Show errors inline

**States**:
- Creating: Disable inputs, show progress on Post button
- Error: Show error message, allow retry
- Success: Navigate away with success snackbar

---

### Search & Discovery

#### Screen 10: Search/Discover

**Purpose**: Search topics, threads, nodes; browse trending

**Layout**:
```
┌─────────────────────────┐
│ [←] Search              │ ← Top AppBar
├─────────────────────────┤
│ [🔍 Search...]          │ ← Search bar (prominent)
├─────────────────────────┤
│ Filters:                │
│ [All] [Topics] [Threads]│ ← Chips/filters
│ [Nodes]                 │
├─────────────────────────┤
│                         │
│  Results (23)           │ ← Result count
│                         │
│  [Result Card 1]        │
│  ┌───────────────────┐  │
│  │ Thread: Economy.. │  │
│  │ Matched: "tax"    │  │ ← Highlight match
│  │ 42 votes, 2 days  │  │
│  └───────────────────┘  │
│                         │
│  [Result Card 2]        │
│  ┌───────────────────┐  │
│  │ Node: Education.. │  │
│  │ Matched: "policy" │  │
│  │ 89 votes          │  │
│  └───────────────────┘  │
│                         │
└─────────────────────────┘
```

**Elements**:
- **Search Bar**: Prominent, 56dp height, search icon at start
- **Filters**: Horizontal scrollable chips
- **Results**: List of cards (thread or node cards)
- **Highlight**: Match text in bold/colored

**Behavior**:
- Real-time search (debounced 500ms)
- Tap result → Navigate to Thread Detail or Node Detail
- Clear button in search bar (when text entered)
- Empty state: "Try different keywords"

---

### User Activity

#### Screen 11: My Activity

**Purpose**: Show user's nodes, votes, replies

**Layout**:
```
┌─────────────────────────┐
│ [≡] My Activity         │ ← Top AppBar
├─────────────────────────┤
│ [My Posts] [My Votes]    │ ← Tabs
│ [Replies]               │
├─────────────────────────┤
│                         │
│  [Activity Item 1]      │
│  ┌───────────────────┐  │
│  │ 📝 My Post Title  │  │
│  │ In: Economy...    │  │
│  │ 👍 42 votes      │  │
│  │ 📅 2 days ago    │  │
│  └───────────────────┘  │
│                         │
│  [Activity Item 2]      │
│  ┌───────────────────┐  │
│  │ 👍 Voted: Tax...  │  │ ← Shows vote type
│  │ In: Economy...    │  │
│  │ 📅 1 day ago      │  │
│  └───────────────────┘  │
│                         │
└─────────────────────────┘
```

**Elements**:
- **Tabs**: 3 tabs (My Posts, My Votes, Replies)
- **Activity Cards**: Standard cards, clickable
- **Icon prefix**: Indicates type (📝 post, 👍 vote, 💬 reply)

**Behavior**:
- Switch tabs: Filter activity list
- Tap card: Navigate to Thread/Node Detail
- Empty state: "No activity yet. Create your first post!"

---

### Profile & Settings

#### Screen 12: Profile

**Purpose**: User profile, settings, logout

**Layout**:
```
┌─────────────────────────┐
│ [≡] Profile        [⋮]  │ ← Top AppBar (settings menu)
├─────────────────────────┤
│                         │
│    [Avatar]             │ ← 80dp circle, centered
│    Display Name         │ ← Headline Small
│    user@email.com       │ ← Body Medium
│                         │
│  ────────────────────── │
│                         │
│  📊 My Stats            │
│  Posts: 12  Votes: 89   │ ← Body Medium
│                         │
│  ────────────────────── │
│                         │
│  ⚙️ Settings            │ ← List item
│  🔔 Notifications       │ ← List item
│  🌐 Language: עברית     │ ← List item (if multi-lang)
│                         │
│  ────────────────────── │
│                         │
│  [🔧 Admin Panel]       │ ← If admin role
│                         │
│  ────────────────────── │
│                         │
│  [🚪 Logout]            │ ← Secondary button
│                         │
└─────────────────────────┘
```

**Elements**:
- **Avatar**: Placeholder or user image (if profile pics in MVP)
- **Stats**: Simple text display
- **Settings Items**: Standard list items with icons
- **Logout**: Bottom of screen, secondary style

**Behavior**:
- Tap settings items → Navigate to respective settings screens
- Tap logout → Confirm dialog → Clear tokens → Navigate to Onboarding
- Pull to refresh: Update stats

---

### Notifications

#### Screen 13: Notifications List

**Purpose**: Show user notifications

**Layout**:
```
┌─────────────────────────┐
│ [←] Notifications       │ ← Top AppBar
├─────────────────────────┤
│                         │
│  [Notification 1]       │
│  ┌───────────────────┐  │
│  │ 💬 New reply to  │  │
│  │ "Your Post"      │  │ ← Unread (bold)
│  │ 2 hours ago      │  │
│  └───────────────────┘  │
│                         │
│  [Notification 2]       │
│  ┌───────────────────┐  │
│  │ ⏰ Vote closing:  │  │ ← Read (normal)
│  │ Economy Reform   │  │
│  │ 1 day ago        │  │
│  └───────────────────┘  │
│                         │
│  [Notification 3]       │
│  ┌───────────────────┐  │
│  │ 📢 New thread     │  │
│  │ Education Policy  │  │
│  │ 3 days ago       │  │
│  └───────────────────┘  │
│                         │
└─────────────────────────┘
```

**Elements**:
- **Notification Cards**: Full width, clickable
- **Unread Indicator**: Bold text, or dot badge
- **Icon**: Type-specific (💬 reply, ⏰ deadline, 📢 announcement)

**Behavior**:
- Tap notification → Navigate to relevant Thread/Node
- Mark as read on tap (PATCH API)
- Pull to refresh
- Empty state: "No notifications"

**Notification Types** (from API spec):
- `node_reply`: Someone replied to your node
- `node_updated`: Node you voted on was edited
- `vote_closed`: Vote deadline reached
- `report_opened`: Admin opened your report (admin only)

---

### Modals & Sheets

#### Screen 14: Voter List Bottom Sheet

**Purpose**: Show public voters for a node

**Layout** (Bottom Sheet):
```
┌─────────────────────────┐
│  ═══                    │ ← Handle
├─────────────────────────┤
│  Voters (42)            │ ← Title
│  [Like] [Dislike] [All] │ ← Filter tabs (no Abstain shown)
├─────────────────────────┤
│  👤 User Name 1         │ ← List items
│  👤 User Name 2         │
│  👤 User Name 3         │
│  ...                    │
│                         │
└─────────────────────────┘
```

**Behavior**:
- Swipe down or tap outside to dismiss
- Filter tabs: Show only Like/Dislike/All voters (Abstain voters filtered out, not shown)
- Scrollable if many voters
- Tap user → Navigate to user profile (if profile exists in MVP)

---

#### Screen 15: Report Content Dialog
#### Screen 16: Add Media Sheet

**Purpose**: Let users choose how to attach video content to a node.

**Layout** (Bottom Sheet):
```
┌─────────────────────────┐
│  ═══                    │ ← Handle
├─────────────────────────┤
│  Add Media              │ ← Title
│  Choose how to attach:  │ ← Subtitle
├─────────────────────────┤
│  [📁 Upload from device]│ ← List item (opens picker)
│  [🔗 Paste link]        │ ← List item (expands to input field)
│                         │
│  Link input state:      │
│  ┌───────────────────┐  │
│  │ https://...       │  │ ← Text field + Paste button
│  └───────────────────┘  │
│  [Fetch preview] button  │
│  [Preview card]          │ ← Thumbnail, title, provider, remove
│                         │
│  [Cancel]    [Attach]   │ ← Buttons (Attach disabled until preview ready)
└─────────────────────────┘
```

**Behavior**:
- Upload option immediately opens Android file picker and dismisses sheet on success.
- Link option validates URL (allowlist), calls `/videos/preview`, shows loading spinner, then displays preview card with inline play.
- If preview fails, show error message inline and keep Attach disabled.
- Attach button inserts media card into Create/Edit screen; Cancel closes sheet with no changes.
- Removing media from Create/Edit screen clears selection so sheet can be reopened.


**Purpose**: Report inappropriate content

**Layout** (Dialog):
```
┌─────────────────────────┐
│  Report Content         │ ← Title
│                         │
│  Reason:                │
│  ( ) Spam               │ ← Radio buttons
│  ( ) Harassment         │
│  ( ) Misinformation     │
│  ( ) Other              │
│                         │
│  Additional notes:      │
│  ┌───────────────────┐  │
│  │ [Optional text]  │  │
│  └───────────────────┘  │
│                         │
│  [Cancel]  [Submit]     │ ← Buttons
└─────────────────────────┘
```

**Behavior**:
- Reason required
- Submit → POST to API → Show success → Dismiss
- Cancel → Dismiss without action

---

### Empty & Error States

#### Empty State Pattern

```
┌─────────────────────────┐
│                         │
│    [Empty Icon]         │ ← 64dp icon
│                         │
│  No [content type]      │ ← Body Large
│  [Helpful message]      │ ← Body Medium
│                         │
│  [Action Button]        │ ← If applicable
│                         │
└─────────────────────────┘
```

**Examples**:
- "No threads yet. Be the first to create one!"
- "No search results. Try different keywords."
- "No notifications"

#### Error State Pattern

```
┌─────────────────────────┐
│                         │
│    ⚠️                    │ ← Error icon
│                         │
│  Something went wrong   │ ← Body Large
│  [Error message]        │ ← Body Medium
│                         │
│  [Retry Button]         │ ← Primary button
│                         │
└─────────────────────────┘
```

---

### Interaction Specifications

#### Pull to Refresh
- **Trigger**: Pull down from top of scrollable content
- **Visual**: CircularProgressIndicator at top
- **Behavior**: Refresh current content (API call)

#### Swipe Actions (Future Enhancement)
- **Swipe right** (LTR): Bookmark/favorite (not in MVP)
- **Swipe left** (LTR): Quick actions menu (report, share)

#### Long-Press Menu
- **Nodes/Threads**: Context menu with options
  - Edit (if owner)
  - Report
  - Share
  - Copy link (if applicable)

#### Vote Feedback
- **Tap vote button**: Immediate visual feedback (ripple, scale)
- **Loading**: Disable buttons, show small spinner on button
- **Success**: Update tallies with count-up animation (500ms)
- **Error**: Show snackbar, revert UI state

---

### Responsive Considerations

#### Phone (Portrait)
- Single column layout
- Cards full width minus 16dp margins
- Bottom navigation always visible

#### Tablet (Landscape, Future)
- Two-column layout (if space > 840dp)
- Side navigation (drawer) instead of bottom nav
- Expanded tree views

---

### Implementation Notes

- **Compose Layouts**: Use `Column`, `Row`, `LazyColumn`, `Box`
- **Navigation**: Jetpack Navigation Compose
- **State Management**: ViewModel with StateFlow
- **Loading States**: Show skeleton loaders or progress indicators
- **Error Handling**: Snackbars for transient errors, full-screen for critical errors

---

### Version History

- **v0.1** (2025-01-27): Initial wireframe specifications
  - All main screens defined
  - Authentication flow
  - Core interaction patterns
  - Empty/error states

