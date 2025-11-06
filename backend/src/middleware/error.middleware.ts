import { Request, Response, NextFunction } from 'express';

export interface ApiError extends Error {
  statusCode?: number;
  code?: string;
}

export const errorHandler = (
  err: ApiError,
  _req: Request,
  res: Response,
  _next: NextFunction
) => {
  const statusCode = err.statusCode || 500;
  const message = err.message || 'Internal server error';

  res.status(statusCode).json({
    error: err.code || 'internal_server_error',
    message,
  });
};

export const notFoundHandler = (_req: Request, res: Response) => {
  res.status(404).json({
    error: 'not_found',
    message: 'Route not found',
  });
};

