# Quick Start: OAuth2 with Personal Google Drive

This is a step-by-step guide to set up Google Drive video uploads using your personal Google account.

## Prerequisites
- A Google account (Gmail account)
- Access to Google Cloud Console (free)

---

## Step 1: Go to Google Cloud Console

1. Open your browser and go to: **https://console.cloud.google.com/**
2. Sign in with your Google account

---

## Step 2: Create or Select a Project

1. At the top of the page, you'll see a project dropdown (may say "Select a project")
2. Click it and either:
   - **Select an existing project** (if you have one), OR
   - **Click "NEW PROJECT"** to create one
3. If creating new:
   - Project name: `Day Party` (or any name you like)
   - Click **CREATE**
   - Wait a few seconds, then click **SELECT PROJECT**

---

## Step 3: Enable Google Drive API

1. In the left sidebar, click **"APIs & Services"** > **"Library"**
2. In the search bar at the top, type: `Google Drive API`
3. Click on **"Google Drive API"** in the results
4. Click the blue **"ENABLE"** button
5. Wait a few seconds for it to enable

---

## Step 4: Configure OAuth Consent Screen

1. In the left sidebar, click **"APIs & Services"** > **"OAuth consent screen"**
2. Select **"External"** (unless you have Google Workspace)
3. Click **"CREATE"**
4. Fill in the required fields:
   - **App name**: `Day Party` (or any name)
   - **User support email**: Select your email
   - **Developer contact information**: Enter your email
5. Click **"SAVE AND CONTINUE"**
6. On the **Scopes** page:
   - Click **"ADD OR REMOVE SCOPES"**
   - In the filter box, type: `drive.file`
   - Check the box for: **`.../auth/drive.file`**
   - Click **"UPDATE"**
   - Click **"SAVE AND CONTINUE"**
7. On the **Test users** page:
   - Click **"ADD USERS"**
   - Enter your Gmail address
   - Click **"ADD"**
   - Click **"SAVE AND CONTINUE"**
8. On the **Summary** page, click **"BACK TO DASHBOARD"**

---

## Step 5: Create OAuth Credentials

1. In the left sidebar, click **"APIs & Services"** > **"Credentials"**
2. At the top, click **"+ CREATE CREDENTIALS"**
3. Select **"OAuth client ID"**
4. If prompted about consent screen, click **"CONFIGURE CONSENT SCREEN"** and follow Step 4 above
5. In the **Application type** dropdown, select **"Desktop app"**
6. **Name**: `Day Party Video Upload` (or any name)
7. Click **"CREATE"**
8. **IMPORTANT**: A popup will appear with:
   - **Your Client ID** (looks like: `123456789-abc.apps.googleusercontent.com`)
   - **Your Client Secret** (looks like: `GOCSPX-abc123...`)
9. **Copy both values** and save them somewhere safe (you'll need them)
10. Click **"OK"**

---

## Step 6: Get Your Refresh Token

You need a refresh token so the server can access your Drive without you having to log in every time.

### Method: Using OAuth2 Playground (Easiest)

1. Open a new browser tab and go to: **https://developers.google.com/oauthplayground/**
2. In the top right, click the **gear icon (⚙️)**
3. Check the box: **"Use your own OAuth credentials"**
4. Enter your **Client ID** (from Step 5)
5. Enter your **Client Secret** (from Step 5)
6. Click **"Close"**
7. In the left panel, scroll down and find **"Drive API v3"**
8. Expand it and check the box: **`https://www.googleapis.com/auth/drive.file`**
9. Click the blue **"Authorize APIs"** button at the bottom
10. You'll be asked to sign in with your Google account - **sign in**
11. You'll see a warning about "This app isn't verified" - this is normal for testing. Click **"Advanced"** > **"Go to Day Party (unsafe)"**
12. Click **"Allow"** to grant permissions
13. You'll be redirected back to the playground
14. Click the blue **"Exchange authorization code for tokens"** button
15. You'll see a response with JSON. Look for **"refresh_token"** - copy that entire value
16. **Save this refresh token** - you'll need it for your `.env` file

---

## Step 7: Get Folder ID (Optional - Recommended)

If you want videos organized in a specific folder:

1. Go to **https://drive.google.com/** in your browser
2. Create a new folder (or use an existing one):
   - Click **"New"** > **"Folder"**
   - Name it: `Day Party Videos` (or any name)
   - Click **"Create"**
3. Open the folder (double-click it)
4. Look at the URL in your browser - it will look like:
   ```
   https://drive.google.com/drive/folders/1a2b3c4d5e6f7g8h9i0j
   ```
5. Copy the part after `/folders/` - that's your **Folder ID**
6. **Save this Folder ID** (you'll need it for your `.env` file)

---

## Step 8: Configure Your Backend

1. Open your backend folder: `E:\day_party\backend\`
2. If you don't have a `.env` file, copy `env.example` to `.env`:
   ```bash
   copy env.example .env
   ```
   Or on Windows PowerShell:
   ```powershell
   Copy-Item env.example .env
   ```
3. Open the `.env` file in a text editor
4. Add or update these lines with your values:

```env
# Google Drive OAuth2 (Personal Drive)
GOOGLE_DRIVE_CLIENT_ID="paste-your-client-id-here"
GOOGLE_DRIVE_CLIENT_SECRET="paste-your-client-secret-here"
GOOGLE_DRIVE_REFRESH_TOKEN="paste-your-refresh-token-here"
GOOGLE_DRIVE_FOLDER_ID="paste-your-folder-id-here-or-leave-empty"
```

**Example:**
```env
GOOGLE_DRIVE_CLIENT_ID="123456789-abc123def456.apps.googleusercontent.com"
GOOGLE_DRIVE_CLIENT_SECRET="GOCSPX-abc123def456ghi789"
GOOGLE_DRIVE_REFRESH_TOKEN="1//abc123def456ghi789jkl012mno345pqr678stu901vwx234"
GOOGLE_DRIVE_FOLDER_ID="1a2b3c4d5e6f7g8h9i0j"
```

**Important**: 
- Keep the quotes around the values
- Don't put any spaces around the `=` sign
- If you don't have a folder ID, leave `GOOGLE_DRIVE_FOLDER_ID=""` empty

---

## Step 9: Install Dependencies and Test

1. Open a terminal in your backend folder
2. Install the new packages:
   ```bash
   npm install
   ```
3. Start your backend server:
   ```bash
   npm run dev
   ```
4. You should see the server start without errors

---

## Step 10: Test the Upload (Optional)

You can test if it works using curl or Postman:

```bash
curl -X POST http://localhost:3000/api/videos/upload \
  -F "video=@C:\path\to\your\test-video.mp4"
```

Or use Postman:
- Method: POST
- URL: `http://localhost:3000/api/videos/upload`
- Body tab: form-data
- Key: `video` (type: File)
- Value: Select a video file
- Click Send

You should get a response with `videoUrl` that you can open in a browser.

---

## Troubleshooting

### "Invalid credentials" error
- Double-check that all three values (Client ID, Client Secret, Refresh Token) are correct in `.env`
- Make sure there are no extra spaces or quotes
- Try regenerating the refresh token in Step 6

### "Permission denied" error
- Make sure you added yourself as a test user in Step 4
- Try going through the OAuth Playground again (Step 6)
- Make sure the Drive API is enabled (Step 3)

### "This app isn't verified" warning
- This is normal for testing apps
- Click "Advanced" > "Go to [Your App Name] (unsafe)"
- This won't appear after you publish your app

### Videos not accessible
- The backend automatically makes videos public, but verify in Google Drive
- Right-click the uploaded file in Drive > Share > Make sure it's set to "Anyone with the link"

---

## What Happens Next?

Once configured:
1. When a user selects a video in the Flutter app
2. The app uploads it to your backend
3. Your backend uploads it to your Google Drive
4. Your backend returns a public URL
5. The video appears in your Drive and is playable in the app

---

## Security Notes

- **Never commit your `.env` file** to git (it should already be in `.gitignore`)
- Your refresh token doesn't expire, but you can revoke it in Google Account settings
- You can monitor storage usage in Google Drive
- Consider setting up a separate Google account for production if needed

---

## Need Help?

If you get stuck:
1. Check the browser console for errors
2. Check the backend server logs for detailed error messages
3. Verify all steps were completed correctly
4. Try regenerating the refresh token

