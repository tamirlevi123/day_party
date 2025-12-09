import express from 'express';
import { uploadVideo, deleteVideo, upload, previewExternalVideo } from '../controllers/video.controller';

const router = express.Router();

// POST /api/videos/preview
// Validate external video links and return metadata
router.post('/preview', previewExternalVideo);

// POST /api/videos/upload
// Upload a video file to Google Drive
// Content-Type: multipart/form-data
// Body: { video: File }
router.post('/upload', upload.single('video'), uploadVideo);

// DELETE /api/videos/:fileId
// Delete a video from Google Drive (optional cleanup endpoint)
router.delete('/:fileId', deleteVideo);

export default router;

