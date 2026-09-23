import { NextFunction, Request, Response } from 'express';
import { ZodSchema } from 'zod';

type Source = 'body' | 'query' | 'params';

/** Валидирует req[source] по Zod-схеме; при ошибке — 422 с описанием по полям. */
export function validate(schema: ZodSchema, source: Source = 'body') {
  return (req: Request, res: Response, next: NextFunction) => {
    const result = schema.safeParse(req[source]);
    if (!result.success) {
      const details: Record<string, string> = {};
      for (const issue of result.error.issues) {
        details[issue.path.join('.') || source] = issue.message;
      }
      res.status(422).json({ error: { code: 'VALIDATION_ERROR', message: 'Некорректные данные', details } });
      return;
    }
    (req as Request & Record<string, unknown>)[`validated${capitalize(source)}`] = result.data;
    next();
  };
}

function capitalize(s: string) {
  return s.charAt(0).toUpperCase() + s.slice(1);
}
