import { Request, Response } from 'express';
import multer from 'multer';
import { driveService, UploadVideoResult } from '../services/drive.service';

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

