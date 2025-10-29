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

### Nodes

POST /nodes
- Body: { threadId, parentNodeId?, parentRelation?: 'pro' | 'against' | 'neutral', title, textContent?, videoUrl?, isAnonymous?: boolean }
- Rules: parentRelation required if parentNodeId provided (must be 'pro', 'against', or 'neutral'). parentRelation must be NULL for root nodes (when parentNodeId is null).
- Returns: { nodeId, threadId, parentNodeId, parentRelation, title, author, createdAt }

PATCH /nodes/{nodeId}
- Body: { title?, textContent?, videoUrl?, parentRelation?: 'pro' | 'against' | 'neutral' }
- Rules: parentRelation can only be changed if node is a reply (has parentNodeId). Cannot add parentRelation to root node.
- Returns: { nodeId, title, parentRelation, editedAt }

GET /nodes/{nodeId}
- Returns: { nodeId, threadId, parentNodeId, parentRelation, title, textContent, videoUrl, author, voteTallies, createdAt }

### Common Errors
- 400: validation_error
- 401: unauthorized
- 403: forbidden
- 404: not_found
- 409: conflict (e.g., vote closed)
- 422: unprocessable (e.g., not a root node for deadline, invalid parentRelation for node type)


