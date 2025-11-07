import { Request, Response, NextFunction, RequestHandler } from 'express';
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
export const authenticate: RequestHandler = async (
  req: Request,
  res: Response,
  next: NextFunction
): Promise<void> => {
  try {
    const token = extractTokenFromHeader(req.headers.authorization);

    if (!token) {
      res.status(401).json({
        error: 'unauthorized',
        message: 'No authorization token provided',
      });
      return;
    }

    // Verify token
    const payload = verifyToken(token);

    // Optionally verify user still exists and is active
    const user = await prisma.user.findUnique({
      where: { id: payload.userId },
      select: { id: true, role: true, isActive: true },
    });

    if (!user || !user.isActive) {
      res.status(401).json({
        error: 'unauthorized',
        message: 'User not found or inactive',
      });
      return;
    }

    // Attach user to request
    (req as AuthRequest).user = {
      id: user.id,
      role: user.role,
    };

    next();
  } catch (error: any) {
    if (error.message === 'Invalid or expired token') {
      res.status(401).json({
        error: 'unauthorized',
        message: 'Invalid or expired token',
      });
      return;
    }

    res.status(500).json({
      error: 'internal_server_error',
      message: 'Authentication error',
    });
    return;
  }
};

/**
 * Middleware to check if user is admin
 */
export const requireAdmin: RequestHandler = (
  req: Request,
  res: Response,
  next: NextFunction
): void => {
  const authReq = req as AuthRequest;
  if (!authReq.user) {
    res.status(401).json({
      error: 'unauthorized',
      message: 'Authentication required',
    });
    return;
  }

  if (authReq.user.role !== 'admin') {
    res.status(403).json({
      error: 'forbidden',
      message: 'Admin access required',
    });
    return;
  }

  next();
};

