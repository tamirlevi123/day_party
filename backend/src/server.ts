import express from 'express';
import dotenv from 'dotenv';
import { PrismaClient } from '@prisma/client';
import apiRoutes from './routes';
import { errorHandler, notFoundHandler } from './middleware/error.middleware';

dotenv.config();

const app = express();
const PORT = parseInt(process.env.PORT || '3000', 10);
export const prisma = new PrismaClient();

app.use(express.json());

// CORS middleware for Android emulator
app.use((req, res, next) => {
  res.header('Access-Control-Allow-Origin', '*');
  res.header('Access-Control-Allow-Methods', 'GET, POST, PUT, PATCH, DELETE, OPTIONS');
  res.header('Access-Control-Allow-Headers', 'Origin, X-Requested-With, Content-Type, Accept, Authorization');
  if (req.method === 'OPTIONS') {
    return res.sendStatus(200);
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

// API routes
app.use('/api', apiRoutes);

// Error handling (must be last)
app.use(notFoundHandler);
app.use(errorHandler);

app.listen(PORT, '0.0.0.0', () => {
  console.log(`Day Party API server running on port ${PORT}`);
});

