## Analytics Plan

Analytics strategy, KPIs, events, and funnels for tracking user engagement and platform health in the Android MVP.

### Analytics Goals

**Primary Goals**:
1. **Understand user engagement**: How users interact with discussions and voting
2. **Measure adoption**: Registration, retention, active users
3. **Track content health**: Post quality, discussion depth, moderation needs
4. **Optimize features**: Identify friction points, drop-off areas
5. **Validate MVP success**: Achieve baseline metrics per Creative Brief targets

**Privacy Considerations**:
- Anonymous analytics (no PII in events)
- GDPR/Privacy Law compliance (user consent)
- Option to opt-out in settings
- Minimal data collection (only necessary events)

---

### Analytics Platform

**Decision**: Firebase Analytics (Google Analytics for Firebase)
- **Rationale**: 
  - Free tier sufficient for MVP
  - Built into Android ecosystem
  - Easy integration with Firebase (if used for push notifications later)
  - Privacy-compliant defaults
  - Custom events, funnels, cohorts

**Alternative Considered**: Mixpanel
- More expensive, better for advanced analytics (future consideration)

---

### Key Performance Indicators (KPIs)

#### User Acquisition KPIs
- **New Registrations** (Daily, Weekly, Monthly)
  - Target: TBD per Creative Brief (to be set post-MVP baseline)
  - Metric: `user_registered` event count

- **Registration Rate** (% of app opens → registrations)
  - Target: >10% conversion (industry baseline ~5-15%)
  - Calculation: `user_registered / app_opened` (for new users)

#### Engagement KPIs
- **Daily Active Users (DAU)**
  - Target: Baseline to be established after first 30 days
  - Metric: Unique users per day with any event

- **Weekly Active Users (WAU)**
  - Target: Baseline to be established
  - Metric: Unique users per week

- **Monthly Active Users (MAU)**
  - Target: Initial target TBD (per Creative Brief)
  - Retention: Target DAU/MAU ratio >20% (healthy engagement)

- **Posts Created** (Daily, Weekly)
  - Target: Baseline post-MVP (user-generated content)
  - Metric: `node_created` event count

- **Votes Cast** (Daily, Weekly)
  - Target: Baseline post-MVP
  - Metric: `vote_submitted` event count

- **Reply Rate** (% of nodes with at least 1 reply)
  - Target: >30% of root nodes have replies (healthy discussion)
  - Calculation: Nodes with `node_replied` / total root nodes

#### Quality KPIs
- **Average Reply Depth** (conversation depth)
  - Target: >1.5 levels average (indicating discussion, not just single replies)
  - Calculation: Average depth of reply tree per thread

- **Vote Participation Rate** (% of viewed nodes that receive votes)
  - Target: >15% (engagement threshold)
  - Calculation: Nodes with votes / nodes viewed

- **Session Duration**
  - Target: >3 minutes average (indicating engagement)
  - Metric: Average time between `session_start` and `session_end`

- **Screens per Session**
  - Target: >3 screens (exploration)
  - Metric: Unique screen views per session

#### Retention KPIs
- **Day 1 Retention** (% of new users who return next day)
  - Target: >40% (industry baseline 25-45%)
  - Calculation: Users active on day N+1 / new users on day N

- **Day 7 Retention** (Week 1 return rate)
  - Target: >20%
  - Calculation: Users active on day 7 / new users on day 0

- **Day 30 Retention** (Month 1 return rate)
  - Target: >10%
  - Calculation: Users active on day 30 / new users on day 0

#### Technical KPIs
- **App Crash Rate**
  - Target: <1% of sessions
  - Metric: Firebase Crashlytics

- **API Error Rate**
  - Target: <2% of API calls
  - Metric: Track `api_error` events

- **Loading Time** (key screens)
  - Target: <2 seconds for feed load
  - Metric: Custom timing events

---

### Event Tracking Strategy

#### Event Naming Convention
Format: `snake_case`, descriptive action verb + noun
- Pattern: `{action}_{object}` (e.g., `vote_submitted`, `node_created`)
- Consistency: Use same terms as domain (node, thread, vote)

#### Core Events

##### Authentication Events
| Event Name | Trigger | Parameters |
|------------|---------|------------|
| `app_opened` | App launch (cold start or background) | `source` (cold/background), `is_first_launch` (bool) |
| `onboarding_viewed` | Onboarding screen displayed | None |
| `login_started` | User taps social login button | `provider` (google/facebook/apple) |
| `login_completed` | OAuth callback successful, token received | `provider`, `login_method` (new/linking) |
| `login_failed` | OAuth failure or network error | `provider`, `error_type` (network/auth_error) |
| `user_registered` | First-time user account created | `provider`, `display_name_provided` (bool) |
| `logout` | User logs out | None |
| `guest_mode_entered` | User chooses "Continue as Guest" | None |

##### Navigation Events
| Event Name | Trigger | Parameters |
|------------|---------|------------|
| `screen_viewed` | Any screen displayed | `screen_name` (home/thread_detail/node_detail/etc) |
| `tab_selected` | Bottom nav tab tapped | `tab_name` (home/search/activity/profile) |
| `thread_opened` | User opens thread detail | `thread_id`, `topic_id`, `source` (home/search/etc) |
| `node_opened` | User opens node detail | `node_id`, `thread_id`, `is_root` (bool), `source` |

##### Content Creation Events
| Event Name | Trigger | Parameters |
|------------|---------|------------|
| `node_create_started` | Create Node screen opened | `context` (thread_id if replying, null if new root) |
| `node_created` | Node successfully posted | `node_id`, `thread_id`, `is_root` (bool), `has_video` (bool), `is_anonymous` (bool), `title_length` (int), `content_length` (int) |
| `node_create_cancelled` | User exits without posting | `had_content` (bool), `form_filled` (bool) |
| `node_create_failed` | Post API error | `error_type` (network/validation/server) |
| `node_edited` | User edits existing node | `node_id`, `edit_type` (title/content/video) |
| `video_upload_started` | User selects video to upload | `source` (picker/camera) |
| `video_upload_completed` | Video uploaded successfully | `file_size_mb` (float), `duration_sec` (int) |
| `video_upload_failed` | Video upload error | `error_type`, `file_size_mb` |

##### Voting Events
| Event Name | Trigger | Parameters |
|------------|---------|------------|
| `vote_button_tapped` | User taps Like/Dislike/Abstain | `node_id`, `vote_type` (like/dislike/abstain), `context` (node_detail/thread_detail) |
| `vote_submitted` | Vote successfully saved | `node_id`, `vote_type`, `is_public` (bool), `changed_from` (previous vote or null) |
| `vote_visibility_changed` | User toggles public/private | `node_id`, `new_visibility` (public/private) |
| `vote_failed` | Vote API error | `node_id`, `error_type` |
| `voter_list_opened` | User views public voters | `node_id`, `filter` (like/dislike/all) |

##### Engagement Events
| Event Name | Trigger | Parameters |
|------------|---------|------------|
| `reply_tapped` | User taps Reply button | `node_id`, `parent_node_id` (if replying to specific node) |
| `search_performed` | User submits search | `query_length` (int), `filter` (all/topics/threads/nodes), `result_count` (int) |
| `filter_applied` | User changes sort/filter | `screen` (thread_list/search), `filter_type` (new/hot/deadline), `filter_value` |
| `content_shared` | User shares node/thread | `content_type` (node/thread), `content_id`, `share_method` (if available) |
| `report_submitted` | User reports content | `content_type`, `content_id`, `reason` (spam/harassment/etc) |

##### Notification Events
| Event Name | Trigger | Parameters |
|------------|---------|------------|
| `notification_received` | Push notification received (if implemented) | `notification_type` (reply/vote_closed/etc) |
| `notification_opened` | User taps notification | `notification_type`, `navigated_to` (screen) |
| `notification_list_opened` | User opens notifications screen | None |

##### Admin Events (if admin role)
| Event Name | Trigger | Parameters |
|------------|---------|------------|
| `admin_panel_opened` | Admin opens admin panel | None |
| `deadline_set` | Admin sets voting deadline | `node_id`, `deadline_days` (int) |
| `content_moderated` | Admin hides/removes content | `content_type`, `content_id`, `action` (hide/remove), `reason` |

##### Performance Events
| Event Name | Trigger | Parameters |
|------------|---------|------------|
| `api_call` | Any API request | `endpoint`, `method` (GET/POST/etc), `status_code`, `response_time_ms` (int) |
| `api_error` | API returns error | `endpoint`, `status_code`, `error_type` |
| `screen_load_time` | Screen rendered | `screen_name`, `load_time_ms` (int) |
| `image_load_time` | Image loaded (Coil) | `source` (url/local), `load_time_ms` |
| `video_load_time` | Video ready to play | `video_id`, `load_time_ms` |

##### Error Events
| Event Name | Trigger | Parameters |
|------------|---------|------------|
| `error_occurred` | Any handled error | `error_type`, `screen`, `error_message` (sanitized, no PII) |
| `crash` | Unhandled exception (Crashlytics) | Auto-captured by Firebase |

---

### User Properties

**User Properties** (set once, used for segmentation):
- `user_id` (anonymous, UUID)
- `registration_date` (date registered)
- `total_posts` (int, updated incrementally)
- `total_votes` (int)
- `user_role` (user/admin)
- `locale` (he-IL/en-US/etc)
- `app_version` (for version-based analysis)

**Set on Events**:
- User properties updated when relevant events fire (e.g., `total_posts` on `node_created`)

---

### Funnels

#### Funnel 1: Registration Funnel
**Goal**: Understand drop-off in onboarding/login

1. `app_opened` (first launch)
2. `onboarding_viewed`
3. `login_started` (with provider)
4. `login_completed`
5. `user_registered` (or first login if existing)

**Expected Drop-off**:
- Step 2→3: ~30% (users exit)
- Step 3→4: ~10% (OAuth fails)
- Step 4→5: Auto (if new user)

**Optimization Targets**:
- Improve Step 2→3: Reduce onboarding friction
- Improve Step 3→4: Better error handling, retry options

#### Funnel 2: Content Creation Funnel
**Goal**: Understand why users abandon post creation

1. `node_create_started`
2. `title_entered` (implicit, track if form field focused)
3. `content_entered` (implicit)
4. `node_created` (success)

**Expected Drop-off**:
- Step 1→2: ~40% (immediate exit)
- Step 2→4: ~20% (form abandonment)

**Optimization Targets**:
- Auto-save drafts (future)
- Better UX for mobile text input

#### Funnel 3: Engagement Funnel
**Goal**: Measure progression from viewer to active participant

1. `screen_viewed` (home feed)
2. `thread_opened`
3. `node_opened`
4. `vote_button_tapped` OR `reply_tapped`
5. `vote_submitted` OR `node_created` (reply)

**Expected Progression**:
- Step 1→2: >50% (users browse)
- Step 2→3: >70% (users read)
- Step 3→4: >15% (users engage)
- Step 4→5: >90% (users complete action)

**Optimization Targets**:
- Improve Step 3→4: Make voting more prominent, reduce friction
- Improve Step 4→5: Optimize vote submission flow

#### Funnel 4: Search Funnel
**Goal**: Measure search effectiveness

1. `screen_viewed` (search)
2. `search_performed`
3. Result tapped (from search results)
4. `thread_opened` or `node_opened`

**Expected Progression**:
- Step 1→2: >60% (users search)
- Step 2→3: >40% (users find relevant results)
- Step 3→4: >80% (users open result)

**Optimization Targets**:
- Improve Step 2→3: Better search ranking, relevance

---

### Cohorts

**User Cohorts** (for retention analysis):

1. **Registration Cohort**: Group users by registration week/month
   - Track: Retention by cohort over time
   - Identify: Which cohorts retain better

2. **Activity Cohort**: Group users by first action type
   - Cohorts: Voted first, Posted first, Only browsed
   - Track: Which first action leads to best retention

3. **Engagement Cohort**: Group by activity level
   - Cohorts: High (10+ posts/votes), Medium (3-9), Low (1-2), Inactive (0)
   - Track: Retention by engagement level

---

### Reports & Dashboards

#### Daily Dashboard (for stakeholders)
- **User Metrics**: New registrations, DAU, WAU
- **Engagement**: Posts created, votes cast, active threads
- **Health**: Crash rate, API errors, session duration
- **Trends**: Day-over-day changes (up/down indicators)

#### Weekly Report
- **Retention**: Day 1, Day 7 retention rates
- **Quality**: Average reply depth, vote participation
- **Top Content**: Most active threads, highest voted nodes
- **Issues**: Error trends, user-reported problems

#### Monthly Review
- **Growth**: MAU, user acquisition trends
- **Engagement**: Depth of discussion, user lifetime value (proxy)
- **Technical**: Performance improvements, crash fixes
- **Goals**: Progress toward Creative Brief targets

---

### Privacy & Compliance

#### Data Collection Policy
- **Collected**: Anonymous user behavior, device info (OS version, app version), event timestamps
- **Not Collected**: PII (name, email), device identifiers (IMEI, serial), location (unless consent)
- **User Control**: Opt-out option in Profile settings

#### Consent Flow
1. **First Launch**: Show privacy notice (brief, clear)
2. **Consent**: "I agree" button (required for app use)
3. **Settings**: Toggle to disable analytics (post-MVP)

#### Data Retention
- **Event Data**: 14 months (Firebase default)
- **User Properties**: 14 months
- **Anonymization**: After 14 months, aggregate only

---

### Implementation Plan

#### Phase 1: MVP Launch (Weeks 1-4)
- **Set Up**: Firebase Analytics project
- **Integrate**: Add Firebase SDK to Android app
- **Core Events**: Track essential events (auth, navigation, voting, posting)
- **Basic Dashboard**: Create Firebase dashboard with key metrics

#### Phase 2: Baseline Establishment (Weeks 5-12)
- **Monitor**: Collect data without making changes
- **Analyze**: Identify trends, drop-off points
- **Report**: Weekly summaries for stakeholders
- **Set Targets**: Define success metrics based on actual data

#### Phase 3: Optimization (Post-MVP)
- **A/B Testing**: Test improvements based on funnel analysis
- **Advanced Events**: Add granular events for deeper insights
- **Custom Dashboards**: Build custom reports for specific questions

---

### Success Metrics (Post-MVP Baseline)

**To Be Set After First 30 Days**:
- Target DAU/WAU/MAU
- Target posts per day/week
- Target votes per day/week
- Retention benchmarks

**Validation Criteria**:
- Registration funnel: >10% conversion (app open → registration)
- Engagement funnel: >15% of node views result in votes
- Retention: >40% Day 1, >20% Day 7

---

### Event Implementation Checklist

**Android Implementation** (Firebase Analytics):

```kotlin
// Example event tracking
FirebaseAnalytics.getInstance(context).logEvent(
    FirebaseAnalytics.Event.SELECT_ITEM
) {
    param("item_name", "vote_like")
    param("node_id", nodeId)
}

// Custom event
val event = Bundle().apply {
    putString("node_id", nodeId)
    putString("vote_type", "like")
}
FirebaseAnalytics.getInstance(context).logEvent("vote_submitted", event)
```

**Backend Implementation**:
- Track API call events (timing, errors)
- Log server-side events if needed (e.g., scheduled job events)

---

### Version History

- **v0.1** (2025-01-27): Initial analytics plan
  - KPIs defined
  - Event catalog created
  - Funnels specified
  - Privacy considerations documented

