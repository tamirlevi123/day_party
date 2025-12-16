import express from 'express';
import { startSocialAuth, handleGoogleCallback, handleSocialCallback, logout, refreshToken } from '../controllers/auth.controller';
import { authenticate } from '../middleware/auth.middleware';

const router = express.Router();

// POST /auth/social/start - Get OAuth authorization URL
router.post('/social/start', startSocialAuth);

// GET /auth/google/callback - Google redirects here, then we redirect to app
router.get('/google/callback', handleGoogleCallback);

// POST /auth/social/callback - Alternative: App can call this directly with code
router.post('/social/callback', handleSocialCallback);

// POST /auth/refresh - Refresh access token using refresh token
router.post('/refresh', refreshToken);

// POST /auth/logout - Logout user (requires authentication)
router.post('/logout', authenticate, logout);

export default router;

