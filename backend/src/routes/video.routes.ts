import express from 'express';
import { uploadVideo, deleteVideo, upload, previewExternalVideo, proxyGoogleDriveVideo } from '../controllers/video.controller';

const router = express.Router();

// POST /api/videos/preview
// Validate external video links and return metadata
router.post('/preview', previewExternalVideo);

// GET /api/videos/proxy?fileId=FILE_ID or /api/videos/proxy?url=GOOGLE_DRIVE_URL
// Proxy Google Drive videos for web playback
router.get('/proxy', proxyGoogleDriveVideo);

// POST /api/videos/upload
// Upload a video file to Google Drive
// Content-Type: multipart/form-data
// Body: { video: File }
router.post('/upload', upload.single('video'), uploadVideo);

// DELETE /api/videos/:fileId
// Delete a video from Google Drive (optional cleanup endpoint)
router.delete('/:fileId', deleteVideo);

export default router;

