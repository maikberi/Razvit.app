export {};

declare module 'express-serve-static-core' {
  interface Request {
    validatedBody?: unknown;
    validatedQuery?: unknown;
    validatedParams?: unknown;
    userId?: string;
  }
}
