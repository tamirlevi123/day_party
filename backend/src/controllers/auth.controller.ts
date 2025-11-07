import { Request, Response } from 'express';
import axios from 'axios';
import { findOrCreateUserFromOAuth, generateTokensForUser, logoutUser, OAuthUserInfo } from '../services/auth.service';
import { Provider } from '@prisma/client';
import { verifyToken } from '../utils/jwt.util';

const GOOGLE_CLIENT_ID = process.env.GOOGLE_CLIENT_ID;
const GOOGLE_CLIENT_SECRET = process.env.GOOGLE_CLIENT_SECRET;
// Use localhost for development - Google allows localhost redirect URIs
// For Android emulator, the app connects via 10.0.2.2, but Google redirects to localhost
// The backend server must be accessible on localhost:3000
const BACKEND_CALLBACK_URL = process.env.GOOGLE_CALLBACK_URL || 'http://localhost:3000/api/auth/google/callback';

/**
 * POST /auth/social/start
 * Initiates OAuth flow by returning authorization URL
 */
export const startSocialAuth = async (req: Request, res: Response): Promise<Response | void> => {
  try {
    const { provider, redirectUri } = req.body;

    if (!provider || !redirectUri) {
      return res.status(400).json({
        error: 'validation_error',
        message: 'provider and redirectUri are required',
      });
    }

    if (provider !== 'google') {
      return res.status(400).json({
        error: 'validation_error',
        message: 'Only Google provider is currently supported',
      });
    }

    if (!GOOGLE_CLIENT_ID || !GOOGLE_CLIENT_SECRET) {
      return res.status(500).json({
        error: 'configuration_error',
        message: 'Google OAuth credentials not configured',
      });
    }

    // For mobile apps, we need to use the backend callback URL
    // Google will redirect to our backend, then we redirect to the app's deep link
    // Generate state parameter for CSRF protection (includes app's redirect URI)
    const state = Buffer.from(JSON.stringify({ redirectUri, provider })).toString('base64');
    
    // Build Google OAuth authorization URL
    // Note: redirect_uri must be the backend callback URL (Google doesn't accept custom schemes directly)
    const authUrl = `https://accounts.google.com/o/oauth2/v2/auth?` +
      `client_id=${GOOGLE_CLIENT_ID}&` +
      `redirect_uri=${encodeURIComponent(BACKEND_CALLBACK_URL)}&` +
      `response_type=code&` +
      `scope=openid%20email%20profile&` +
      `state=${encodeURIComponent(state)}&` +
      `access_type=offline&` +
      `prompt=consent`;

    return res.status(200).json({
      authorizationUrl: authUrl,
    });
  } catch (error: any) {
    return res.status(500).json({
      error: 'internal_server_error',
      message: error.message || 'Failed to start OAuth flow',
    });
  }
};

/**
 * GET /auth/google/callback
 * Handles Google OAuth callback (redirected from Google)
 * This endpoint receives the code from Google, then redirects to the app's deep link
 */
export const handleGoogleCallback = async (req: Request, res: Response): Promise<Response | void> => {
  try {
    const { code, state } = req.query;

    if (!code || !state) {
      return res.status(400).send('Missing code or state parameter');
    }

    // Decode state to get app's redirect URI
    let appRedirectUri: string;
    try {
      const stateData = JSON.parse(Buffer.from(state as string, 'base64').toString());
      appRedirectUri = stateData.redirectUri;
    } catch {
      return res.status(400).send('Invalid state parameter');
    }

    // IMPORTANT: Don't exchange the code here!
    // The code is single-use. If we exchange it here, then when the app tries to use it
    // via /auth/social/callback, Google will return "invalid_grant" because it's already used.
    // Instead, pass the code directly to the app, which will exchange it via /auth/social/callback.
    
    // For emulator: Show code on page since browser can't reach localhost
    // For physical device: Redirect to deep link
    const redirectUrl = `${appRedirectUri}?code=${code}`;
    
    // Check if this is likely an emulator request (browser can't reach localhost)
    // Provide a page with the code that user can copy or click
    return res.send(`
      <!DOCTYPE html>
      <html>
        <head>
          <meta charset="UTF-8">
          <meta name="viewport" content="width=device-width, initial-scale=1.0">
          <title>Authentication Success</title>
          <style>
            body {
              font-family: Arial, sans-serif;
              max-width: 600px;
              margin: 50px auto;
              padding: 20px;
              background: #f5f5f5;
            }
            .container {
              background: white;
              padding: 30px;
              border-radius: 8px;
              box-shadow: 0 2px 4px rgba(0,0,0,0.1);
            }
            h1 {
              color: #1976D2;
              margin-top: 0;
            }
            .code-box {
              background: #f0f0f0;
              padding: 15px;
              border-radius: 4px;
              font-family: monospace;
              word-break: break-all;
              margin: 20px 0;
              border: 2px solid #1976D2;
            }
            .button {
              display: inline-block;
              background: #1976D2;
              color: white;
              padding: 12px 24px;
              text-decoration: none;
              border-radius: 4px;
              margin: 10px 5px 0 0;
              cursor: pointer;
            }
            .button:hover {
              background: #1565C0;
            }
            .copy-btn {
              background: #4CAF50;
            }
            .copy-btn:hover {
              background: #45a049;
            }
            .instructions {
              background: #e3f2fd;
              padding: 15px;
              border-radius: 4px;
              margin-top: 20px;
            }
          </style>
          <script>
            function copyCode() {
              const code = "${code}";
              navigator.clipboard.writeText(code).then(function() {
                alert('Code copied to clipboard!');
              }, function() {
                // Fallback for older browsers
                const textArea = document.createElement('textarea');
                textArea.value = code;
                document.body.appendChild(textArea);
                textArea.select();
                document.execCommand('copy');
                document.body.removeChild(textArea);
                alert('Code copied to clipboard!');
              });
            }
            
            // Try to open deep link automatically
            function tryDeepLink() {
              window.location.href = "${redirectUrl}";
              // Show manual option after 2 seconds
              setTimeout(function() {
                document.getElementById('manual-section').style.display = 'block';
              }, 2000);
            }
            
            // Try deep link on page load
            window.onload = function() {
              tryDeepLink();
            };
          </script>
        </head>
        <body>
          <div class="container">
            <h1>✅ Authentication Successful!</h1>
            <p>Your authorization code:</p>
            <div class="code-box" id="code-display">${code}</div>
            
            <button class="button copy-btn" onclick="copyCode()">📋 Copy Code</button>
            <a href="${redirectUrl}" class="button">🔗 Open App</a>
            
            <div id="manual-section" style="display: none;">
              <div class="instructions">
                <h3>If the app didn't open automatically:</h3>
                <ol>
                  <li>Copy the code above</li>
                  <li>Go back to the Day Party app</li>
                  <li>If prompted, paste the code</li>
                  <li>Or click "Open App" button above</li>
                </ol>
              </div>
            </div>
          </div>
        </body>
      </html>
    `);
  } catch (error: any) {
    console.error('Google OAuth callback error:', error);
    return res.status(500).send('Authentication failed. Please try again.');
  }
};

/**
 * POST /auth/social/callback
 * Alternative endpoint: App can call this directly with code (for testing or alternative flow)
 * Handles OAuth callback and exchanges code for JWT tokens
 */
export const handleSocialCallback = async (req: Request, res: Response): Promise<Response | void> => {
  try {
    const { provider, code, redirectUri } = req.body;

    if (!provider || !code || !redirectUri) {
      return res.status(400).json({
        error: 'validation_error',
        message: 'provider, code, and redirectUri are required',
      });
    }

    if (provider !== 'google') {
      return res.status(400).json({
        error: 'validation_error',
        message: 'Only Google provider is currently supported',
      });
    }

    if (!GOOGLE_CLIENT_ID || !GOOGLE_CLIENT_SECRET) {
      return res.status(500).json({
        error: 'configuration_error',
        message: 'Google OAuth credentials not configured',
      });
    }

    // Exchange code for access token
    // IMPORTANT: redirect_uri must match EXACTLY what was used in the authorization request
    // Google requires: redirect_uri in token exchange === redirect_uri from authorization
    // The authorization used BACKEND_CALLBACK_URL, so we must use the same here
    let tokenResponse;
    try {
      tokenResponse = await axios.post('https://oauth2.googleapis.com/token', {
        code,
        client_id: GOOGLE_CLIENT_ID,
        client_secret: GOOGLE_CLIENT_SECRET,
        redirect_uri: BACKEND_CALLBACK_URL, // Must match the redirect_uri from authorization
        grant_type: 'authorization_code',
      });
    } catch (axiosError: any) {
      // Log Google's actual error response
      if (axiosError.response) {
        console.error('Google OAuth token exchange error:', {
          status: axiosError.response.status,
          statusText: axiosError.response.statusText,
          data: axiosError.response.data,
          redirect_uri_used: BACKEND_CALLBACK_URL,
          code_length: code.length,
        });
        
        // Return a more informative error
        return res.status(400).json({
          error: 'oauth_error',
          message: axiosError.response.data?.error_description || axiosError.response.data?.error || 'Failed to exchange authorization code',
          details: axiosError.response.data,
        });
      }
      throw axiosError;
    }

    const { access_token } = tokenResponse.data;

    // Get user info from Google
    const userInfoResponse = await axios.get('https://www.googleapis.com/oauth2/v2/userinfo', {
      headers: {
        Authorization: `Bearer ${access_token}`,
      },
    });

    const googleUser = userInfoResponse.data;

    // Find or create user
    const oauthInfo: OAuthUserInfo = {
      provider: Provider.google,
      providerUserId: googleUser.id,
      email: googleUser.email || null,
      displayName: googleUser.name || googleUser.given_name || 'User',
    };

    const { user, isNewUser } = await findOrCreateUserFromOAuth(oauthInfo);

    // Generate JWT tokens
    const { token, refreshToken } = generateTokensForUser(user.id, user.role);

    return res.status(200).json({
      token,
      refreshToken,
      user: {
        id: user.id,
        displayName: user.displayName,
        role: user.role,
        profilePicture: googleUser.picture || null, // Include profile picture from Google
      },
      isNewUser,
    });
  } catch (error: any) {
    console.error('OAuth callback error:', error);
    return res.status(500).json({
      error: 'internal_server_error',
      message: error.message || 'Failed to complete OAuth flow',
    });
  }
};

/**
 * POST /auth/logout
 * Logs out user (invalidates session)
 */
export const logout = async (req: Request, res: Response): Promise<Response | void> => {
  try {
    // Extract token from Authorization header
    const authHeader = req.headers.authorization;
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      return res.status(401).json({
        error: 'unauthorized',
        message: 'No authorization token provided',
      });
    }

    const token = authHeader.substring(7);

    // Verify token and get user ID
    const payload = verifyToken(token);
    
    // Logout user (invalidate refresh token if needed)
    await logoutUser(payload.userId);

    return res.status(204).send();
  } catch (error: any) {
    if (error.message === 'Invalid or expired token') {
      return res.status(401).json({
        error: 'unauthorized',
        message: 'Invalid or expired token',
      });
    }

    return res.status(500).json({
      error: 'internal_server_error',
      message: error.message || 'Failed to logout',
    });
  }
};
