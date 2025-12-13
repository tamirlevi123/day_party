import { Request, Response } from 'express';
import multer from 'multer';
import { Readable } from 'stream';
import axios from 'axios';
import { driveService, UploadVideoResult } from '../services/drive.service';
import { getVideoPreview } from '../services/video-link.service';

// Configure multer for memory storage (don't save to disk)
const storage = multer.memoryStorage();

// File filter: only allow video files
const fileFilter = (_req: Request, file: Express.Multer.File, cb: multer.FileFilterCallback) => {
  const allowedMimeTypes = [
    'video/mp4',
    'video/mpeg',
    'video/quicktime',
    'video/x-msvideo',
    'video/webm',
    'video/3gpp',
  ];

  if (allowedMimeTypes.includes(file.mimetype)) {
    cb(null, true);
  } else {
    cb(new Error(`Invalid file type. Allowed types: ${allowedMimeTypes.join(', ')}`));
  }
};

// Configure multer upload
export const upload = multer({
  storage,
  fileFilter,
  limits: {
    fileSize: 500 * 1024 * 1024, // 500MB max file size
  },
});

/**
 * Upload video endpoint
 * POST /api/videos/upload
 * Content-Type: multipart/form-data
 * Body: { video: File }
 */
export const uploadVideo = async (req: Request, res: Response): Promise<Response | void> => {
  try {
    if (!req.file) {
      return res.status(400).json({
        error: 'validation_error',
        message: 'No video file provided. Use field name "video"',
      });
    }

    const file = req.file;
    
    // Validate file size (already checked by multer, but double-check)
    if (file.size > 500 * 1024 * 1024) {
      return res.status(400).json({
        error: 'validation_error',
        message: 'File size exceeds 500MB limit',
      });
    }

    // Upload to Google Drive
    const result: UploadVideoResult = await driveService.uploadVideo(
      file.buffer,
      file.originalname,
      file.mimetype
    );

    // Return the public URL for video playback
    // Use webContentLink for direct streaming access
    return res.status(200).json({
      videoUrl: result.webContentLink,
      fileId: result.fileId,
      webViewLink: result.webViewLink,
      thumbnailLink: result.thumbnailLink,
      fileName: file.originalname,
      size: file.size,
      mimeType: file.mimetype,
    });
  } catch (error: any) {
    console.error('Video upload error:', error);
    
    if (error.message.includes('credentials')) {
      return res.status(500).json({
        error: 'configuration_error',
        message: 'Google Drive is not properly configured. Please check server configuration.',
      });
    }

    return res.status(500).json({
      error: 'upload_failed',
      message: error.message || 'Failed to upload video',
    });
  }
};

/**
 * Delete video endpoint (optional, for cleanup)
 * DELETE /api/videos/:fileId
 */
export const deleteVideo = async (req: Request, res: Response): Promise<Response | void> => {
  try {
    const { fileId } = req.params;

    if (!fileId) {
      return res.status(400).json({
        error: 'validation_error',
        message: 'File ID is required',
      });
    }

    await driveService.deleteFile(fileId);

    return res.status(200).json({
      message: 'Video deleted successfully',
      fileId,
    });
  } catch (error: any) {
    console.error('Video delete error:', error);
    return res.status(500).json({
      error: 'delete_failed',
      message: error.message || 'Failed to delete video',
    });
  }
};

/**
 * Fetch metadata for an external video link
 * POST /api/videos/preview
 * Body: { url: string }
 */
export const previewExternalVideo = async (req: Request, res: Response): Promise<Response | void> => {
  try {
    const { url } = req.body;

    if (!url || typeof url !== 'string') {
      return res.status(400).json({
        error: 'validation_error',
        message: 'A video URL is required',
      });
    }

    const preview = await getVideoPreview(url);

    return res.status(200).json({
      provider: preview.provider,
      providerId: preview.providerId,
      normalizedUrl: preview.normalizedUrl,
      title: preview.title,
      description: preview.description,
      durationSec: preview.durationSec,
      thumbnailUrl: preview.thumbnailUrl,
      embedHtml: preview.embedHtml,
      metadata: preview.metadata,
    });
  } catch (error: any) {
    const message = error?.message || 'Failed to fetch video metadata';
    return res.status(400).json({
      error: 'preview_failed',
      message,
    });
  }
};

/**
 * Extract Google Drive file ID from URL
 */
function extractGoogleDriveFileId(url: string): string | null {
  // Format: https://drive.google.com/uc?export=view&id=FILE_ID
  const ucMatch = url.match(/[?&]id=([a-zA-Z0-9_-]+)/);
  if (ucMatch) {
    return ucMatch[1];
  }

  // Format: https://drive.google.com/file/d/FILE_ID/view
  const fileMatch = url.match(/\/file\/d\/([a-zA-Z0-9_-]+)/);
  if (fileMatch) {
    return fileMatch[1];
  }

  return null;
}

/**
 * Proxy Google Drive video for web playback
 * GET /api/videos/proxy?fileId=FILE_ID or /api/videos/proxy?url=GOOGLE_DRIVE_URL
 * 
 * ARCHITECTURE:
 * This endpoint is used specifically for user-uploaded videos (source: 'upload')
 * that are stored in Google Drive. External videos (YouTube, Vimeo, etc.) don't
 * need this proxy since they're already hosted and playable.
 * 
 * WHY PROXY IS NEEDED:
 * - Google Drive URLs cannot be played directly by HTML5 video players on web
 *   due to CORS restrictions and authentication requirements
 * - The backend uses Google Drive API credentials to fetch the video stream
 * - This allows the video to be streamed to the browser with proper headers
 * 
 * IMPLEMENTATION:
 * Uses Google Drive API (driveService.getVideoStream) to fetch the video stream.
 * Requires Google Drive API credentials to be configured.
 * 
 * This endpoint streams Google Drive videos through the backend,
 * allowing them to be played in HTML5 video players on web.
 */
export const proxyGoogleDriveVideo = async (req: Request, res: Response): Promise<void> => {
  try {
    const { fileId, url } = req.query;

    let driveFileId: string | null = null;

    if (fileId && typeof fileId === 'string') {
      driveFileId = fileId;
    } else if (url && typeof url === 'string') {
      driveFileId = extractGoogleDriveFileId(url);
    }

    if (!driveFileId) {
      console.error('Proxy video: Missing fileId or invalid URL', { fileId, url });
      res.status(400).json({
        error: 'validation_error',
        message: 'Either fileId or url query parameter is required. URL must be a Google Drive URL.',
      });
      return;
    }

    console.log(`Proxy video: Fetching stream for fileId: ${driveFileId}`);

    // Handle Range requests for video seeking (required for HTML5 video players)
    const range = req.headers.range;
    let rangeStart: number | undefined;
    let rangeEnd: number | undefined;
    
    if (range) {
      const parts = range.replace(/bytes=/, '').split('-');
      rangeStart = parseInt(parts[0], 10);
      rangeEnd = parts[1] ? parseInt(parts[1], 10) : undefined;
    }

    // Get video stream from Google Drive
    // Since Android can play these videos directly, they are publicly accessible.
    // We can use the direct download URL without OAuth2 credentials.
    let stream: Readable;
    let mimeType: string;
    let size: number | undefined;
    
    // Try Google Drive API first (if credentials are configured)
    try {
      const result = await driveService.getVideoStream(driveFileId);
      stream = result.stream;
      mimeType = result.mimeType;
      size = result.size;
      console.log(`Proxy video: Got stream via Google Drive API, mimeType: ${mimeType}, size: ${size}`);
    } catch (apiError: any) {
      // API failed (likely invalid credentials) - use direct download URL for public files
      console.warn('Proxy video: Google Drive API failed, using direct download URL:', apiError.message);
      console.log('Proxy video: Using direct download URL (files are publicly accessible)');
      
      try {
        // Use direct download URL format for publicly accessible files
        const directUrl = `https://drive.google.com/uc?export=download&id=${driveFileId}&confirm=t`;
        const requestHeaders: any = {};
        
        // Add Range header if this is a Range request
        if (rangeStart !== undefined) {
          requestHeaders['Range'] = range;
        }
        
        const response = await axios.get(directUrl, {
          responseType: 'stream',
          headers: requestHeaders,
          maxRedirects: 5,
        });
        
        stream = response.data;
        mimeType = response.headers['content-type'] || 'video/mp4';
        
        // Handle Range response
        if (response.status === 206 && response.headers['content-range']) {
          // Parse Content-Range: bytes start-end/total
          const contentRange = response.headers['content-range'];
          const match = contentRange.match(/bytes (\d+)-(\d+)\/(\d+)/);
          if (match) {
            rangeStart = parseInt(match[1], 10);
            rangeEnd = parseInt(match[2], 10);
            size = parseInt(match[3], 10);
          }
        } else {
          size = response.headers['content-length'] ? parseInt(response.headers['content-length'], 10) : undefined;
        }
        
        console.log(`Proxy video: Got stream via direct URL, mimeType: ${mimeType}, size: ${size}, range: ${rangeStart !== undefined ? `${rangeStart}-${rangeEnd}` : 'full'}`);
      } catch (directError: any) {
        console.error('Proxy video: Failed to fetch video via direct URL:', directError.message);
        res.status(500).json({
          error: 'video_fetch_error',
          message: `Failed to fetch video from Google Drive. API error: ${apiError.message}. Direct URL error: ${directError.message}`,
        });
        return;
      }
    }

    // Set headers for video streaming
    res.setHeader('Content-Type', mimeType);
    res.setHeader('Accept-Ranges', 'bytes');
    res.setHeader('Cache-Control', 'public, max-age=3600'); // Cache for 1 hour

    // Handle Range response
    if (rangeStart !== undefined && size && rangeEnd !== undefined) {
      const chunkSize = rangeEnd - rangeStart + 1;
      res.status(206); // Partial Content
      res.setHeader('Content-Range', `bytes ${rangeStart}-${rangeEnd}/${size}`);
      res.setHeader('Content-Length', chunkSize.toString());
    } else if (size) {
      res.setHeader('Content-Length', size.toString());
    }

    // Stream the video
    stream.on('error', (error) => {
      console.error('Stream error:', error);
      if (!res.headersSent) {
        res.status(500).json({
          error: 'stream_error',
          message: 'Failed to stream video',
        });
      }
    });

    stream.pipe(res);
  } catch (error: any) {
    console.error('Video proxy error:', error);
    if (!res.headersSent) {
      res.status(500).json({
        error: 'proxy_failed',
        message: error.message || 'Failed to proxy video',
      });
    }
  }
};

