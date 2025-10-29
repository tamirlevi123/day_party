## Information Architecture

This document defines the app structure, navigation, screens, and core user flows for the Android MVP.

### App Structure (High-Level)

```
Main Navigation (Bottom Nav)
├── Home (Topics/Threads feed)
├── Search/Discover
├── My Activity (user threads/nodes, votes)
└── Profile (settings, logout)
```

### Screen Inventory

#### Authentication Flow
1. **Splash/Onboarding** (first launch)
   - Welcome message
   - Social login buttons (Google, Facebook, Apple)

2. **Login/Social Auth**
   - Custom Tabs → provider → deep link callback
   - Account linking if email matches

3. **Main App** (after auth success)

#### Main Screens

1. **Home/Feed**
   - Topics list (categories)
   - Threads within selected topic
   - Root nodes (initial posts) in thread
   - Voting tallies visible
   - Thread filtering (new, hot, by deadline)

2. **Thread Detail**
   - Thread metadata (title, description, topic)
   - Root node (first post) with text/video
   - Replies as tree (expandable/collapsible)
   - Voting UI per node
   - Reply button (creates child node)

3. **Node Detail** (full screen from feed or thread)
   - Content (text/video, if both: toggle)
   - Voting interface (Like/Dislike/Abstain)
   - Vote visibility toggle (public/private)
   - Tree navigation (parent, siblings, children)
   - Reply button
   - Edit button (if author)
   - Share button

4. **Create/Edit Node**
   - Title input
   - Text editor (markdown/plain)
   - Video upload/picker
   - Anonymous toggle
   - Preview
   - Post/Update button

5. **Search/Discover**
   - Search bar (topics, threads, nodes)
   - Filters (by topic, date, vote count)
   - Results list

6. **My Activity**
   - Tabs: My Nodes, My Votes, My Replies
   - List of nodes user created or voted on
   - Quick navigation to threads

7. **Profile**
   - Display name, locale
   - Notification settings
   - Logout
   - Admin panel link (if admin)

8. **Notifications**
   - Drawer or dedicated screen
   - Types: node_updated, node_reply, report_opened, vote_closed
   - Mark read/unread

9. **Voter List** (for nodes with public votes)
   - Modal or bottom sheet
   - Filter by vote type (like/dislike/abstain)
   - User cards with display names

### Core User Flows

#### Flow 1: Onboarding & Login
```
Splash → Welcome/Onboarding → Choose Provider (Google/Facebook/Apple)
  → Custom Tabs → OAuth → Deep Link Callback → Main App
```

#### Flow 2: Browse & Discover
```
Home → Select Topic → Thread List → Thread Detail → Root Node
  → Expand Replies (tree navigation) → Node Detail
```

#### Flow 3: Vote on Node
```
Node Detail → Tap Like/Dislike/Abstain → Confirm
  → Vote visibility toggle (public/private) → Vote saved
  → Tallies update live
```

#### Flow 4: Create & Reply
```
Thread Detail → Tap Reply/New Post → Create Node Screen
  → Enter title → Upload text/video → (Optional: anonymous)
  → Post → Node appears in thread tree → Notifications sent
```

#### Flow 5: Edit Node
```
My Activity → My Nodes → Select Node → Edit → Update content
  → Save → Version created → Notifications to prior voters
```

#### Flow 6: Report Content
```
Node/Thread Detail → Menu → Report → Select reason → Submit
  → Admin notification → Admin reviews
```

#### Flow 7: Admin Set Deadline (root node only)
```
Admin Panel → Threads → Select Root Node → Set Deadline
  → voting_closes_at updated → UI shows countdown
```

### Navigation Patterns

#### Bottom Navigation (Primary)
- Home (topics/threads)
- Search
- My Activity
- Profile

#### Top Navigation (Secondary)
- Thread detail: Back, Thread title, Share
- Node detail: Back, Node title, Menu (edit/report/share)

#### Drawer/Side Menu
- Profile
- Notifications
- Settings
- Admin panel (if admin)
- Logout

### Information Hierarchy

```
Topics (High-Level Categories)
  └── Threads (Discussion Containers)
      └── Root Nodes (Initial Posts)
          ├── Text/Video Content
          ├── Voting UI (Like/Dislike/Abstain + tallies)
          ├── Replies (Tree Structure)
          │   ├── Child Node 1
          │   │   └── Grandchild Node 1.1
          │   └── Child Node 2
          └── Metadata (author, timestamp, deadline if root)
```

### Content Organization

#### Threads
- Sorted by: New, Hot (vote count), Deadline (upcoming first)
- Display: Title, description, node count, last activity

#### Nodes (Tree View)
- Root visible by default
- Replies collapsed (expand to view)
- Indentation shows hierarchy
- Vote count badges inline

#### Filtering & Sorting
- Topics: All, Recent, Most Active
- Threads: Open/Closed, By deadline, By activity
- Nodes: By votes, By recency, By replies

### User States & Permissions

#### Guest (Not Logged In)
- View threads and nodes (read-only)
- Cannot vote or post
- Prompt to login on action

#### Authenticated User
- Create nodes, vote, reply
- Edit own nodes
- Toggle vote visibility
- Report content

#### Admin
- All user capabilities
- Set/change deadlines (root nodes only)
- Moderate content (hide/remove)
- View and resolve reports
- Access admin panel

### Responsive Considerations (Future: Desktop)

- Mobile-first (current: Android only)
- Desktop: Multi-column layout, expanded tree views
- Tablet: Side-by-side thread + node detail

### Accessibility (RTL & A11y)

#### RTL Support
- Hebrew-first UI (locale: he-IL)
- Mirror navigation (right-to-left)
- Text alignment: auto-based on content language
- Icons/buttons flipped appropriately

#### Accessibility Features
- Screen reader support (content, voting, navigation)
- High contrast mode
- Font scaling
- Touch targets: min 44dp
- Color contrast: WCAG AA minimum

### Key Interaction Patterns

#### Voting
- Tap to vote (Like/Dislike/Abstain)
- Long-press to change visibility
- Vote tallies visible inline
- Public voter list (tap tally to view)

#### Tree Navigation
- Tap node to expand/collapse replies
- Swipe to navigate parent/sibling/child
- Breadcrumb trail for deep trees
- Jump to root button

#### Content Modalities
- If both text and video: toggle button
- Video: thumbnail + play overlay
- Text: formatted (markdown if applicable)
- Missing modality: "Generating..." indicator

### Next Steps

After IA approval, we'll create:
- Detailed wireframes for each screen
- Interaction specifications
- State diagrams for complex flows
- Design system foundations (components)

