import { google } from 'googleapis';
import { Readable } from 'stream';
import dotenv from 'dotenv';

// Load environment variables (in case this module is imported before server.ts loads dotenv)
dotenv.config();

// Google Drive API setup
// Uses service account or OAuth2 credentials from environment variables

export interface UploadVideoResult {
  fileId: string;
  webViewLink: string;
  webContentLink: string; // Direct download link
  thumbnailLink?: string;
}

class DriveService {
  private drive: any = null;
  private folderId: string | null = null;
  private initialized: boolean = false;

  constructor() {
    // Lazy initialization - only initialize when actually needed
    // This allows the server to start even if Google Drive credentials are not configured
  }

  private ensureInitialized() {
    if (this.initialized && this.drive) {
      return;
    }

    this.initialize();
  }

  private initialize() {
    // Initialize Google Drive API
    // Option 1: Service Account (recommended for server-to-server)
    // Option 2: OAuth2 (for personal Drive access)
    
    const credentials = process.env.GOOGLE_DRIVE_CREDENTIALS;
    const clientId = process.env.GOOGLE_DRIVE_CLIENT_ID;
    const clientSecret = process.env.GOOGLE_DRIVE_CLIENT_SECRET;
    const refreshToken = process.env.GOOGLE_DRIVE_REFRESH_TOKEN;
    const folderId = process.env.GOOGLE_DRIVE_FOLDER_ID;

    this.folderId = folderId || null;

    if (credentials) {
      // Service Account approach (JSON key file)
      try {
        const creds = JSON.parse(credentials);
        const auth = new google.auth.GoogleAuth({
          credentials: creds,
          scopes: ['https://www.googleapis.com/auth/drive.file'],
        });
        this.drive = google.drive({ version: 'v3', auth });
        this.initialized = true;
        console.log('✅ Google Drive initialized with Service Account');
      } catch (error) {
        console.error('❌ Failed to parse Google Drive credentials:', error);
        throw new Error('Invalid Google Drive credentials format');
      }
    } else if (clientId && clientSecret && refreshToken) {
      // OAuth2 approach (for personal Drive)
      try {
        const oauth2Client = new google.auth.OAuth2(
          clientId,
          clientSecret,
          'http://localhost' // Redirect URI (not used for refresh token flow)
        );

        oauth2Client.setCredentials({
          refresh_token: refreshToken,
        });

        this.drive = google.drive({ version: 'v3', auth: oauth2Client });
        this.initialized = true;
        console.log('✅ Google Drive initialized with OAuth2');
      } catch (error) {
        console.error('❌ Failed to initialize Google Drive OAuth2:', error);
        throw new Error('Failed to initialize Google Drive OAuth2 credentials');
      }
    } else {
      const errorMsg = 
        'Google Drive credentials not configured. ' +
        'Video uploads will not work. ' +
        'See GOOGLE_DRIVE_SETUP.md for setup instructions. ' +
        'Provide either GOOGLE_DRIVE_CREDENTIALS (service account) or ' +
        'GOOGLE_DRIVE_CLIENT_ID, GOOGLE_DRIVE_CLIENT_SECRET, and GOOGLE_DRIVE_REFRESH_TOKEN (OAuth2)';
      console.warn('⚠️  ' + errorMsg);
      throw new Error(errorMsg);
    }
  }

  /**
   * Upload a video file to Google Drive
   * @param fileBuffer - File buffer or stream
   * @param fileName - Original filename
   * @param mimeType - MIME type (e.g., 'video/mp4')
   * @returns Upload result with file ID and public links
   */
  async uploadVideo(
    fileBuffer: Buffer | Readable,
    fileName: string,
    mimeType: string = 'video/mp4'
  ): Promise<UploadVideoResult> {
    // Lazy initialization - only initialize when upload is attempted
    this.ensureInitialized();
    try {
      const fileMetadata: any = {
        name: `dayparty-${Date.now()}-${fileName}`,
        mimeType,
      };

      // If folder ID is provided, add it to parents
      if (this.folderId) {
        fileMetadata.parents = [this.folderId];
      }

      const media = {
        mimeType,
        body: fileBuffer instanceof Buffer 
          ? Readable.from(fileBuffer)
          : fileBuffer,
      };

      const response = await this.drive.files.create({
        requestBody: fileMetadata,
        media,
        fields: 'id, name, webViewLink, webContentLink, thumbnailLink',
      });

      const fileId = response.data.id;

      // Make the file publicly viewable (required for video playback)
      await this.drive.permissions.create({
        fileId,
        requestBody: {
          role: 'reader',
          type: 'anyone',
        },
      });

      // Generate direct download link (for video player)
      // Use uc?export=view for streaming video (works better than download)
      const directDownloadLink = `https://drive.google.com/uc?export=view&id=${fileId}`;

      return {
        fileId,
        webViewLink: response.data.webViewLink || `https://drive.google.com/file/d/${fileId}/view`,
        webContentLink: directDownloadLink,
        thumbnailLink: response.data.thumbnailLink,
      };
    } catch (error: any) {
      console.error('Error uploading to Google Drive:', error);
      throw new Error(`Failed to upload video: ${error.message}`);
    }
  }

  /**
   * Delete a file from Google Drive
   */
  async deleteFile(fileId: string): Promise<void> {
    // Lazy initialization - only initialize when delete is attempted
    this.ensureInitialized();
    try {
      await this.drive.files.delete({
        fileId,
      });
    } catch (error: any) {
      console.error('Error deleting file from Google Drive:', error);
      throw new Error(`Failed to delete file: ${error.message}`);
    }
  }

  /**
   * Get file metadata
   */
  async getFileInfo(fileId: string) {
    // Lazy initialization - only initialize when getting file info
    this.ensureInitialized();
    try {
      const response = await this.drive.files.get({
        fileId,
        fields: 'id, name, mimeType, size, webViewLink, webContentLink, thumbnailLink',
      });
      return response.data;
    } catch (error: any) {
      console.error('Error getting file info:', error);
      throw new Error(`Failed to get file info: ${error.message}`);
    }
  }
}

// Singleton instance
export const driveService = new DriveService();

