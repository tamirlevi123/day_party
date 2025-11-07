# Quick Setup: Google Drive for Video Storage

The error you're seeing is harmless - the server will work fine without Google Drive credentials, but video uploads won't work until you configure them.

## Quick Setup (OAuth2 - Easiest for Personal Use)

### Step 1: Get OAuth Credentials

1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Select your project (or create one)
3. Enable **Google Drive API**:
   - Go to **APIs & Services** > **Library**
   - Search "Google Drive API" > Click **Enable**
4. Create OAuth credentials:
   - Go to **APIs & Services** > **Credentials**
   - Click **Create Credentials** > **OAuth client ID**
   - If prompted, configure OAuth consent screen (see below)
   - Application type: **Desktop app** or **Web application**
   - Save **Client ID** and **Client Secret**

### Step 2: Configure OAuth Consent Screen

If you see "OAuth consent screen" configuration:
1. Select **External** (unless you have Google Workspace)
2. Fill in:
   - App name: `Day Party`
   - User support email: Your email
3. Add scopes: `https://www.googleapis.com/auth/drive.file`
4. Add test users: Your Gmail address
5. Save and continue

### Step 3: Get Refresh Token (Easiest Method)

1. Go to [OAuth2 Playground](https://developers.google.com/oauthplayground/)
2. Click the **⚙️ gear icon** (top right)
3. Check **"Use your own OAuth credentials"**
4. Enter your **Client ID** and **Client Secret**
5. In the left panel, find and select:
   - `https://www.googleapis.com/auth/drive.file`
6. Click **"Authorize APIs"**
7. Sign in with your Google account
8. Click **"Exchange authorization code for tokens"**
9. Copy the **Refresh token** (long string)

### Step 4: Update .env on VM

SSH to your VM and edit the `.env` file:

```bash
ssh azureuser@172.167.43.172
cd ~/dayparty/backend
nano .env
```

Add these lines (replace with your actual values):

```env
GOOGLE_DRIVE_CLIENT_ID="your-client-id.apps.googleusercontent.com"
GOOGLE_DRIVE_CLIENT_SECRET="your-client-secret"
GOOGLE_DRIVE_REFRESH_TOKEN="your-refresh-token"
GOOGLE_DRIVE_FOLDER_ID=""  # Optional: Leave empty to use Drive root
```

Save (Ctrl+X, then Y, then Enter)

### Step 5: Restart the Server

```bash
pm2 restart dayparty-api
pm2 logs dayparty-api
```

You should see: `✅ Google Drive initialized with OAuth2`

---

## Alternative: Service Account (Better for Production)

See `GOOGLE_DRIVE_SETUP.md` for detailed Service Account setup instructions.

---

## Testing

After setup, test video upload:

```bash
curl -X POST http://172.167.43.172/api/videos/upload \
  -F "video=@/path/to/test-video.mp4"
```

You should get a response with `videoUrl`.

---

## Troubleshooting

**Error still appears?**
- Make sure all three variables are set: `CLIENT_ID`, `CLIENT_SECRET`, `REFRESH_TOKEN`
- Check for typos in `.env` file
- Make sure there are no extra spaces or quotes
- Restart PM2: `pm2 restart dayparty-api`

**"Invalid refresh token" error?**
- Generate a new refresh token using OAuth2 Playground
- Make sure you're using the same Google account that authorized the app

**"Permission denied" error?**
- Make sure you added yourself as a test user in OAuth consent screen
- Check that the scope `drive.file` is enabled

