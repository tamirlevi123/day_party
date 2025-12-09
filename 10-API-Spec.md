## Minimal API Spec (v0)

Base URL: /api
Auth: Bearer JWT (issued after social login) unless noted.

### Votes

POST /nodes/{nodeId}/vote
- Body: { type: 'like' | 'dislike' | 'abstain', isPublic?: boolean }
- Rules: must be before voting_closes_at if set and changes not allowed after close; user can change vote if `voting_allow_change_until_close`.
- Returns: { nodeId, tallies: { like, dislike, abstain }, myVote: { type, isPublic } }

PATCH /nodes/{nodeId}/vote/visibility
- Body: { isPublic: boolean }
- Rules: must be before voting_closes_at if set; toggles visibility only.
- Returns: { nodeId, myVote: { type, isPublic } }

GET /nodes/{nodeId}/voters
- Query: ?type=like|dislike|abstain&limit&cursor
- Returns: { voters: [{ userId, displayName }], nextCursor }
- Rules: returns only votes where is_public=true.

### Deadlines (Admin only; node must be root)

PATCH /nodes/{nodeId}/deadline
- Body: { votingClosesAt: datetime | null }
- Auth: admin only.
- Returns: { nodeId, votingClosesAt }

### Notifications

GET /notifications
- Returns: { items: [{ id, type, payload, createdAt, isRead }], nextCursor }

PATCH /notifications/{id}
- Body: { isRead: boolean }
- Returns: { id, isRead }

### Auth (Social / Google)

POST /auth/social/start
- Body: { provider: 'google' | 'facebook' | 'apple', redirectUri }
- Returns: { authorizationUrl }

POST /auth/social/callback
- Body: { provider, code, redirectUri }
- Returns: { token, user: { id, displayName, role } }

POST /auth/logout
- Header: Authorization: Bearer
- Returns: 204

#### Provider notes (Google first)
- Protocol: OpenID Connect (OAuth 2.0 Authorization Code with PKCE)
- Scopes: 'openid email profile'
- Tokens: Access JWT (exp ~1h), Refresh token (rotating, exp ~30d)
- Security: PKCE required on mobile; state param enforced; strict redirect URI allowlist
- Account linking: If Google email matches an existing user, link identity after ownership check

#### Android Auth UI flow
1) App calls POST /auth/social/start with provider 'google' and app redirect URI (e.g., dayparty://auth/callback)
2) Open Custom Tabs to authorizationUrl
3) Provider redirects to app via deep link (intent filter for scheme host path)
4) App extracts code, calls POST /auth/social/callback with code and redirectUri
5) Backend verifies code, issues JWT + refresh; app stores securely (EncryptedSharedPreferences)
6) For logout, call POST /auth/logout and clear tokens locally

Deep link example (AndroidManifest):
scheme: dayparty  host: auth  pathPrefix: /callback

### Threads

POST /threads
- Body: { topicId, title, description? }
- Auth: Required
- Rules: `topicId` must reference an existing topic. `title` is required, max 500 characters. `description` is optional.
- Returns: { threadId, topicId, title, description, status, createdAt }

GET /threads/{threadId}
- Returns: { thread: { threadId, topicId, title, description, status, createdAt }, nodes: [...] }
- Returns thread with all its nodes (excluding deleted nodes)

GET /threads/{threadId}/nodes
- Returns: [{ nodeId, threadId, parentNodeId, parentRelation, title, textContent, video, author, voteTallies, createdAt, ... }]
- Returns all nodes for a thread (excluding deleted nodes)

### Nodes

POST /nodes
- Body:  
  ```
  {
    threadId,
    parentNodeId?,
    parentRelation?: 'pro' | 'against' | 'neutral',
    title,
    textContent?,
    video?: {
      source: 'upload' | 'external',
      uploadId?: string,           // Drive object reference when source='upload'
      externalUrl?: string,        // e.g., https://youtu.be/...
      provider?: 'youtube' | 'vimeo' | 'other'
    },
    isAnonymous?: boolean
  }
  ```
- Rules: parentRelation required if parentNodeId provided (must be 'pro', 'against', or 'neutral'). parentRelation must be NULL for root nodes (when parentNodeId is null). `video` object optional; when provided, exactly one of `uploadId` or `externalUrl` must be present. For known providers (YouTube/Vimeo) backend derives provider metadata and stores embed HTML.
- Returns: { nodeId, threadId, parentNodeId, parentRelation, title, textContent, video, author, createdAt }

PATCH /nodes/{nodeId}
- Body: { title?, textContent?, video?: { source, uploadId?, externalUrl?, provider? }, parentRelation?: 'pro' | 'against' | 'neutral' }
- Rules: parentRelation can only be changed if node is a reply (has parentNodeId). Cannot add parentRelation to root node. Video updates follow same exclusivity rule (either switch to upload or external link). Setting `video` to null removes video.
- Returns: { nodeId, title, textContent, video, parentRelation, editedAt }

GET /nodes/{nodeId}
- Returns: { nodeId, threadId, parentNodeId, parentRelation, title, textContent, video: { source, url, provider, providerId, embedHtml, thumbnailUrl, durationSec }, author, voteTallies, createdAt }

### Video Metadata Helper

POST /videos/preview
- Body: { url }
- Returns: { provider: 'youtube' | 'vimeo' | 'other', providerId, normalizedUrl, title, description, durationSec?, thumbnailUrl, embedHtml }
- Rules: Requires auth; validates URL against allowlist; caches response for short TTL. Clients call before POST /nodes to show preview and capture metadata. Backend re-validates when saving node.

### Admin Endpoints (Admin Role Required)

All admin endpoints require authentication and admin role. Returns 403 if user is not admin.

#### Node Management

GET /admin/nodes
- Query params: `threadId?`, `authorId?`, `isDeleted?` (true/false), `moderationState?`, `limit?` (default: 50), `offset?` (default: 0)
- Returns: `{ nodes: [...], pagination: { total, limit, offset } }`
- Lists all nodes (including deleted) with optional filters

GET /admin/nodes/{nodeId}
- Returns: Full node object (including deleted nodes)
- Admin can view any node, including deleted ones

PATCH /admin/nodes/{nodeId}
- Body: `{ title?, textContent?, textFormat?, parentRelation?, moderationState?, isAnonymous?, video?: {...} }`
- Returns: Updated node object
- Admin can edit any field of any node, including moderation state
- Creates a version history entry with change summary "Admin edit"

DELETE /admin/nodes/{nodeId}
- Returns: `{ message: "Node deleted successfully", node: {...} }`
- Soft deletes the node (sets `isDeleted: true`, `moderationState: 'removed'`)
- Creates a version history entry with change summary "Admin deletion"

POST /admin/nodes/{nodeId}/restore
- Returns: `{ message: "Node restored successfully", node: {...} }`
- Restores a deleted node (sets `isDeleted: false`, `moderationState: 'visible'`)
- Creates a version history entry with change summary "Admin restoration"

### Common Errors
- 400: validation_error, bad_request
- 401: unauthorized
- 403: forbidden (admin access required)
- 404: not_found
- 409: conflict (e.g., vote closed)
- 422: unprocessable (e.g., not a root node for deadline, invalid parentRelation for node type)


