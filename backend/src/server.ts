import express from 'express';
import dotenv from 'dotenv';
import path from 'path';
import { PrismaClient } from '@prisma/client';
import apiRoutes from './routes';
import { errorHandler, notFoundHandler } from './middleware/error.middleware';
import { loadStatusCache } from './services/knesset-status.service';

dotenv.config();

const app = express();
const PORT = parseInt(process.env.PORT || '3000', 10);
export const prisma = new PrismaClient({
  log: [
    { emit: 'event', level: 'query' },
    { emit: 'event', level: 'error' },
    { emit: 'event', level: 'info' },
    { emit: 'event', level: 'warn' },
  ],
});

// Log all Prisma queries
prisma.$on('query' as never, (e: any) => {
  console.log(`[SQL] Query: ${e.query}`);
  console.log(`[SQL] Params: ${e.params}`);
  console.log(`[SQL] Duration: ${e.duration}ms`);
});

prisma.$on('error' as never, (e: any) => {
  console.error(`[Prisma Error] ${e.message}`);
});

app.use(express.json());

// Serve static files from public directory
app.use(express.static(path.join(__dirname, '../public')));

// CORS middleware for Android emulator
app.use((req, res, next): void => {
  res.header('Access-Control-Allow-Origin', '*');
  res.header('Access-Control-Allow-Methods', 'GET, POST, PUT, PATCH, DELETE, OPTIONS');
  res.header('Access-Control-Allow-Headers', 'Origin, X-Requested-With, Content-Type, Accept, Authorization');
  if (req.method === 'OPTIONS') {
    res.sendStatus(200);
    return;
  }
  next();
});

// Test endpoints
app.get('/health', (_req, res) => {
  res.status(200).json({ status: 'OK', timestamp: new Date().toISOString() });
});

app.post('/echo', (req, res) => {
  res.status(200).json({ ok: true, body: req.body });
});

app.get('/time', (_req, res) => {
  res.status(200).json({ now: new Date().toISOString() });
});

app.get('/db/ping', async (_req, res) => {
  try {
    await prisma.$queryRawUnsafe('SELECT 1 AS ok');
    res.status(200).json({ ok: true });
  } catch (error: any) {
    res.status(500).json({ ok: false, error: error?.message ?? 'DB error' });
  }
});

// Request logging middleware (for debugging) - log ALL requests
app.use((req, _res, next) => {
  console.log(`[Server] ${req.method} ${req.path} from ${req.ip}`);
  if (req.path.includes('knesset')) {
    console.log(`[Server] Knesset-related request detected: ${req.method} ${req.path}`);
  }
  next();
});

// API routes
app.use('/api', apiRoutes);

// Admin panel route - serve index.html for /admin
app.get('/admin', (_req, res) => {
  res.sendFile(path.join(__dirname, '../public/admin/index.html'));
});

// Error handling (must be last)
app.use(notFoundHandler);
app.use(errorHandler);

// Load Knesset status cache at startup
loadStatusCache().catch((error) => {
  console.error('[Server] Failed to load Knesset status cache:', error);
});

app.listen(PORT, '0.0.0.0', () => {
  console.log(`Day Party API server running on port ${PORT}`);
});

