## Design Principles

Core guardrails that guide design and development decisions for Day Party.

### 1. Accessibility First
**Why it matters**: To ensure the platform is inclusive and usable by all users, including those with disabilities. **Example**: All interactive elements meet WCAG AA contrast ratios (4.5:1 minimum), touch targets are minimum 48dp, screen reader support for all content and actions.

### 2. RTL Native Experience
**Why it matters**: Hebrew-first audience requires seamless right-to-left support. The app should feel native to RTL users, not like a translated LTR app. **Example**: Navigation drawers open from the right, back buttons flip, text alignment respects content language. All layouts use `start`/`end` properties, never `left`/`right`.

### 3. Clarity & Transparency
**Why it matters**: Trust requires clear communication. Users need to understand voting mechanisms, deadlines, and their own data. **Example**: Vote tallies are always visible, deadlines shown with clear countdowns, user's own votes clearly indicated, metadata (author, time) always accessible.

### 4. Neutral & Balanced Presentation
**Why it matters**: Political/civic platform must present information neutrally to avoid bias. **Example**: Vote tallies shown equally for all options, content sorted algorithmically (not by bias), moderation actions transparent to affected users.

### 5. Purposeful Design
**Why it matters**: Every design element should serve a clear purpose. Avoid decoration for decoration's sake. **Example**: Icons used only when they clarify meaning, colors have semantic meaning (green=like, red=dislike), animations guide attention rather than distract.

### 6. Mobile-First, Efficient Interactions
**Why it matters**: Android-first means optimizing for mobile constraints: small screens, thumb reach, one-handed use. **Example**: Primary actions within thumb zone, bottom navigation for major sections, swipe gestures for quick actions where appropriate.

### 7. Error Prevention & Recovery
**Why it matters**: Users make mistakes. Design should prevent errors and provide clear recovery paths. **Example**: Form validation with helpful error messages, confirmation dialogs for destructive actions, retry buttons on network errors, auto-save drafts (future).

### 8. Progressive Disclosure
**Why it matters**: Complex content (tree discussions) can overwhelm. Show what's necessary, reveal more on demand. **Example**: Reply trees collapsed by default, expand to see more, "show more" buttons for long threads, filters and sorting options clearly available but not prominent.

### 9. Performance & Responsiveness
**Why it matters**: Slow or unresponsive apps frustrate users and reduce trust. **Example**: Loading states for all async operations, optimistic UI updates for votes, skeleton screens instead of blank states, lazy loading for images/videos.

### 10. Consistent Language & Patterns
**Why it matters**: Consistency reduces cognitive load and builds user confidence. **Example**: Same button styles throughout, consistent terminology (node vs post used consistently), navigation patterns follow platform conventions, error messages use same tone.


