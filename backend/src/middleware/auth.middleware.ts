import { Request, Response, NextFunction } from 'express';
import { verifyToken, extractTokenFromHeader } from '../utils/jwt.util';
import { prisma } from '../server';

export interface AuthRequest extends Request {
  user?: {
    id: string;
    role: string;
  };
}

/**
 * Middleware to authenticate requests using JWT token
 */
export const authenticate = async (
  req: AuthRequest,
  res: Response,
  next: NextFunction
) => {
  try {
    const token = extractTokenFromHeader(req.headers.authorization);

    if (!token) {
      return res.status(401).json({
        error: 'unauthorized',
        message: 'No authorization token provided',
      });
    }

    // Verify token
    const payload = verifyToken(token);

    // Optionally verify user still exists and is active
    const user = await prisma.user.findUnique({
      where: { id: payload.userId },
      select: { id: true, role: true, isActive: true },
    });

    if (!user || !user.isActive) {
      return res.status(401).json({
        error: 'unauthorized',
        message: 'User not found or inactive',
      });
    }

    // Attach user to request
    req.user = {
      id: user.id,
      role: user.role,
    };

    next();
  } catch (error: any) {
    if (error.message === 'Invalid or expired token') {
      return res.status(401).json({
        error: 'unauthorized',
        message: 'Invalid or expired token',
      });
    }

    return res.status(500).json({
      error: 'internal_server_error',
      message: 'Authentication error',
    });
  }
};

/**
 * Middleware to check if user is admin
 */
export const requireAdmin = (
  req: AuthRequest,
  res: Response,
  next: NextFunction
) => {
  if (!req.user) {
    return res.status(401).json({
      error: 'unauthorized',
      message: 'Authentication required',
    });
  }

  if (req.user.role !== 'admin') {
    return res.status(403).json({
      error: 'forbidden',
      message: 'Admin access required',
    });
  }

  next();
};

