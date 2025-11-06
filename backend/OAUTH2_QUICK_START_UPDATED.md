# Quick Start: OAuth2 with Personal Google Drive (Updated UI)

## Step 4: Configure OAuth Consent Screen (Updated Instructions)

Google has updated their interface. Here's how to configure it now:

1. **From the left sidebar**, look for **"Google Auth Platform"** section
2. You should see these options:
   - Overview (where you currently are)
   - **Branding** ← Click this first
   - **Audience** ← This is where most consent screen settings are
   - Clients
   - Data Access
   - Verification Center
   - Settings

### Option A: If you see "Audience" option

1. Click **"Audience"** in the left sidebar
2. You'll be prompted to configure the consent screen
3. Follow these steps:

#### Step 4a: Initial Setup
1. Select **"External"** (unless you have Google Workspace)
2. Click **"CREATE"**

#### Step 4b: App Information (Branding)
1. **App name**: `Day Party` (or any name)
2. **User support email**: Select your email
3. **App logo**: Optional (you can skip this)
4. **App domain**: Leave empty (or use `localhost` for testing)
5. **Application home page**: Leave empty (or use `http://localhost`)
6. **Privacy Policy link**: Optional (can add later)
7. **Terms of Service link**: Optional (can add later)
8. Click **"SAVE AND CONTINUE"**

#### Step 4c: Scopes
1. Click **"ADD OR REMOVE SCOPES"**
2. In the filter box, type: `drive.file`
3. Check the box for: **`https://www.googleapis.com/auth/drive.file`**
   - Make sure it shows "Google Drive API" as the source
4. Click **"UPDATE"**
5. Click **"SAVE AND CONTINUE"**

#### Step 4d: Test Users
1. Click **"ADD USERS"**
2. Enter your Gmail address (the one you want to use for Drive)
3. Click **"ADD"**
4. Click **"SAVE AND CONTINUE"**

#### Step 4e: Summary
1. Review the summary
2. Click **"BACK TO DASHBOARD"** or **"DONE"**

### Option B: If you see "Branding" instead

1. Click **"Branding"** first
2. Fill in:
   - App name: `Day Party`
   - Support email: Your email
3. Click **"SAVE"**
4. Then click **"Audience"** in the sidebar
5. Follow the steps above from Step 4c (Scopes)

### Option C: If you're redirected to a different page

If clicking "OAuth consent screen" takes you to a page that says:
- "You need to configure your OAuth consent screen" → Click **"CONFIGURE CONSENT SCREEN"**
- "Get started" → Click **"GET STARTED"**
- Any setup wizard → Follow the prompts

---

## Alternative: Direct URL

If the navigation is confusing, you can try going directly to:
```
https://console.cloud.google.com/apis/credentials/consent?project=knessetproj
```

Replace `knessetproj` with your project ID if different.

---

## What to do if you see an error

If you get an error message when clicking "OAuth consent screen", please share:
1. The exact error message
2. What page you're redirected to
3. Any buttons or options visible on that page

Common issues:
- **"You need to enable an API first"** → You've already done this (Drive API is enabled)
- **"Project not found"** → Make sure you're in the correct project (KnessetProj)
- **"Permission denied"** → Make sure you're the project owner

---

## Continue from Step 5

Once you've configured the consent screen, continue with:
- **Step 5: Create OAuth Credentials** (from the original guide)
- **Step 6: Get Refresh Token** (from the original guide)

The rest of the setup remains the same!

