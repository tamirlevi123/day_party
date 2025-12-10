# Video Architecture Documentation

## Overview

The Day Party platform supports two types of videos:

1. **User-Uploaded Videos** (`source: 'upload'`)
   - Videos uploaded by users (e.g., from camera)
   - Stored in **Google Drive**
   - Require backend proxy for web playback

2. **External Videos** (`source: 'external'`)
   - Videos hosted elsewhere (YouTube, Vimeo, etc.)
   - Only links/pointers stored in database
   - Played directly via embed/iframe

## Architecture Flow

### User-Uploaded Videos

```
User Upload → Backend → Google Drive Storage
                      ↓
              Google Drive URL stored in DB
                      ↓
         Flutter App (VideoPlayerWidget)
                      ↓
         ┌───────────┴───────────┐
         │                        │
    Android/Mobile          Web Platform
         │                        │
    Direct Play          Backend Proxy Required
         │                        │
    ✅ Works            /api/videos/proxy
                              │
                    ┌─────────┴─────────┐
                    │                   │
            Google Drive API    Direct Download URL
            (Primary)          (Fallback)
                    │                   │
            ✅ With credentials    ✅ Public files
```

### External Videos

```
User Provides Link → Backend validates → Store link in DB
                                      ↓
                            Flutter App (ExternalVideoCard)
                                      ↓
                            Direct embed/iframe
                                      ↓
                            ✅ Works everywhere
```

## Implementation Details

### Frontend (Flutter)

**VideoPlayerWidget** (`lib/widgets/video_player_widget.dart`)
- Used for **upload videos only**
- Detects Google Drive URLs on web
- Automatically routes through backend proxy: `/api/videos/proxy?url=...`
- On mobile: Plays directly (no proxy needed)

**ExternalVideoCard** (`lib/widgets/external_video_card.dart`)
- Used for **external videos only**
- Embeds YouTube/Vimeo iframes
- No proxy needed

### Backend Proxy Endpoint

**`GET /api/videos/proxy`** (`backend/src/controllers/video.controller.ts`)

**Purpose**: Stream Google Drive videos for web playback

**Implementation**:

Uses Google Drive API exclusively:
```typescript
driveService.getVideoStream(fileId)
```
- Uses Google Drive API credentials
- Fetches video stream with `alt: 'media'`
- Provides proper MIME type and file size
- Requires: API credentials configured
- No fallback mechanism - fails fast if API is unavailable

**Response Headers**:
- `Content-Type`: Video MIME type (e.g., `video/mp4`)
- `Accept-Ranges`: `bytes` (for video seeking)
- `Content-Length`: File size (if available)
- `Cache-Control`: `public, max-age=3600`

**Range Request Support**:
- Supports HTTP Range requests for video seeking
- Returns `206 Partial Content` with `Content-Range` header

## Why Proxy is Needed

### Problem
Google Drive URLs cannot be played directly by HTML5 `<video>` elements on web because:

1. **CORS Restrictions**: Google Drive doesn't allow cross-origin video playback
2. **Authentication**: Videos may require authentication even if "publicly viewable"
3. **Content-Type**: Google Drive may return HTML pages instead of video streams
4. **Browser Security**: Browsers block direct video playback from Google Drive

### Solution
Backend proxy:
- Uses Google Drive API with proper credentials
- Fetches video stream server-side
- Streams to browser with correct headers
- Bypasses CORS restrictions
- Provides consistent video format

## Database Schema

```prisma
model Node {
  video_source      VideoSource?  // 'upload' or 'external'
  video_url         String?       // Google Drive URL (upload) or external URL
  video_provider    VideoProvider? // 'youtube', 'vimeo', 'other' (external only)
  video_provider_id String?       // Provider-specific ID (external only)
  video_embed_html  String?        // Embed HTML (external only)
  // ...
}

enum VideoSource {
  upload    // User-uploaded, stored in Google Drive
  external  // External link (YouTube, Vimeo, etc.)
}
```

## Usage Examples

### Upload Video (Stored in Google Drive)
```dart
// In thread_detail_screen.dart
if (node.video?.source == VideoSource.upload) {
  VideoPlayerWidget(
    urlOrPath: node.video!.url!, // Google Drive URL
    height: 220,
  )
}
```

### External Video (YouTube/Vimeo)
```dart
// In thread_detail_screen.dart
if (node.video?.source == VideoSource.external) {
  ExternalVideoCard(attachment: node.video!)
}
```

## Configuration

### Backend Environment Variables

For Google Drive API (Primary Method):
```env
GOOGLE_DRIVE_CREDENTIALS={...}  # Service Account JSON
# OR
GOOGLE_DRIVE_CLIENT_ID=...
GOOGLE_DRIVE_CLIENT_SECRET=...
GOOGLE_DRIVE_REFRESH_TOKEN=...
```

### File Permissions

Uploaded videos must be:
- Stored in Google Drive
- Made publicly viewable (`role: 'reader', type: 'anyone'`)
- Accessible via the configured Google Drive API credentials

## Troubleshooting

### Video Not Playing on Web

1. **Check Backend Logs**:
   - Look for "Proxy video: Fetching stream..."
   - Check if API method or fallback is used
   - Verify error messages

2. **Verify Google Drive Setup**:
   - API credentials configured?
   - File is publicly shared?
   - File ID is correct?

3. **Check Browser Network Tab**:
   - Is `/api/videos/proxy` returning 200?
   - What Content-Type header?
   - Any CORS errors?

### Fallback Used Instead of API

If you see "Proxy video: API failed, falling back to direct download URL":
- Google Drive API credentials may be missing/incorrect
- API may not have access to the file
- This is OK - fallback works for publicly shared files

## Future Improvements

- [ ] Add video transcoding for better compatibility
- [ ] Implement video caching/CDN
- [ ] Add support for more video hosting providers
- [ ] Optimize proxy performance for large files
- [ ] Add video thumbnail generation

