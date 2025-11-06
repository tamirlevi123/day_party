# Google Drive Setup Guide

This guide explains how to configure Google Drive for video storage in the Day Party backend.

## Option 1: OAuth2 with Personal Google Drive (Recommended for Personal Use)

This option uses your personal Google Drive account to store videos.

### Step 1: Enable Google Drive API

1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Create a new project or select an existing one
3. Enable the **Google Drive API**:
   - Navigate to **APIs & Services** > **Library**
   - Search for "Google Drive API"
   - Click **Enable**

### Step 2: Create OAuth 2.0 Credentials

1. Go to **APIs & Services** > **Credentials**
2. Click **Create Credentials** > **OAuth client ID**
3. If prompted, configure the OAuth consent screen:
   - Choose **External** (unless you have a Google Workspace account)
   - Fill in required fields (App name, User support email, etc.)
   - Add scopes: `https://www.googleapis.com/auth/drive.file`
   - Add test users (your email) if app is in testing mode
4. Create OAuth client:
   - Application type: **Desktop app** or **Web application**
   - Name: "Day Party Video Upload"
   - Click **Create**
5. Save the **Client ID** and **Client Secret**

### Step 3: Get Refresh Token

You need to get a refresh token that allows the server to access your Drive without user interaction.

#### Method A: Using OAuth2 Playground (Easiest)

1. Go to [OAuth2 Playground](https://developers.google.com/oauthplayground/)
2. Click the gear icon (⚙️) in top right
3. Check "Use your own OAuth credentials"
4. Enter your **Client ID** and **Client Secret**
5. In the left panel, find and select:
   - `https://www.googleapis.com/auth/drive.file`
6. Click **Authorize APIs**
7. Sign in with your Google account
8. Click **Exchange authorization code for tokens**
9. Copy the **Refresh token**

#### Method B: Using Node.js Script

Create a file `get-refresh-token.js`:

```javascript
const { google } = require('googleapis');
const readline = require('readline');

const rl = readline.createInterface({
  input: process.stdin,
  output: process.stdout,
});

const oauth2Client = new google.auth.OAuth2(
  'YOUR_CLIENT_ID',
  'YOUR_CLIENT_SECRET',
  'http://localhost:3000/oauth2callback'
);

const scopes = ['https://www.googleapis.com/auth/drive.file'];

const authUrl = oauth2Client.generateAuthUrl({
  access_type: 'offline',
  scope: scopes,
});

console.log('Authorize this app by visiting this url:', authUrl);
rl.question('Enter the code from that page here: ', (code) => {
  oauth2Client.getToken(code, (err, token) => {
    if (err) return console.error('Error retrieving access token', err);
    console.log('Refresh Token:', token.refresh_token);
    rl.close();
  });
});
```

Run it and follow the prompts.

### Step 4: Configure Environment Variables

Add to your `.env` file:

```env
GOOGLE_DRIVE_CLIENT_ID="your-client-id.apps.googleusercontent.com"
GOOGLE_DRIVE_CLIENT_SECRET="your-client-secret"
GOOGLE_DRIVE_REFRESH_TOKEN="your-refresh-token"
GOOGLE_DRIVE_FOLDER_ID=""  # Optional: Folder ID to organize videos
```

### Step 5: Get Folder ID (Optional)

If you want videos organized in a specific folder:

1. Create a folder in Google Drive
2. Open the folder
3. Copy the folder ID from the URL: `https://drive.google.com/drive/folders/FOLDER_ID_HERE`
4. Add to `.env`: `GOOGLE_DRIVE_FOLDER_ID="FOLDER_ID_HERE"`

---

## Option 2: Service Account (Recommended for Production)

This option uses a service account that doesn't require your personal Drive.

### Step 1: Create Service Account

1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Navigate to **APIs & Services** > **Credentials**
3. Click **Create Credentials** > **Service account**
4. Fill in details:
   - Name: "Day Party Video Upload"
   - Click **Create and Continue**
   - Skip role assignment (or add "Storage Admin")
   - Click **Done**
5. Click on the created service account
6. Go to **Keys** tab
7. Click **Add Key** > **Create new key**
8. Choose **JSON** format
9. Download the JSON file

### Step 2: Share Drive Folder with Service Account

1. Create a folder in your Google Drive (or use root)
2. Right-click the folder > **Share**
3. Enter the service account email (found in the JSON file, e.g., `day-party@project-id.iam.gserviceaccount.com`)
4. Give it **Editor** permissions
5. Click **Send**

### Step 3: Configure Environment Variables

Copy the entire JSON content and add to `.env`:

```env
GOOGLE_DRIVE_CREDENTIALS='{"type":"service_account","project_id":"...","private_key_id":"...",...}'
GOOGLE_DRIVE_FOLDER_ID="folder-id-if-using-specific-folder"
```

**Note**: The JSON must be on a single line or properly escaped for your `.env` file.

---

## Testing the Setup

1. Install backend dependencies:
   ```bash
   cd backend
   npm install
   ```

2. Start the backend:
   ```bash
   npm run dev
   ```

3. Test the upload endpoint:
   ```bash
   curl -X POST http://localhost:3000/api/videos/upload \
     -F "video=@/path/to/test-video.mp4"
   ```

You should receive a response with `videoUrl` that you can use in the Flutter app.

---

## Troubleshooting

### "Invalid credentials" error
- Verify all environment variables are set correctly
- For OAuth2: Ensure refresh token is valid (they don't expire but can be revoked)
- For Service Account: Ensure JSON is properly formatted and folder is shared

### "Permission denied" error
- For Service Account: Ensure the Drive folder is shared with the service account email
- For OAuth2: Ensure you granted the correct scopes

### Videos not accessible
- Files uploaded by service account need to be shared with "anyone with link"
- The Drive service automatically sets this permission, but verify the file permissions in Google Drive

### Large file uploads fail
- Check file size limit (currently 500MB)
- Consider increasing timeout settings in Express
- For very large files, consider implementing chunked uploads

---

## Security Notes

- **Never commit** your `.env` file to version control
- Store credentials securely (use environment variables in production)
- Consider using a separate Google Drive account for production
- Regularly rotate refresh tokens and service account keys
- Monitor Drive storage usage to avoid quota limits

