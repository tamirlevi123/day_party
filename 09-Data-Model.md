## Data Model (ERD + Draft Schemas)

This document outlines the core entities for the Android-first MVP and their relationships. Target DB: MySQL 8+.

### ERD (Overview)
```
Users (1) ──< TopicRoles >── (M) Topics
   │                         │
   └──< Threads >────────────┘
            │
          Nodes (tree: parent_node_id)
            │  ├─ modalities: text, video (one or both)
            │  └─ votes: like/dislike (per user, single)
            │
         NodeVersions (history per node)

Reports target: Threads | Nodes
Notifications -> Users
```

### Entities and Draft Tables

#### users
- id (pk, uuid)
- email (text, unique, nullable)
- phone (text, unique, nullable)
- password_hash (text, nullable)  // if using password auth; else auth_provider fields
- display_name (text)
- locale (text, default 'he-IL')
- is_active (boolean, default true)
- role (enum: 'user' | 'admin', default 'user')
- created_at (datetime, default current_timestamp)

#### user_identities
- id (pk, uuid)
- user_id (fk -> users.id)
- provider (text enum: 'google' | 'facebook' | 'apple')
- provider_user_id (text)
- email (text, nullable)
- display_name (text, nullable)
- access_token_last4 (text, nullable)
- refresh_token_last4 (text, nullable)
- created_at (datetime, default current_timestamp)

Unique constraints:
- unique(provider, provider_user_id)

Indexes:
- (user_id)

Unique constraints:
- one of email/phone must be present; enforce at app layer for now

Indexes:
- unique(email), unique(phone)

#### topics
- id (pk, uuid)
- name (text)
- description (text)
- visibility (text enum: 'public' | 'private', default 'public')
- created_by (fk -> users.id)
- created_at (datetime, default current_timestamp)

Indexes:
- (visibility)
- (created_by)

#### topic_roles
- id (pk, uuid)
- topic_id (fk -> topics.id)
- user_id (fk -> users.id)
- role (text enum: 'admin')  // moderation centralized to admins
- created_at (datetime, default current_timestamp)

Unique constraints:
- unique(topic_id, user_id, role)

#### threads
- id (pk, uuid)
- topic_id (fk -> topics.id)
- title (text)
- description (text, nullable)
- created_by (fk -> users.id)
- status (text enum: 'open' | 'closed', default 'open')
- created_at (datetime, default current_timestamp)

Indexes:
- (topic_id)
- (created_by)

#### nodes
- id (pk, uuid)
- thread_id (fk -> threads.id)
- parent_node_id (fk -> nodes.id, nullable)  // tree structure
- parent_relation (enum: 'pro' | 'against' | 'neutral', nullable)  // relation to parent (NULL for root nodes)
- title (text)
- text_content (text, nullable)
- text_format (text enum: 'markdown' | 'plain' | 'html' | 'delta', default 'plain')
- video_source (enum: 'upload' | 'external', default 'upload')  // identifies whether video is stored in Drive or linked
- video_url (text, nullable)  // storage location/URL (Drive URL or provider link)
- video_provider (enum: 'youtube' | 'vimeo' | 'other', nullable)  // only when video_source='external'
- video_provider_id (text, nullable)  // e.g., YouTube video ID
- video_embed_html (text, nullable)  // cached embed snippet (sanitized)
- video_metadata_json (json, nullable)  // cached provider metadata (title, duration, channel)
- video_duration_sec (int, nullable)
- video_thumbnail_url (text, nullable)  // CDN/Drive thumbnail or provider thumbnail
- text_language (text, nullable)  // e.g., 'he', 'en'
- text_confidence (numeric, nullable)  // if generated/transcribed
- text_status (text enum: 'provided' | 'generated' | 'missing', default 'missing')
- video_status (text enum: 'provided' | 'generated' | 'linked' | 'missing', default 'missing')
- moderation_state (text enum: 'visible' | 'limited' | 'hidden' | 'removed', default 'visible')
- is_anonymous (boolean, default false)
- author_id (fk -> users.id, nullable)  // nullable when anonymous
- is_deleted (boolean, default false)
- created_at (datetime, default current_timestamp)
- edited_at (datetime, nullable)

Voting configuration (per node):
- voting_enabled (boolean, default true)
 - voting_closes_at (datetime, nullable)  // applies only to root nodes (parent_node_id is null)
 - voting_required_quorum (int, nullable)  // minimum votes required; currently not enforced
 - voting_default_public (boolean, default false)  // default visibility for new votes
 - voting_eligibility_min_account_age_days (int, nullable)  // if set, new accounts younger than this cannot vote

Voting denormalized tallies (optional, update async):
- like_count (int, default 0)
- dislike_count (int, default 0)
- abstain_count (int, default 0)

Constraints:
- At creation, at least one of (text_content, video_url) should be non-null
  (enforced at application/service layer for simplicity in MVP).
- When `video_source='external'`, `video_provider` and `video_url` must be present; `video_provider_id` required for known providers (YouTube/Vimeo).
- When `video_source='upload'`, `video_provider*` fields must be null.

Indexes:
- (thread_id)
- (parent_node_id)
- (author_id)

#### node_versions
- id (pk, uuid)
- node_id (fk -> nodes.id)
- version_number (int)  // 1-based incremental
- title (text)
- text_content (text, nullable)
- text_format (text enum: 'markdown' | 'plain' | 'html' | 'delta')
- video_source (enum: 'upload' | 'external', nullable)
- video_url (text, nullable)
- video_provider (enum: 'youtube' | 'vimeo' | 'other', nullable)
- video_provider_id (text, nullable)
- video_embed_html (text, nullable)
- video_metadata_json (json, nullable)
- video_duration_sec (int, nullable)
- video_thumbnail_url (text, nullable)
- text_language (text, nullable)
- text_confidence (numeric, nullable)
- text_status (text enum: 'provided' | 'generated' | 'missing')
- video_status (text enum: 'provided' | 'generated' | 'linked' | 'missing')
- moderation_state (text enum: 'visible' | 'limited' | 'hidden' | 'removed')
- edited_by (fk -> users.id, nullable)  // uploader or moderator
- edited_at (datetime, default current_timestamp)
- change_summary (text, nullable)

Unique constraints:
- unique(node_id, version_number)

Indexes:
- (node_id, version_number desc)

#### node_votes
- id (pk, uuid)
- node_id (fk -> nodes.id)
- user_id (fk -> users.id)
- type (text enum: 'like' | 'dislike' | 'abstain')
- created_at (datetime, default current_timestamp)
 - is_public (boolean, default false)
 - updated_at (datetime, default current_timestamp)

Unique constraints:
- unique(node_id, user_id)  // one vote per user per node; toggling updates type

Indexes:
- (node_id)
- (user_id)
 - (node_id, is_public)

// Polls removed in favor of node-centric voting

#### reports
- id (pk, uuid)
- target_type (text enum: 'thread' | 'node')
- target_id (uuid)  // polymorphic
- reporter_id (fk -> users.id)
- reason (text)
- status (text enum: 'open' | 'reviewing' | 'resolved' | 'rejected', default 'open')
- created_at (datetime, default current_timestamp)
- resolved_by (fk -> users.id, nullable)
- resolved_at (datetime, nullable)

Indexes:
- (target_type, target_id)
- (status)

#### notifications
- id (pk, uuid)
- user_id (fk -> users.id)
- type (text)
- payload_json (json)
- is_read (boolean, default false)
- created_at (datetime, default current_timestamp)

Indexes:
- (user_id, is_read)

Notification types to consider:
- 'node_updated' — sent to users who reacted to the node previously
- 'node_reply' — sent to node author when someone replies (if not anonymous or if opted-in)
 - 'report_opened'/'report_resolved' — sent to admins for moderation lifecycle
 - 'node_vote_closed' — sent when a node's voting window closes (if configured)

#### modality_generation_jobs
- id (pk, uuid)
- node_id (fk -> nodes.id)
- target_modality (text enum: 'text' | 'video')
- source (text enum: 'ai' | 'human')
- status (text enum: 'queued' | 'in_progress' | 'succeeded' | 'failed')
- requested_by (fk -> users.id, nullable)
- created_at (datetime, default current_timestamp)
- completed_at (datetime, nullable)
- notes (text, nullable)

Indexes:
- (node_id, target_modality)

### Relationship Notes
- A `thread` belongs to a `topic`; users create `nodes` within threads.
- `nodes` form a tree via `parent_node_id`; replies are new nodes referencing a parent.
- A `poll` is attached to a `thread` for visibility and context.
- Moderation is scoped via `topic_roles` to allow distributed admin/moderator control.
- `reports` are polymorphic to handle issues across threads and nodes.
- `node_versions` store immutable snapshots for auditability and user notification context.
- Moderation is centralized to users with `role = 'admin'`.

### Data and Integrity Considerations
- Soft deletes on nodes preserve discussion history while hiding content.
- Enforce at least one modality at creation; allow generating the other later.
- Track provenance of generated modalities via `modality_generation_jobs`.
- RTL content: store as UTF-8 text; rendering is a client concern.
 - A user can always change their vote until `voting_closes_at` (policy: changes allowed before close).
- Maintain per-user uniqueness in `node_votes` (unique(node_id, user_id)).
- Denormalized counts on `nodes` should be recalculated or updated via write-through logic.
 - Per-vote visibility: store `is_public` on `node_votes`; default taken from `nodes.voting_default_public`. Users can flip visibility until close.
 - Deadlines: only root nodes may have `voting_closes_at`; replies inherit no deadline. Only Admins can set/change deadlines.
 - Quorum: `voting_required_quorum` is presently informational and not enforced in logic.
 - Tallies are always visible live (no hide-on-close behavior).
 - Eligibility: deny voting if account age < `voting_eligibility_min_account_age_days` when set.
- Voting integrity: rate-limit votes and ensure per-user uniqueness constraints.
- Privacy: allow anonymous nodes by leaving `author_id` null and marking `is_anonymous` true.
- On node update: create a new `node_versions` row and generate 'node_updated' notifications to prior reactors (from `node_reactions`).
- Consider opt-out preferences for notifications per user.


