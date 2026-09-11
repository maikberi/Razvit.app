import { NextFunction, Request, Response } from 'express';

/** Оборачивает async-обработчик так, чтобы отклонённый промис попадал в errorHandler, а не терялся. */
export function asyncHandler(fn: (req: Request, res: Response, next: NextFunction) => Promise<void>) {
  return (req: Request, res: Response, next: NextFunction) => {
    fn(req, res, next).catch(next);
  };
}
