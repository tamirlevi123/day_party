## Design System

Foundational design tokens, components, and guidelines for the Android MVP. This system ensures consistency, accessibility, and RTL support throughout the app.

### Design Principles (from Brief)

**Tone & Brand Keywords:** Transparency, sensible, welcoming, engaging, clear, trustworthy, inclusive, neutral, practical.

**Core Principles:**
1. **Accessibility First** — WCAG AA minimum contrast, screen reader support, scalable fonts, 44dp min touch targets
2. **RTL Native** — Hebrew-first UI (he-IL locale), mirrored navigation, context-aware text alignment
3. **Clarity & Trust** — Neutral colors, clear typography, transparent information hierarchy
4. **Inclusive** — High contrast modes, multiple input methods, reduced motion support

---

### Color Palette

#### Primary Colors
- **Primary Blue**: `#1976D2` (Material Blue 700)
  - Primary actions, links, active states
  - Use for CTAs, voting buttons, active tabs
  - Contrast: 7:1 on white (WCAG AAA)

- **Primary Blue Dark**: `#1565C0` (Material Blue 800)
  - Hover/pressed states, primary buttons
  - Contrast: 8:1 on white (WCAG AAA)

- **Primary Blue Light**: `#42A5F5` (Material Blue 400)
  - Secondary actions, disabled primary elements
  - Use sparingly for accents

#### Secondary Colors
- **Success/Positive**: `#388E3C` (Material Green 700)
  - Like votes, positive feedback, success states
  - Contrast: 4.5:1 on white (WCAG AA)

- **Warning**: `#F57C00` (Material Orange 700)
  - Deadlines approaching, caution states
  - Contrast: 4.5:1 on white (WCAG AA)

- **Error/Negative**: `#D32F2F` (Material Red 700)
  - Dislike votes, errors, destructive actions
  - Contrast: 4.5:1 on white (WCAG AA)

#### Neutral Colors
- **Background Primary**: `#FFFFFF` (White)
  - Main screen backgrounds

- **Background Secondary**: `#F5F5F5` (Grey 100)
  - Card backgrounds, alternate list items, input fields

- **Surface**: `#FAFAFA` (Grey 50)
  - Elevated surfaces (cards, bottom sheets)

- **Divider**: `#E0E0E0` (Grey 300)
  - List separators, card borders

- **Text Primary**: `#212121` (Grey 900)
  - Main content text, headings
  - Contrast: 15.9:1 on white (WCAG AAA)

- **Text Secondary**: `#757575` (Grey 600)
  - Metadata, timestamps, helper text
  - Contrast: 4.6:1 on white (WCAG AA)

- **Text Disabled**: `#BDBDBB` (Grey 400)
  - Disabled buttons, inactive elements
  - Contrast: 3.1:1 on white (WCAG AA, large text only)

#### Semantic Colors (Voting)
- **Like/Upvote**: `#388E3C` (Green 700)
- **Dislike/Downvote**: `#D32F2F` (Red 700)
- **Abstain/Neutral**: `#757575` (Grey 600)
- **Vote Tally Background**: `#F5F5F5` (Grey 100)

#### Dark Mode (Future)
- Note: Dark mode support planned post-MVP but color tokens defined now
- Background: `#121212` (Material Dark Surface)
- Surface: `#1E1E1E`
- Text Primary: `#FFFFFF`
- Text Secondary: `#B3B3B3`

---

### Typography

#### Font Family
- **Primary**: Roboto (Android system font)
  - Best RTL support
  - Excellent Hebrew character rendering
  - Built-in Android support, no custom font loading needed

- **Monospace** (for code/technical content): Roboto Mono
  - Only if markdown code blocks are supported in MVP

#### Type Scale (Material Design 3)

**Display Large** — `Roboto Regular, 57sp/72dp line-height`
- Screen titles (sparingly)
- Large hero text

**Headline Large** — `Roboto Regular, 32sp/40dp line-height`
- Main screen titles
- Thread/node titles
- Use: Page titles in AppBar

**Headline Medium** — `Roboto Regular, 28sp/36dp line-height`
- Section headings
- Card titles

**Headline Small** — `Roboto Regular, 24sp/32dp line-height`
- Subsection headings
- Node content titles

**Title Large** — `Roboto Medium, 22sp/28dp line-height`
- Important labels
- Tab labels (active)

**Title Medium** — `Roboto Medium, 16sp/24dp line-height`
- Card action labels
- Button text (primary)

**Title Small** — `Roboto Medium, 14sp/20dp line-height`
- List item titles
- Secondary button text

**Body Large** — `Roboto Regular, 16sp/24dp line-height`
- Primary body text
- Node content
- Thread descriptions
- Default text size

**Body Medium** — `Roboto Regular, 14sp/20dp line-height`
- Secondary body text
- Metadata, timestamps
- Default for compact views

**Body Small** — `Roboto Regular, 12sp/16dp line-height`
- Captions, helper text
- Error messages
- Minimum readable size

**Label Large** — `Roboto Medium, 14sp/20dp line-height`
- Buttons, tabs, labels

**Label Medium** — `Roboto Medium, 12sp/16dp line-height`
- Small buttons, chips, tags

**Label Small** — `Roboto Medium, 11sp/16dp line-height`
- Micro-interactions, badges
- Minimum for interactive elements

#### RTL Typography Notes
- Default alignment: `start` (auto-flips in RTL)
- Hebrew text: Natural alignment (right-aligned)
- English/Latin: Left-aligned (mirrors to right in RTL)
- Mixed content: Detect language, align per segment

---

### Spacing & Layout

#### Spacing Scale (8dp base unit)
- **4dp** — Tiny spacing (icon padding, tight groups)
- **8dp** — Small spacing (between related elements)
- **16dp** — Medium spacing (standard gaps, card padding)
- **24dp** — Large spacing (section separation, list items)
- **32dp** — Extra large (screen edges, major sections)
- **48dp** — XXL spacing (between major content blocks)

#### Component Spacing
- **Card padding**: 16dp (all sides)
- **List item padding**: 16dp horizontal, 12dp vertical
- **Button padding**: 12dp horizontal, 16dp vertical (minimum)
- **Text input padding**: 16dp horizontal, 12dp vertical
- **Screen edge padding**: 16dp (24dp on tablets)

#### Grid System
- **Columns**: No fixed grid for mobile (use ConstraintLayout/Column in Compose)
- **Breakpoints** (future tablet/desktop): 600dp, 840dp, 1200dp
- **Content width**: Max 840dp centered (tablets/desktop)

---

### Components

#### Buttons

**Primary Button**
- Background: Primary Blue (`#1976D2`)
- Text: White, Title Medium (16sp, Medium weight)
- Padding: 24dp horizontal, 16dp vertical
- Min height: 48dp
- Corner radius: 4dp
- States: Enabled, Pressed (darker), Disabled (40% opacity)

**Secondary Button**
- Background: Transparent
- Border: 1dp, Primary Blue
- Text: Primary Blue, Title Medium
- Padding: 24dp horizontal, 16dp vertical
- Min height: 48dp
- Corner radius: 4dp

**Text Button**
- Background: Transparent
- Text: Primary Blue, Label Large (14sp, Medium)
- Padding: 12dp horizontal, 8dp vertical
- Min height: 40dp

**Icon Button** (FAB, vote buttons)
- Size: 48dp (touch target) / 40dp icon
- Background: Surface color with elevation
- Icon: 24dp, Primary Blue
- States: Elevated (6dp) when pressed

#### Cards

**Standard Card**
- Background: White (`#FFFFFF`)
- Elevation: 2dp (default), 8dp (pressed)
- Corner radius: 8dp
- Padding: 16dp
- Margin: 8dp between cards

**Node Card** (in thread/list)
- Same as standard card
- Indentation for hierarchy: 16dp per level (max 4 levels visible)
- Border left: 4dp, colored by vote tally (if voted)
**Media Attachment Card** (Create/Edit)
- Background: Grey 50 (`#FAFAFA`)
- Border: 1dp dashed, Primary Blue at 40% opacity when empty; solid Grey 300 when populated
- Padding: 16dp
- Layout:
  - Empty state: Centered icon (`add_circle`), Title Small text "Add media", helper text Body Small
  - Populated state: Row with provider icon, title, source chip, 16:9 thumbnail preview, remove icon button at end
- States:
  - **Valid external link**: Show provider chip (Primary Blue background, white text) + "Open preview" text button
  - **Error**: Border Red 700, helper text red, error icon
  - **Loading**: Replace preview with progress indicator, disable remove button

**Reply Node Header** (for reply nodes only, not root)
- Must display parent relation badge (PRO/AGAINST/NEUTRAL)
- Layout: Badge at start, followed by author info and timestamp
- Badge is first element in header row (before author name)

#### Voting Components
#### Media & Provider Badges

**Provider Chip**
- Background: Determined by provider
  - YouTube: `#FF0000`
  - Vimeo: `#1AB7EA`
  - Other: Primary Blue (`#1976D2`)
- Text: White, Label Medium (12sp)
- Icon: 16dp provider glyph to the start (mirrors in RTL)
- Padding: 8dp horizontal, 4dp vertical
- Border radius: 12dp (pill)
- Usage: Display above embedded player and inside media card to signal external source.

**Open Externally Link**
- Text Button style, trailing `open_in_new` icon (flips in RTL)
- Typography: Label Large, Primary Blue
- Touch target: 48dp height
- Placement: Right-aligned (start in RTL) directly beneath media player


**Vote Button** (Like/Dislike - MVP: Abstain hidden)
- Type: Icon Button (icon-only, no text labels)
- Layout: **Like (👍) on LEFT, Dislike (👎) on RIGHT**
- Icons: Thumb Up (Like), Thumb Down (Dislike)
- Selected state: Filled background (green for Like, red for Dislike), white icon
- Unselected state: Outlined icon, grey, minimal background
- Size: 48dp × 48dp touch target, 40dp icon
- Spacing: Buttons separated with space between (centered in container or split to edges)
- Note: Abstain vote type tracked in backend but not displayed in UI (MVP)

**Vote Tally Display**
- Background: Grey 100 (`#F5F5F5`) or transparent
- Padding: 8dp horizontal, 6dp vertical
- Border radius: 16dp (pill shape) for individual tallies
- Text: Body Small (12sp), color by vote type (green for Like, red for Dislike)
- Layout: **Horizontal, Like tally on LEFT, Dislike tally on RIGHT**
- Example: `[👍 42]    [8 👎]` (spaced apart, not stacked)
- Each tally is a separate pill/chip component

#### Text Inputs

**Standard Input**
- Background: White or Grey 100 (depending on context)
- Border: 1dp, Grey 300 (Divider color)
- Border radius: 4dp
- Padding: 16dp horizontal, 12dp vertical
- Typography: Body Large (16sp) for user input
- Label: Title Small (14sp), above or inside (Material Design 3 style)
- Error state: Border Red 700, helper text red

**Text Area** (node content editor)
- Same as standard input
- Min height: 120dp
- Multi-line support
- Character count (bottom right, RTL-aware)

#### Navigation

**Bottom Navigation**
- Height: 56dp
- Background: White
- Elevation: 8dp (shadow above)
- Icons: 24dp, Grey 600 (inactive), Primary Blue (active)
- Labels: Label Small (11sp), below icons
- Selected indicator: Underline, 2dp, Primary Blue

**Top AppBar**
- Height: 56dp (default), 64dp (with subtitle)
- Background: White
- Elevation: 4dp
- Title: Title Large (22sp, Medium)
- Icons: 24dp, Grey 600
- Back button: Start-aligned (left in LTR, right in RTL)

**Tabs** (if used)
- Height: 48dp
- Active tab: Title Medium (16sp, Medium), Primary Blue underline
- Inactive tab: Title Medium (16sp, Regular), Grey 600
- Indicator: 2dp height, Primary Blue

#### Lists

**List Item** (threads, nodes)
- Min height: 72dp (recommended 96dp for content)
- Padding: 16dp horizontal, 12dp vertical
- Divider: 1dp, Grey 300, full width at bottom (not indented)
- Interactive: Ripple effect on tap, elevation on long-press

**Expandable List Item** (tree nodes)
- Same as list item
- Expand/collapse icon: 24dp, start-aligned (flips in RTL)
- Indentation: +16dp per level (max visual: 4 levels before "show more")

#### Badges & Chips

**Badge** (notification count, new items)
- Background: Red 700 (`#D32F2F`)
- Text: White, Label Small (11sp)
- Size: Min 16dp diameter, auto-width for text
- Position: Top-end of parent (top-right in LTR, top-left in RTL)

**Parent Relation Badge** (PRO/AGAINST/NEUTRAL - reply nodes only)
- **PRO**: Green 700 (`#388E3C`) background, white text, Label Medium (12sp)
- **AGAINST**: Red 700 (`#D32F2F`) background, white text, Label Medium (12sp)
- **NEUTRAL**: Grey 600 (`#757575`) background, white text, Label Medium (12sp)
- Padding: 6dp horizontal, 4dp vertical
- Border radius: 4dp (rectangular, not pill)
- Position: Start of reply node header (left in LTR, right in RTL)
- Always uppercase: "PRO", "AGAINST", "NEUTRAL"

**Chip** (topic tags, filters)
- Background: Grey 200 (`#EEEEEE`)
- Text: Grey 900, Label Medium (12sp)
- Padding: 8dp horizontal, 4dp vertical
- Border radius: 16dp (pill)
- Selected: Primary Blue background, white text

#### Modals & Sheets

**Bottom Sheet**
- Background: White
- Corner radius: 16dp (top corners only)
- Max height: 90% of screen
- Handle: 4dp height, 40dp width, Grey 400, centered at top
- Content padding: 24dp

**Dialog** (confirmations, alerts)
- Background: White
- Corner radius: 8dp
- Min width: 280dp, max width: 560dp
- Padding: 24dp
- Buttons: Horizontal layout at bottom, Text Buttons

---

### Icons

**Icon Library**: Material Icons (built into Android)
- Size: 24dp (standard), 16dp (small), 32dp (large)
- Style: Outlined (default), Filled (selected/active)
- Color: Follow semantic colors (Grey 600 default, Primary Blue active)

**Key Icons**:
- Navigation: `menu` (drawer), `arrow_back` (back), `search` (search)
- Voting: `thumb_up`, `thumb_down`, `remove_circle_outline` (abstain)
- Content: `add` (create), `edit`, `reply`, `share`, `more_vert` (menu)
- Status: `check_circle` (success), `error` (error), `info` (info)
- Social: `account_circle` (profile), `notifications` (alerts)

**RTL Icon Mapping**:
- `arrow_back` → flips automatically (use `arrow_forward` in RTL if needed)
- Navigation icons mirror in RTL contexts

---

### Accessibility

#### Color Contrast
- **Text on background**: Minimum 4.5:1 (WCAG AA), target 7:1 (WCAG AAA)
- **Interactive elements**: 3:1 minimum (4.5:1 recommended)
- **Large text** (18sp+): 3:1 minimum acceptable

#### Touch Targets
- **Minimum size**: 48dp × 48dp (Android guideline)
- **Recommended**: 56dp × 56dp for primary actions
- **Spacing**: At least 8dp between targets

#### Screen Reader (TalkBack)
- **Content labels**: All interactive elements must have `contentDescription`
- **Heading hierarchy**: Use semantic headings (h1-h6 equivalent in Compose)
- **Live regions**: Voting tallies, notifications announce on change
- **Focus order**: Logical tab order (top-to-bottom, start-to-end in RTL)

#### Text Scaling
- Support up to 200% scaling (Android system setting)
- Test at all scales: 100%, 125%, 150%, 175%, 200%
- Layout should not break; text should not truncate unnecessarily

#### Reduced Motion
- Respect `ACCESSIBILITY_LIVE_REGION` and `ACCESSIBILITY_ENABLED` settings
- Reduce animations for users who prefer reduced motion
- Provide skip animations option in settings

---

### RTL (Right-to-Left) Support

#### Layout Mirroring
- **Navigation**: Drawer opens from right, back button moves to right
- **Bottom nav**: Icons and labels stay in same relative positions (doesn't flip)
- **Cards**: Content flows right-to-left
- **Lists**: Start-aligned content (right-aligned in RTL)

#### Text Alignment
- **Default**: `start` (not `left`) — auto-flips in RTL
- **Hebrew text**: Natural alignment (right)
- **English/Latin**: Natural alignment (left, but appears right in RTL layout)
- **Mixed content**: Use `textDirection="locale"` in Compose

#### Icon Mirroring
- **Arrows**: `arrow_back` mirrors automatically
- **Navigation**: Menu icons stay in logical positions
- **Asymmetric icons**: Only mirror if meaning changes (e.g., play/pause don't flip)

#### Spacing & Padding
- Use `start`/`end` instead of `left`/`right` for margins/padding
- ConstraintLayout/Column/Row handle RTL automatically

#### Testing Checklist
- [ ] All screens render correctly in RTL
- [ ] Text alignment appropriate for content language
- [ ] Icons positioned correctly
- [ ] Touch targets accessible
- [ ] Animations feel natural
- [ ] Layout doesn't break at different text scales

---

### Animation & Motion

#### Principles
- **Purposeful**: Animations guide user attention, indicate state changes
- **Subtle**: Don't distract from content
- **Fast**: Most transitions 200-300ms
- **Natural**: Easing curves (Material Design easing)

#### Common Animations
- **Screen transitions**: Slide (300ms), fade (200ms)
- **List items**: Fade in (150ms staggered)
- **Button press**: Scale 0.95 (100ms)
- **Vote tallies**: Count up animation (500ms)
- **Expand/collapse**: Height transition (250ms)

#### Accessibility
- Respect `ANIMATION_DURATION_SCALE` system setting
- Pause/resume on app backgrounding
- Test with reduced motion enabled

---

### Implementation Notes (Jetpack Compose)

- Colors: Define in `Theme.kt` as `Color` objects
- Typography: Use `MaterialTheme.typography` with custom scale
- Spacing: Create `Dimens.kt` object with spacing constants
- Components: Build as composable functions with theme parameters
- RTL: Use `LocalLayoutDirection` and `start`/`end` properties
- Dark mode: Prepare color scheme (implement post-MVP)

---

### Version History

- **v0.1** (2025-01-27): Initial design system defined
  - Color palette established
  - Typography scale (Material Design 3)
  - Component specifications
  - RTL and accessibility guidelines

