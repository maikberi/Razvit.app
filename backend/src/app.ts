import cors from 'cors';
import express, { Express } from 'express';
import { errorHandler, notFoundHandler } from './middleware/errorHandler';
import { foodRouter } from './modules/food/food.routes';

export function createApp(): Express {
  const app = express();
  app.use(cors());
  app.use(express.json());

  app.get('/health', (_req, res) => res.status(200).json({ status: 'ok' }));

  app.use('/api/v1', foodRouter);

  app.use(notFoundHandler);
  app.use(errorHandler);

  return app;
}
